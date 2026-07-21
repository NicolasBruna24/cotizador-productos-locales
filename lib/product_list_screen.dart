import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cotizador_de_productos_locales/supabase_service.dart';
import 'package:cotizador_de_productos_locales/login_screen.dart';
import 'package:cotizador_de_productos_locales/upload_product_screen.dart';
import 'package:cotizador_de_productos_locales/join_screen.dart';
import 'package:cotizador_de_productos_locales/edit_profile_screen.dart';
import 'package:cotizador_de_productos_locales/reset_password_screen.dart';
import 'package:cotizador_de_productos_locales/product_detail_screen.dart';
import 'package:cotizador_de_productos_locales/favorites_screen.dart';
import 'package:cotizador_de_productos_locales/orders_screen.dart'; // Importar la nueva pantalla
import 'package:cotizador_de_productos_locales/premium_dashboard_screen.dart'; // Importar el Dashboard Premium

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

enum ScreenTab { catalog, favorites, orders, profile }

class _ProductListScreenState extends State<ProductListScreen> {
  final SupabaseService _service = SupabaseService();
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  bool _isLoading = true;
  String _searchText = '';
  String _selectedCategory = 'Todos';
  final TextEditingController _searchController = TextEditingController();
  String? _detectedRegion;
  bool _esProveedorReal = false;
  bool _esVerificado = false; // Nueva variable para controlar el acceso al Dashboard
  bool _esPremium = false;
  Set<String> _favoritosIds = {};
  bool _isLocating = false;
  List<String> _categories = ['Todos'];
  int _currentTabIndex = 0;

  // Variables para Anuncios
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  // Variables para Deep Linking
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  final GlobalKey _dashboardKey = GlobalKey();
  final GlobalKey _loginKey = GlobalKey();
  final GlobalKey _regionKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadProducts();
    // Delay banner ad init until after first frame to avoid Theme.of() usage in initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initBannerAd();
    });
    _initDeepLinks();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTutorial();
    });

    _service.sincronizarCambiosOffline(); // Intentar sincronizar al abrir
    // Escuchar cambios de autenticación (Magic Link, Logout, etc.)
    _authSubscription = _service.onAuthStateChange.listen((data) {
      debugPrint("Evento de Autenticación detectado: ${data.event}");
      
      final session = data.session;
      // Verificamos si es un evento de recuperación o si el usuario tiene metadatos de recuperación
      if (data.event == AuthChangeEvent.passwordRecovery) {
        // Usamos un pequeño delay para asegurar que la App ya cargó el estado
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ResetPasswordScreen()),
            );
          }
        });
      } else if (data.event == AuthChangeEvent.signedIn && session != null) {
        // Caso de respaldo: Si el evento es signedIn pero venimos de un flujo de recuperación
        // (Útil en Web si el hash se procesa antes de que el listener capture el evento específico)
        if (Uri.base.toString().contains('type=recovery')) {
           WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ResetPasswordScreen()));
            }
          });
        }
        _loadProducts(); // Recargar datos al iniciar sesión
      } else if (mounted) {
        _detectedRegion = null; // Limpiar filtros de región al cerrar sesión
        _loadProducts(); // Recargar datos al cerrar sesión
        setState(() {}); // Forzamos el redibujado para otros estados
      }
    });
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();
    
    // Cancelamos cualquier suscripción previa si existe
    _linkSubscription?.cancel();

    // Escuchar enlaces mientras la app está abierta o en segundo plano
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      debugPrint('Deep Link recibido: $uri');
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    if (uri.host == 'pago-exitoso') {
      _showPaymentStatusDialog(
        title: '¡Gracias por tu compra!',
        message: 'Tu pago ha sido procesado con éxito. El productor se pondrá en contacto contigo pronto.',
        isSuccess: true,
      );
    } else if (uri.host == 'pago-fallido') {
      _showPaymentStatusDialog(
        title: 'Pago cancelado',
        message: 'No se pudo completar la transacción. Por favor, intenta nuevamente.',
        isSuccess: false,
      );
    }
  }

  void _showPaymentStatusDialog({required String title, required String message, required bool isSuccess}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  void _initBannerAd() {
    if (kIsWeb) return; // Los anuncios móviles no funcionan en Web
    _bannerAd = BannerAd(
      // ID de prueba de Google. Reemplazar por tu Unit ID de producción después.
      adUnitId: kIsWeb ? '' : (Theme.of(context).platform == TargetPlatform.android 
          ? 'ca-app-pub-3940256099942544/6300978111' 
          : 'ca-app-pub-3940256099942544/2934735716'),
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() => _isBannerLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Error al cargar anuncio: $error');
        },
      ),
    );
    try {
      _bannerAd?.load();
    } catch (e) {
      debugPrint('Ad error: $e');
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _linkSubscription?.cancel(); // Ahora está correctamente definido en el State
    _authSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = _service.usuarioActual;
    if (user != null) {
      final isProv = await _service.esUsuarioProveedor();
      final isVerif = await _service.esProveedorVerificado();
      final isPremium = await _service.esPremium();
      final favs = await _service.obtenerMisFavoritosIds();
      if (mounted) {
        setState(() {
          _esProveedorReal = isProv;
          _esVerificado = isVerif;
          _esPremium = isPremium;
          _favoritosIds = favs.toSet();
        });
      }
    } else {
      // Limpiar estado cuando no hay usuario (Cierre de sesión)
      if (mounted) {
        setState(() {
          _esProveedorReal = false;
          _esVerificado = false;
          _esPremium = false;
          _favoritosIds = {};
        });
      }
    }
  }

  Future<void> _checkTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    bool visto = prefs.getBool('tutorial_visto') ?? false;
    if (!visto) {
      _showTutorial();
    }
  }

  void _showTutorial() {
    final bool esProveedor = _service.usuarioActual != null;
    List<TargetFocus> targets = [];
    int totalSteps = esProveedor ? 4 : 2;
    int currentStep = 1;

    targets.add(
      TargetFocus(
        identify: "login",
        keyTarget: _loginKey,
        shape: ShapeLightFocus.RRect,
        radius: 15,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => _buildTutorialCard(
              title: "Tu Cuenta",
              description: "Inicia sesión para guardar tus favoritos o configurar tu perfil de productor.",
              icon: Icons.person_pin,
              step: currentStep++,
              total: totalSteps,
              controller: controller,
            ),
          ),
        ],
      ),
    );

    targets.add(
      TargetFocus(
        identify: "region",
        keyTarget: _regionKey,
        shape: ShapeLightFocus.RRect,
        radius: 15,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) => _buildTutorialCard(
              title: "Busca por cercanía",
              description: "Usa este botón para encontrar productos frescos en tu región actual.",
              icon: Icons.location_on,
              step: currentStep++,
              total: totalSteps,
              controller: controller,
            ),
          ),
        ],
      ),
    );

    if (esProveedor && _esVerificado) {
      targets.add(
        TargetFocus(
          identify: "dashboard",
          keyTarget: _dashboardKey,
          shape: ShapeLightFocus.RRect,
          radius: 15,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) => _buildTutorialCard(
                title: "Panel de Control",
                description: "Analiza tus ventas, vistas y mejora tu negocio con métricas Premium.",
                icon: Icons.analytics,
                step: currentStep++,
                total: totalSteps,
                controller: controller,
              ),
            ),
          ],
        ),
      );
    }

    if (_esProveedorReal) {
      targets.add(
        TargetFocus(
          identify: "vender",
          keyTarget: _fabKey,
          shape: ShapeLightFocus.Circle,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) => _buildTutorialCard(
                title: "¡Empieza a vender!",
                description: "Sube fotos de tus productos y comienza a recibir pedidos locales.",
                icon: Icons.add_shopping_cart,
                step: currentStep++,
                total: totalSteps,
                controller: controller,
              ),
            ),
          ],
        ),
      );
    }

    TutorialCoachMark(
      targets: targets,
      colorShadow: const Color(0xFF2E7D32),
      opacityShadow: 0.8,
      textSkip: "SALTAR",
      alignSkip: Alignment.topRight,
      paddingFocus: 10,
      onClickTarget: (target) {
        // Opcional: avanzar al hacer clic en el elemento resaltado
      },
      onFinish: () {
        SharedPreferences.getInstance().then((prefs) => prefs.setBool('tutorial_visto', true));
      },
      onSkip: () {
        SharedPreferences.getInstance().then((prefs) => prefs.setBool('tutorial_visto', true));
        return true;
      },
    ).show(context: context);
  }

  Widget _buildTutorialCard({
    required String title,
    required String description,
    required IconData icon,
    required int step,
    required int total,
    required TutorialCoachMarkController controller,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text("Paso $step de $total", 
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                Icon(icon, color: Colors.green, size: 28),
              ],
            ),
            const SizedBox(height: 15),
            Text(title, 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
            const SizedBox(height: 8),
            Text(description, 
              style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.4)),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => controller.next(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(step == total ? "COMENZAR" : "SIGUIENTE"),
              ),
            ),
          ],
        ),
    );
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _service.obtenerCategorias();
      if (mounted) {
        setState(() {
          _categories = ['Todos', ...cats.map((e) => e['nombre'] as String)];
        });
      }
    } catch (_) {}
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final products = await _service.obtenerProductos(region: _detectedRegion);
      
      // Cargamos datos de usuario de forma segura para no bloquear la lista
      try {
        await _loadUserData();
      } catch (e) {
        debugPrint('Error cargando usuario: $e');
      }

      setState(() {
        _allProducts = products;
        _filteredProducts = products;
        _isLoading = false;
      });

      // Registrar "Vistas" para analíticas (en segundo plano)
      for (var p in products) {
        _service.registrarInteraccion(p['id'], p['proveedor_id'], 'vista').catchError((e) {
          debugPrint('Error registrando vista: $e');
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) { // Verificamos que el State siga activo
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar productos: $e')),
        );
      }
    }
  }

  Future<void> _detectarUbicacion() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition();

        String? regionDetectada;

        if (kIsWeb) {
          // Usamos OpenStreetMap (Nominatim) para la Web
          final url = Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=10&addressdetails=1'
          );
          
          final response = await http.get(url, headers: {
            'User-Agent': 'CotizadorProductoresLocales/1.0'
          });

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['address'] != null) {
              // Nominatim suele llamar a la región 'state', 'province' o 'region'
              final addr = data['address'];
              regionDetectada = addr['state'] ?? addr['province'] ?? addr['region'] ?? addr['county'];
            }
          }
        } else {
          // En Móvil seguimos usando el paquete nativo que es más rápido
          List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
          if (placemarks.isNotEmpty) {
            regionDetectada = placemarks.first.administrativeArea;
          }
        }

        if (regionDetectada != null) {
          setState(() {
            _detectedRegion = regionDetectada;
          });
          _loadProducts();
        }
      } else {
        throw 'Permiso de ubicación denegado';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No pudimos detectar tu región: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredProducts = _allProducts
          .where((p) {
            final matchesSearch = p['nombre'].toString().toLowerCase().contains(_searchText.toLowerCase());
            final matchesCategory = _selectedCategory == 'Todos' || p['categoria'] == _selectedCategory;
            return matchesSearch && matchesCategory;
          })
          .toList();
    });
  }

  void _verDetalle(Map<String, dynamic> product) {
    // Registrar "Interés Real" (Clic en la tarjeta o botón)
    _service.registrarInteraccion(product['id'], product['proveedor_id'], 'click_detalle');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(
          productData: product,
        ),
      ),
    );
  }

  Future<void> _toggleStock(String id, bool estadoActual) async {
    try {
      await _service.actualizarEstadoStock(id, !estadoActual);
      _loadProducts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sin conexión. El cambio se sincronizará automáticamente al recuperar señal. 📡'),
          ),
        );
      }
    }
  }

  Future<void> _borrarProducto(String id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar producto?'),
        content: const Text('¿Estás seguro de que quieres eliminar este producto? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await _service.borrarProducto(id);
        if (!mounted) return; // Guardia para el contexto de la clase
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Producto eliminado correctamente')),
        );
        _loadProducts(); // Recargar la lista
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _intentarAccederDashboard() {
    if (_esPremium) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumDashboardScreen()));
    } else {
      showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('🌟 Panel Premium'),
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Lleva tu negocio al siguiente nivel con analíticas avanzadas:'),
                    SizedBox(height: 10),
                    ListTile(leading: Icon(Icons.show_chart, color: Colors.green), title: Text('Tasa de conversión de clientes')),
                    ListTile(leading: Icon(Icons.map_outlined, color: Colors.green), title: Text('Mapa de calor por regiones')),
                    ListTile(leading: Icon(Icons.notifications_active, color: Colors.green), title: Text('Alertas de stock bajo')),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Más tarde')),
                  ElevatedButton(
                    onPressed: () {
                      _procesarPagoPremium(context, setDialogState, 'Mensual', 3500);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                    child: const Text('Mensual \$3.500'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _procesarPagoPremium(context, setDialogState, 'Anual', 29990);
                    },
                    child: const Text('Anual \$29.990'),
                  ),
                ],
              );
            },
          );
        },
      );
    }
  }

  Future<void> _procesarPagoPremium(BuildContext dialogContext, StateSetter setDialogState, String plan, double precio) async {
    setDialogState(() => _isLoading = true); // Usamos una variable local si es necesario, aquí simulamos con setDialogState
    try {
      final url = await _service.obtenerLinkSuscripcionPremium(plan, precio);
      if (!dialogContext.mounted) return;
      Navigator.pop(dialogContext);
      
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (dialogContext.mounted) {
        Navigator.pop(dialogContext);
      }
      if (mounted) { // Cambiado context.mounted por mounted para seguir la recomendación del linter
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _compartirCatalogo() async {
    final user = _service.usuarioActual;
    if (user == null) return;

    final String deepLink = 'io.supabase.prodlocales://catalogo/${user.id}';
    final String mensaje = '¡Hola! Te invito a conocer mi catálogo de productos locales aquí: $deepLink';

    // Opción 1: Share Plus (Dialogo nativo de compartir)
    await SharePlus.instance.share(
      ShareParams(
        text: mensaje,
        subject: 'Mi Catálogo en ProdLocales',
      ),
    );

    // Opción 2: WhatsApp Directo (Opcional, si prefieres forzar WhatsApp)
    /*
    final url = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(mensaje)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
    */
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enlace de catálogo generado y listo para compartir 📱')),
      );
    }
  }

  Future<void> _descargarQR(GlobalKey key) async {
  if (kIsWeb) return;
  // 1️⃣ Pedir permiso de almacenamiento
  final status = await Permission.storage.request();
  if (!status.isGranted) return;
  try {
    // 2️⃣ Capturar el widget del RepaintBoundary
    RenderRepaintBoundary boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    Uint8List pngBytes = byteData!.buffer.asUint8List();

    // 3️⃣ Guardar el PNG en un archivo temporal
    final tempDir = await getTemporaryDirectory();
    final file = await File(
            '${tempDir.path}/qr_${DateTime.now().millisecondsSinceEpoch}.png')
        .create();
    await file.writeAsBytes(pngBytes);

    // 4️⃣ Guardar la imagen en la galería del dispositivo
    await Gal.putImage(file.path);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR guardado en la galería')),
      );
    }
  } catch (e) {
    debugPrint('Error capturando QR: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar QR: $e')),
      );
    }
  }
}

  void _mostrarQRDialog() {
    final user = _service.usuarioActual;
    if (user == null) return;

    final String deepLink = 'io.supabase.prodlocales://catalogo/${user.id}';
    final GlobalKey qrKey = GlobalKey(); // Clave para capturar la imagen

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Tu Código QR', textAlign: TextAlign.center),
        content: SizedBox(
          width: 300, // Definir un ancho fijo soluciona el error de dimensiones intrínsecas (IntrinsicWidth) en el diálogo
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Muestra este código a tus clientes o imprímelo para que accedan directo a tu catálogo.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              RepaintBoundary(
                key: qrKey,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: QrImageView(
                    data: deepLink,
                    version: QrVersions.auto,
                    size: 200.0,
                    gapless: false,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1B5E20)),
                    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1B5E20)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(deepLink, style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
              if (kIsWeb)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Text(
                    'Nota: La descarga directa de la imagen del código QR está disponible únicamente en la aplicación móvil.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.orange[800], fontWeight: FontWeight.w500),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
          ElevatedButton.icon(
            onPressed: kIsWeb ? null : () => _descargarQR(qrKey),
            icon: const Icon(Icons.download_rounded),
            label: const Text('Guardar QR'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarNotificaciones() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF8FAF8),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.notifications_active_outlined, size: 48, color: Color(0xFF1B5E20)),
              const SizedBox(height: 16),
              const Text(
                'Centro de Notificaciones',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
              const SizedBox(height: 10),
              Text(
                'Mantente al tanto de tus pedidos, promociones locales y mensajes directos de productores.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 40),
              // Estado vacío diseñado (Punto 6 del feedback)
              Opacity(
                opacity: 0.6,
                child: Column(
                  children: [
                    Icon(Icons.mark_email_read_outlined, size: 60, color: Colors.grey[400]),
                    const SizedBox(height: 10),
                    const Text('¡Todo al día!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Text('Te avisaremos cuando pase algo importante.', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Verificamos si hay una sesión activa al momento de construir la UI
    final bool estaLogueado = _service.usuarioActual != null;
    final bool mostrarBotonVenta = estaLogueado && _esProveedorReal;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8), // Blanco orgánico para mayor limpieza
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAF8),
        foregroundColor: Colors.black87,
        title: const Text('ProdLocales', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -1.2, color: Color(0xFF1B5E20))),
        centerTitle: false,
        titleSpacing: 20,
        actions: const [
          // Los íconos de Notificaciones y Perfil fueron movidos al menú lateral (Drawer)
        ],
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(210),
          child: Column(
            children: [
              // Mensaje de Propuesta de Valor (Punto 5 del feedback)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _detectedRegion != null ? 'Lo mejor en $_detectedRegion' : 'Productos Locales',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Directo del productor a tu mesa',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (_esVerificado)
                      IconButton.filledTonal(
                        key: _dashboardKey,
                        icon: Icon(Icons.analytics_outlined, color: _esPremium ? Colors.green[800] : Colors.amber[900]),
                        onPressed: _intentarAccederDashboard,
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    _searchText = val;
                    _applyFilters();
                  },
                  decoration: InputDecoration(
                    hintText: 'Encuentra lo mejor del campo...',
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFFF0F2F0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    ActionChip(
                      key: _regionKey,
                      avatar: _isLocating 
                        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(Icons.location_on, size: 16, color: _detectedRegion != null ? Colors.blue : null),
                      label: Text(_detectedRegion ?? 'Detectar Región'),
                      onPressed: _isLocating ? null : _detectarUbicacion,
                    ),
                    if (_detectedRegion != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          setState(() {
                            _detectedRegion = null;
                          });
                          _loadProducts();
                        },
                      ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: _categories.map((cat) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(cat),
                        selected: _selectedCategory == cat,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = cat;
                            _applyFilters();
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero, // Elimina el padding por defecto del ListView
          children: [
            // Custom Drawer Header
            Container(
              height: 180, // Altura ligeramente mayor para el encabezado
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2E7D32), Color(0xFF5CCB88)], // Degradado de verde oscuro a claro
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.local_shipping, color: Colors.white, size: 48), // Ícono más grande
                  SizedBox(height: 10),
                  const Text(
                    'ProdLocales',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24, // Fuente más grande
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (estaLogueado && _service.usuarioActual?.email != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _service.usuarioActual!.email!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined, color: Color(0xFF2E7D32)),
              title: const Text('Notificaciones'),
              onTap: () {
                Navigator.pop(context); // Cerrar drawer
                _mostrarNotificaciones();
              },
            ),
            if (!estaLogueado)
              ListTile(
                leading: const Icon(Icons.login_rounded, color: Color(0xFF2E7D32)),
                title: const Text('Iniciar Sesión / Registrarse'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ).then((_) => _loadUserData());
                },
              ),
            if (estaLogueado) ...[
              ListTile(
                leading: const Icon(Icons.favorite_border, color: Color(0xFF2E7D32)), // Color verde para el ícono
                title: const Text('Mis Favoritos'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                  ).then((_) => _loadUserData()); // Recargar favoritos al volver
                },
              ),
              ListTile(
                leading: Icon(_esProveedorReal ? Icons.storefront : Icons.person_add_alt_1, color: Color(0xFF2E7D32)), // Color verde para el ícono
                title: Text(_esProveedorReal ? 'Mi Perfil Comercial' : 'Quiero ser Proveedor'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (_) => const EditProfileScreen())
                  ).then((_) => _loadUserData()); // Recargar estado al volver
                },
              ),
              if (_esProveedorReal)
                ListTile(
                  leading: const Icon(Icons.share_outlined, color: Color(0xFF2E7D32)),
                  title: const Text('Compartir mi Catálogo'),
                  onTap: () {
                    Navigator.pop(context);
                    _compartirCatalogo();
                  },
                ),
              if (_esProveedorReal)
                ListTile(
                  leading: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF2E7D32)),
                  title: const Text('Generar QR de Catálogo'),
                  onTap: () {
                    Navigator.pop(context);
                    _mostrarQRDialog();
                  },
                ),
              if (_esVerificado) // Mis Ventas también requiere verificación
                Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF2E7D32)), // Color verde para el ícono
                      title: const Text('Mis Ventas'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen()));
                      },
                    ),
                  ],
                ),
              const Divider(), // Separador visual
            ],
            ListTile(
              leading: const Icon(Icons.public, color: Color(0xFF2E7D32)), // Color verde para el ícono
              title: const Text('Expansión y Países'),
              onTap: () {
                Navigator.pop(context); // Cerrar drawer
                Navigator.push(context, MaterialPageRoute(builder: (_) => const JoinScreen()));
              },
            ),
            if (estaLogueado) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Color(0xFF2E7D32)),
                title: const Text('Cerrar Sesión'),
                onTap: () async {
                  Navigator.pop(context); // Cerrar drawer
                  try {
                    await _service.cerrarSesion();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sesión cerrada correctamente')),
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al cerrar sesión: $e'), backgroundColor: Colors.red),
                    );
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                title: const Text('Eliminar mi Cuenta', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context); // Cerrar drawer
                  final confirmar = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('¿Eliminar tu cuenta?'),
                      content: const Text(
                        'Esta acción es irreversible y eliminará todos tus productos y datos asociados. '
                        '¿Estás absolutamente seguro de que quieres continuar?'
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Sí, eliminar mi cuenta'),
                        ),
                      ],
                    ),
                  );

                  if (confirmar == true) {
                    try {
                      await _service.deleteUserAccount();
                      if (!context.mounted) return; // Asegura que el widget siga en el árbol
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tu cuenta ha sido eliminada con éxito.')),
                      );
                    } catch (e) {
                      if (!context.mounted) return; // Asegura que el widget siga en el árbol
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error al eliminar la cuenta: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: mostrarBotonVenta
          ? FloatingActionButton.extended(
              key: _fabKey,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UploadProductScreen()),
              ).then((_) => _loadProducts()), // Recargar al volver
              label: const Text('Vender'),
              icon: const Icon(Icons.add),
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
            )
          : null,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isBannerLoaded && _bannerAd != null)
            SizedBox(
                height: _bannerAd!.size.height.toDouble(),
                width: _bannerAd!.size.width.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
          NavigationBar(
            selectedIndex: _currentTabIndex,
            onDestinationSelected: (index) {
              setState(() => _currentTabIndex = index);
              if (index == 1) { // Favoritos
                if (estaLogueado) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen())).then((_) => _loadUserData());
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                }
              } else if (index == 2) { // Ventas/Pedidos
                if (estaLogueado) {
                  if (_esVerificado) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersScreen()));
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                  }
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                }
              } else if (index == 3) { // Perfil
                if (estaLogueado) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())).then((_) => _loadUserData());
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                }
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront),
                label: 'Catálogo',
              ),
              NavigationDestination(
                icon: Icon(Icons.favorite_border),
                selectedIcon: Icon(Icons.favorite),
                label: 'Favoritos',
              ),
              NavigationDestination(
                icon: Icon(Icons.shopping_bag_outlined),
                selectedIcon: Icon(Icons.shopping_bag),
                label: 'Mis Pedidos',
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredProducts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // Evita conflictos de altura infinita
                    mainAxisAlignment: MainAxisAlignment.center, 
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 80, color: const Color(0xFF2E7D32).withValues(alpha: 0.2)),
                      const SizedBox(height: 20),
                      const Text(
                        '¿Buscas algo rico y local?',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'No encontramos productos en esta sección. Prueba detectando tu región o limpiando los filtros para ver qué hay cerca.',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchText = '';
                            _selectedCategory = 'Todos';
                            _detectedRegion = null;
                            _loadProducts();
                          });
                        },
                        child: const Text('Limpiar filtros'),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300,
                    childAspectRatio: 0.68,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: _filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = _filteredProducts[index];
                    final proveedor = product['perfiles_proveedores'];
                    final nombreProveedor = proveedor?['nombre_comercial'] ?? 'Productor Local';
                    final regionProveedor = proveedor?['region'] ?? '';
                    final bool esDuenio = _service.usuarioActual?.id == product['proveedor_id'];
                    final bool esFavorito = _favoritosIds.contains(product['id']);
                    
                    return GestureDetector(
                      onTap: () => _verDetalle(product),
                      child: Card(
                        elevation: 2,
                        shadowColor: Colors.black12,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 1, // Mantiene la imagen cuadrada y evita errores de altura infinita
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: product['imagen_url'] != null
                                      ? CachedNetworkImage(
                                          imageUrl: product['imagen_url'],
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(color: Colors.grey[100]),
                                          errorWidget: (context, url, error) => Container(
                                            color: Colors.grey[200],
                                            child: const Icon(Icons.broken_image, color: Colors.grey, size: 50),
                                          ),
                                        )
                                      : Container(color: Colors.grey[200], child: const Icon(Icons.image, size: 50)),
                                ),
                                  if (estaLogueado && !esDuenio)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: CircleAvatar(
                                        backgroundColor: Colors.white.withValues(alpha: 0.9),
                                        child: IconButton(
                                          icon: Icon(
                                            esFavorito ? Icons.favorite : Icons.favorite_border,
                                            color: Colors.red,
                                          ),
                                          onPressed: () async {
                                            await _service.toggleFavorito(product['id'], esFavorito);
                                            _loadUserData();
                                          },
                                        ),
                                      ),
                                    ),
                                  if (esDuenio)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: CircleAvatar(
                                        backgroundColor: Colors.red.withValues(alpha: 0.9),
                                        radius: 18,
                                        child: IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                                          onPressed: () => _borrarProducto(product['id']),
                                        ),
                                      ),
                                    ),
                                  if (esDuenio)
                                    Positioned(
                                      top: 8,
                                      left: 8,
                                      child: CircleAvatar(
                                        backgroundColor: (product['activo'] ?? true) ? Colors.green : Colors.orange,
                                        radius: 18,
                                        child: IconButton(
                                          tooltip: 'Cambiar Stock',
                                          icon: Icon((product['activo'] ?? true) ? Icons.check_circle : Icons.pause_circle_filled, color: Colors.white, size: 20),
                                          onPressed: () => _toggleStock(product['id'], product['activo'] ?? true),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(product['nombre'], 
                                    maxLines: 1, 
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: -0.5)),
                                  const SizedBox(height: 2),
                                  Text(nombreProveedor, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                                  if (regionProveedor.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(top: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        regionProveedor, 
                                        style: TextStyle(color: Colors.green[800], fontSize: 10, fontWeight: FontWeight.w600)
                                      ),
                                    ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        NumberFormat.currency(symbol: '\$', decimalDigits: 0, locale: 'es_CL').format(product['precio_base']), 
                                        style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.w900, fontSize: 18)
                                      ),
                                      Icon(Icons.add_circle_outline, color: Colors.grey[400], size: 22),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}