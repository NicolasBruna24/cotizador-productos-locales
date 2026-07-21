import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SupabaseService {
  final _supabase = Supabase.instance.client;

  // Obtener las categorías dinámicas desde la DB
  Future<List<Map<String, dynamic>>> obtenerCategorias() async {
    final response = await _supabase.from('categorias').select().order('nombre');
    return List<Map<String, dynamic>>.from(response);
  }

  // Obtener todos los productos activos con la info del proveedor
  Future<List<Map<String, dynamic>>> obtenerProductos({String? region}) async {
    var query = _supabase
        .from('productos')
        .select('*, perfiles_proveedores!inner(nombre_comercial, whatsapp, region, metodo_pago)');

    // Si NO hay usuario logueado (es un cliente), aplicamos filtros estrictos
    if (usuarioActual == null) {
      query = query
          .eq('activo', true);
    } else {
    }

    if (region != null && region.isNotEmpty) {
      query = query.ilike('perfiles_proveedores.region', '%$region%');
    }

    final response = await query.order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }

  // Registrar una interacción (Vista, Detalle o WhatsApp)
  Future<void> registrarInteraccion(String productoId, String proveedorId, String tipoEvento) async {
    final interactionData = {
      'producto_id': productoId,
      'proveedor_id': proveedorId,
      'tipo_evento': tipoEvento,
    };
    debugPrint('SupabaseService: Intentando registrar interacción: $interactionData');
    await _supabase.from('interacciones').insert(interactionData);
    debugPrint('SupabaseService: Interacción registrada con éxito.');
  }

  // --- Autenticación ---

  // Registrar un nuevo proveedor
  Future<void> registrarse(String email, String password) async {
    await _supabase.auth.signUp(
      email: email,
      password: password,
    );
  }

  // Enviar Magic Link al correo
  Future<void> loginConMagicLink(String email) async {
    // Si estamos en web, detectamos la URL actual para el redireccionamiento
    final String redirectUrl = _getRedirectUrl();

    await _supabase.auth.signInWithOtp(
      email: email,
      emailRedirectTo: redirectUrl,
    );
  }

  // Login con Email y Contraseña
  Future<void> loginConPassword(String email, String password) async {
    await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Recuperar contraseña
  Future<void> recuperarPassword(String email) async {
    final String redirectUrl = _getRedirectUrl();
    debugPrint('Solicitando recuperación para $email con redirección a: $redirectUrl');

    await _supabase.auth.resetPasswordForEmail(email, redirectTo: redirectUrl);
  }

  // Helper para obtener la URL de redirección según plataforma
  String _getRedirectUrl() {
    if (kIsWeb) {
      // Obtenemos la URL base y nos aseguramos de que no tenga parámetros extra
      final url = Uri.base.origin;
      // Si termina en /, se la quitamos para que coincida con la config de Supabase
      // o viceversa, lo importante es que coincida EXACTAMENTE con el dashboard
      return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    }
    // En móvil, usamos el esquema de Deep Link configurado en AndroidManifest.xml
    return 'io.supabase.prodlocales://login-callback';
  }

  // Actualizar la contraseña del usuario actual
  Future<void> actualizarPassword(String nuevoPassword) async {
    await _supabase.auth.updateUser(
      UserAttributes(password: nuevoPassword),
    );
  }

  // Cerrar sesión
  Future<void> cerrarSesion() async => await _supabase.auth.signOut();

  // Eliminar cuenta del usuario actual (requiere una Edge Function por seguridad)
  Future<void> deleteUserAccount() async {
    final user = usuarioActual;
    if (user == null) throw 'No hay usuario autenticado para eliminar.';

    try {
      // **IMPORTANTE:** Esta es una llamada a una Edge Function (o Cloud Function)
      // que DEBE manejar la lógica de eliminación de forma segura en el servidor.
      // NO se debe llamar directamente a `_supabase.auth.admin.deleteUser()` desde el cliente.
      //
      // La Edge Function (que deberás crear en Supabase) hará lo siguiente:
      // 1. Verificar la autenticación del usuario que hace la solicitud.
      // 2. Usar la clave de servicio (Service Role Key) para llamar a `supabase.auth.admin.deleteUser(user_id)`.
      // 3. Opcionalmente, eliminar datos asociados al usuario en otras tablas (productos, pedidos, etc.).
      final response = await _supabase.functions.invoke(
        'delete-user-account', // <-- Nombre de tu Edge Function en Supabase
        body: {
          'user_id': user.id,
        },
      );

      if (response.status != 200) {
        throw 'Error al eliminar la cuenta: ${response.data}';
      }
      await cerrarSesion(); // Si la eliminación fue exitosa en el backend, cerramos la sesión localmente
    } catch (e) {
      debugPrint('Error al intentar eliminar la cuenta: $e');
      rethrow; // Re-lanzar para que la UI pueda manejar el error
    }
  }

  // Obtener sesión actual
  Session? get sesionActual => _supabase.auth.currentSession;
  User? get usuarioActual => _supabase.auth.currentUser;

  // Verificar si el usuario actual tiene perfil de proveedor completo
  Future<bool> esUsuarioProveedor() async {
    final perfil = await obtenerMiPerfil();
    // Es proveedor si configuró su nombre comercial O si el admin lo verificó manualmente
    return perfil != null && (perfil['nombre_comercial'] != null || perfil['verificado'] == true);
  }

  // Verificar si el proveedor ya fue aprobado por el admin
  Future<bool> esProveedorVerificado() async {
    final perfil = await obtenerMiPerfil();
    return perfil != null && perfil['verificado'] == true;
  }

  // Verificar si el usuario tiene suscripción premium activa
  Future<bool> esPremium() async {
    final perfil = await obtenerMiPerfil();
    return perfil != null && perfil['premium_activo'] == true;
  }

  // Generar link de pago para la suscripción Premium
  Future<String> obtenerLinkSuscripcionPremium(String planNombre, double precio) async {
    final user = usuarioActual;
    if (user == null) throw 'Debes iniciar sesión para ser Premium';

    // Usamos un ID especial 'PREMIUM_USER_ID' para que el webhook identifique la transacción
    return obtenerLinkMercadoPago(
      'PREMIUM_${user.id}',
      'Plan Premium $planNombre - ProdLocales',
      precio,
    );
  }

  // --- Gestión de Favoritos ---
  Future<List<String>> obtenerMisFavoritosIds() async {
    final user = usuarioActual;
    if (user == null) return [];
    final res = await _supabase.from('favoritos').select('producto_id').eq('usuario_id', user.id);
    return List<String>.from(res.map((e) => e['producto_id'].toString()));
  }

  Future<List<Map<String, dynamic>>> obtenerMisFavoritosProductos() async {
    final user = usuarioActual;
    if (user == null) return [];
    
    final res = await _supabase
        .from('favoritos')
        .select('productos(*, perfiles_proveedores(nombre_comercial, region))')
        .eq('usuario_id', user.id);
    return List<Map<String, dynamic>>.from(res.map((e) => e['productos']));
  }

  Future<void> toggleFavorito(String productoId, bool esFavoritoActualmente) async {
    final user = usuarioActual;
    if (user == null) return;

    if (esFavoritoActualmente) {
      await _supabase.from('favoritos').delete().eq('usuario_id', user.id).eq('producto_id', productoId);
    } else {
      await _supabase.from('favoritos').insert({'usuario_id': user.id, 'producto_id': productoId});
    }
  }

  // --- Gestión de Productos ---

  // Insertar un nuevo producto
  Future<void> crearProducto(Map<String, dynamic> productoData) async {
    // El RLS se encarga de que el proveedor_id coincida con el usuario autenticado
    await _supabase.from('productos').insert(productoData);
  }

  // Eliminar un producto
  Future<void> borrarProducto(String productoId) async {
    await _supabase.from('productos').delete().eq('id', productoId);
  }

  // Disminuir stock de forma segura
  Future<void> disminuirStock(String productoId, int cantidad) async {
    try {
      await _supabase.rpc('disminuir_stock_producto', params: {
        'prod_id': productoId,
        'cant_a_restar': cantidad,
      });
    } catch (e) {
      debugPrint('Error al disminuir stock: $e');
    }
  }

  // Actualizar stock (activo/inactivo) con soporte offline
  Future<void> actualizarEstadoStock(String productoId, bool nuevoEstado) async {
    try {
      await _supabase
          .from('productos')
          .update({'activo': nuevoEstado})
          .eq('id', productoId);
      debugPrint('Sincronización inmediata exitosa para $productoId');
    } catch (e) {
      debugPrint('Sin conexión o error: Guardando cambio de stock localmente');
      await _guardarCambioOffline(productoId, nuevoEstado);
      rethrow; // Re-lanzamos para que la UI sepa que se guardó "en espera"
    }
  }

  Future<void> _guardarCambioOffline(String id, bool estado) async {
    final prefs = await SharedPreferences.getInstance();
    final String? colaJson = prefs.getString('offline_stock_queue');
    Map<String, dynamic> cola = colaJson != null ? json.decode(colaJson) : {};
    
    cola[id] = estado;
    await prefs.setString('offline_stock_queue', json.encode(cola));
  }

  // Intentar sincronizar cambios pendientes al recuperar señal
  Future<void> sincronizarCambiosOffline() async {
    final prefs = await SharedPreferences.getInstance();
    final String? colaJson = prefs.getString('offline_stock_queue');
    if (colaJson == null) return;

    Map<String, dynamic> cola = json.decode(colaJson);
    List<String> sincronizados = [];

    for (var entry in cola.entries) {
      try {
        await _supabase.from('productos').update({'activo': entry.value}).eq('id', entry.key);
        sincronizados.add(entry.key);
      } catch (_) { /* Seguir intentando el resto */ }
    }

    // Limpiar los que ya se subieron
    for (var id in sincronizados) { cola.remove(id); }
    await prefs.setString('offline_stock_queue', json.encode(cola));
  }

  // Stream para escuchar cambios en la sesión (útil para la UI)
  Stream<AuthState> get onAuthStateChange => _supabase.auth.onAuthStateChange;

  // Obtener estadísticas de clics por producto para el dashboard básico
  Future<List<Map<String, dynamic>>> obtenerEstadisticas() async {
    final user = usuarioActual;
    if (user == null) return [];

    final response = await _supabase
        .from('interacciones')
        .select('tipo_evento, created_at, productos(nombre)')
        .eq('proveedor_id', user.id);
    return List<Map<String, dynamic>>.from(response);
  }

  // Obtener resumen estadístico para el Dashboard Premium
  Future<Map<String, Map<String, int>>> obtenerResumenEstadistico() async {
    final user = usuarioActual;
    if (user == null) return {};

    // Obtener vistas y clics
    final interacciones = await _supabase
        .from('interacciones')
        .select('tipo_evento, productos(nombre)')
        .eq('proveedor_id', user.id);

    // Obtener ventas reales (pedidos pagados)
    final pedidos = await _supabase
        .from('pedidos')
        .select('productos(nombre)')
        .eq('proveedor_id', user.id)
        .eq('estado', 'pagado');

    Map<String, Map<String, int>> stats = {};

    for (var i in interacciones) {
      String nombre = i['productos']?['nombre'] ?? 'Desconocido';
      stats.putIfAbsent(nombre, () => {'vistas': 0, 'ventas': 0});
      stats[nombre]!['vistas'] = stats[nombre]!['vistas']! + 1;
    }

    for (var p in pedidos) {
      String nombre = p['productos']?['nombre'] ?? 'Desconocido';
      stats.putIfAbsent(nombre, () => {'vistas': 0, 'ventas': 0});
      stats[nombre]!['ventas'] = stats[nombre]!['ventas']! + 1;
    }

    return stats;
  }

  // Obtener el perfil del proveedor actual
  Future<Map<String, dynamic>?> obtenerMiPerfil() async {
    final user = usuarioActual;
    if (user == null) return null;
    final perfil = await _supabase
        .from('perfiles_proveedores')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (perfil != null) {
      try {
        final configPago = await _supabase.rpc('obtener_mi_config_pago');
        if (configPago != null) {
          perfil['config_pago'] = configPago;
        }
      } catch (e) {
        debugPrint('Error al obtener config_pago: $e');
      }
    }
    return perfil;
  }

  // Guardar o actualizar perfil
  Future<void> actualizarPerfil(Map<String, dynamic> perfil) async {
    await _supabase.from('perfiles_proveedores').upsert(perfil);
  }

  // Subir imagen al Storage y obtener URL pública
  Future<String> subirImagen(Uint8List bytes, String fileName) async {
    await _supabase.storage.from('productos').uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    return _supabase.storage.from('productos').getPublicUrl(fileName);
  }

  // Generar link de pago llamando a la Edge Function de Python
  Future<String> obtenerLinkMercadoPago(String pedidoId, String nombre, double precio) async {
    try {
      final response = await _supabase.functions.invoke(
        'crear-preferencia-mp', // Asegúrate de desplegar la función con este nombre
        body: {
          'pedido_id': pedidoId,
          'nombre': nombre,
          'precio': precio,
        },
      );
      if (response.data != null && response.data.containsKey('url_pago')) {
        return response.data['url_pago'];
      } else {
        throw 'La respuesta del servidor no contiene la URL de pago';
      }
    } catch (e) {
      debugPrint('Error en obtenerLinkMercadoPago: $e');
      rethrow;
    }
  }

  // Método unificado para pagos con tarjeta en Chile (vía Mercado Pago)
  Future<String> obtenerLinkWebpay(String pedidoId, double precio) async {
    // Como Mercado Pago ya incluye Webpay/Redcompra en Chile, 
    // redirigimos esta llamada al mismo flujo para simplificar.
    return obtenerLinkMercadoPago(pedidoId, "Pedido ProdLocales", precio);
  }

  // --- Gestión de Pedidos ---
  Future<Map<String, dynamic>> crearPedido(Map<String, dynamic> pedidoData) async {
    return await _supabase.from('pedidos').insert(pedidoData).select().single();
  }

  // Obtener pedidos recibidos para el proveedor actual
  Future<List<Map<String, dynamic>>> obtenerMisPedidos() async {
    final user = usuarioActual;
    if (user == null) return [];

    final response = await _supabase
        .from('pedidos')
        .select('*, productos(nombre, imagen_url, detalles)')
        .eq('proveedor_id', user.id)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // Flujo para transferencias: El vendedor confirma que recibió el dinero
  Future<void> confirmarPedidoYRestarStock(String pedidoId, String productoId, int cantidad) async {
    // 1. Cambiamos el estado del pedido
    await actualizarEstadoPedido(pedidoId, 'completado');
    // 2. Llamamos a la función SQL que creaste para bajar el stock
    await disminuirStock(productoId, cantidad);
  }

  Future<void> actualizarEstadoPedido(String pedidoId, String nuevoEstado) async {
    await _supabase.from('pedidos').update({'estado': nuevoEstado}).eq('id', pedidoId);
  }

  Future<String> subirComprobante(Uint8List bytes, String fileName) async {
    await _supabase.storage.from('comprobantes').uploadBinary(fileName, bytes, 
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true));
    return _supabase.storage.from('comprobantes').getPublicUrl(fileName);
  }

  // --- Funciones Administrativas (Para ti) ---

  // Ver productos que están esperando aprobación
  Future<List<Map<String, dynamic>>> obtenerProductosPendientes() async {
    final response = await _supabase
        .from('productos')
        .select('*, perfiles_proveedores(nombre_comercial)')
        .eq('estado', 'pendiente');
    return List<Map<String, dynamic>>.from(response);
  }

  // Aprobar o rechazar un producto manualmente
  Future<void> cambiarEstadoProducto(String productoId, String nuevoEstado) async {
    await _supabase
        .from('productos')
        .update({'estado': nuevoEstado})
        .eq('id', productoId);
  }
}