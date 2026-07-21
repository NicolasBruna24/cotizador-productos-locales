import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cotizador_de_productos_locales/supabase_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> productData;

  const ProductDetailScreen({super.key, required this.productData});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final SupabaseService _service = SupabaseService();
  int _cantidad = 1;
  String _tipoEntrega = 'retiro'; // 'retiro', 'vendedor', 'courier'
  final TextEditingController _direccionController = TextEditingController();
  bool _isProcessing = false;

  // Acceso abreviado a los datos
  Map<String, dynamic> get productData => widget.productData;

  // Getters para facilitar el acceso a los datos anidados de Supabase
  String get title => productData['nombre'] ?? 'Producto';
  double get price => (productData['precio_base'] as num).toDouble();
  String get category => productData['categoria'] ?? 'General';
  String get stockStatus => (productData['activo'] ?? true) ? 'En Stock' : 'Sin Stock';
  String get region => productData['perfiles_proveedores']?['region'] ?? 'Ubicación no disponible';
  String get sellerName => productData['perfiles_proveedores']?['nombre_comercial'] ?? 'Productor Anónimo';
  String? get imageUrl => productData['imagen_url'];
  int get maxStock => productData['detalles']?['stock'] ?? 999;

  @override
  void dispose() {
    _direccionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAF8), // Fondo blanco-verdoso muy sutil
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.contact_support_outlined, color: Colors.black),
            onPressed: () => _mostrarModalContacto(context),
          ),
          const SizedBox(width: 10),
        ],
      ),
      backgroundColor: const Color(0xFFF8FAF8), 
      body: SingleChildScrollView(
        child: Center(
          child: Container(
          constraints: const BoxConstraints(maxWidth: 450), // Simula ancho de móvil
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              _buildImageCard(),
              const SizedBox(height: 20),
              _buildDetailCard(context),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildImageCard() {
    return Container(
      width: double.infinity,
      height: 320,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)], // Degradado Verde Orgánico suave
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Header sobre la imagen
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Etiqueta Orgánica
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.eco_outlined, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(category.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                // Etiqueta Stock
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: (productData['activo'] ?? true) ? Colors.green : Colors.red),
                  ),
                  child: Row(
                    children: [
                      Text(stockStatus, 
                        style: TextStyle(
                          color: (productData['activo'] ?? true) ? Colors.green[800] : Colors.red[800], 
                          fontSize: 10, 
                          fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Imagen Central y Placeholder
          Center(
            child: imageUrl != null 
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl!,
                    height: 200,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const CircularProgressIndicator(),
                    errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 100, color: Colors.brown),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.eco_outlined, color: Color(0xFF2E7D32), size: 100), 
                    const SizedBox(height: 10),
                    Text(
                  'Imagen del producto',
                  style: TextStyle(color: Colors.green.withValues(alpha: 0.4), fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título y Precio
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.5,
                    height: 1.1,
                    color: Color(0xFF1C1C1C),
                  ),
                ),
              ),
              Text(
                NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(price),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          // Datos del Vendedor
          _buildInfoRow(Icons.location_on_outlined, 'Región de procedencia', region),
          const SizedBox(height: 15),
          // Selectores de Compra
          _buildPurchaseSelectors(),
          const SizedBox(height: 15),
          _buildInfoRow(Icons.person_outline, 'Vendedor', sellerName),
          const SizedBox(height: 30),
          // Botones de Acción
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: _isProcessing 
                  ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                  : _buildActionButton(
                      icon: Icons.flash_on,
                      label: 'COMPRAR AHORA CON TARJETA',
                      color: const Color(0xFF2E7D32),
                      onPressed: () => _iniciarPagoOnline(context),
                    ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: _buildActionButton(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'PAGAR POR TRANSFERENCIA',
                  color: Colors.blueGrey[800]!,
                  onPressed: () => _mostrarModalTransferencia(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseSelectors() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Cantidad y Entrega', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, size: 18),
                    onPressed: () => setState(() => _cantidad = _cantidad > 1 ? _cantidad - 1 : 1),
                  ),
                  Text('$_cantidad', style: const TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: _cantidad < maxStock 
                        ? () => setState(() => _cantidad++) 
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _tipoEntrega,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'retiro', child: Text('Retiro en sede', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'vendedor', child: Text('Entrega Productor', style: TextStyle(fontSize: 13))),
                      DropdownMenuItem(value: 'courier', child: Text('Envío Empresa', style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: (val) => setState(() => _tipoEntrega = val!),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_tipoEntrega != 'retiro') ...[
          const SizedBox(height: 15),
          const Text('Dirección de Envío', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          TextField(
            controller: _direccionController,
            decoration: InputDecoration(
              hintText: 'Calle, número, ciudad...',
              hintStyle: const TextStyle(fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _iniciarPagoOnline(BuildContext context) async {
    if (_isProcessing) return;
    
    try {
      // Validación previa de stock
      final int stockActual = productData['detalles']?['stock'] ?? 1;
      if (stockActual <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lo sentimos, este producto se acaba de agotar.')),
        );
        return;
      }

      if (_tipoEntrega != 'retiro' && _direccionController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, ingresa una dirección para el envío.')),
        );
        return;
      }

      setState(() => _isProcessing = true);

      // 1. Crear el registro del pedido en la DB (Estado inicial: pendiente)
      final nuevoPedido = await _service.crearPedido({
        'producto_id': productData['id'],
        'proveedor_id': productData['proveedor_id'],
        'monto': price * _cantidad,
        'metodo_pago': 'mercado_pago',
        'estado': 'pendiente_pago',
        'cantidad': _cantidad,
        'tipo_entrega': _tipoEntrega,
        'direccion_entrega': _tipoEntrega != 'retiro' ? _direccionController.text.trim() : null,
      });

      // 2. Obtener el link de Mercado Pago desde el Backend
      final urlPago = await _service.obtenerLinkMercadoPago(
        nuevoPedido['id'],
        title,
        price * _cantidad, // Corregido: Monto total
      );

      // 3. Abrir la pasarela
      final uri = Uri.parse(urlPago);
      final canLaunch = await canLaunchUrl(uri);
      if (!context.mounted) return;
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al iniciar el pago: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1), // Fondo verde circular muy suave
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF2E7D32)),
        ),
        const SizedBox(width: 15),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w500)),
            Text(value, style: const TextStyle(color: Color(0xFF1C1C1C), fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  void _mostrarModalTransferencia(BuildContext context) {
    final config = productData['perfiles_proveedores']?['config_pago'] ?? {};
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Transferencia Bancaria', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildCopiaField(context, 'Titular', config['titular'] ?? sellerName),
            if (config['rut'] != null && config['rut'].isNotEmpty) _buildCopiaField(context, 'RUT', config['rut']),
            if (config['banco'] != null && config['banco'].isNotEmpty) _buildCopiaField(context, 'Banco', config['banco']),
            if (config['tipo_cuenta'] != null && config['tipo_cuenta'].isNotEmpty) _buildCopiaField(context, 'Tipo de Cuenta', config['tipo_cuenta']),
            if (config['numero_cuenta'] != null && config['numero_cuenta'].isNotEmpty) _buildCopiaField(context, 'Número de Cuenta', config['numero_cuenta']),
            // Compatibilidad con otros formatos (opcional)
            if (config['alias'] != null && config['alias'].isNotEmpty) _buildCopiaField(context, 'Alias / Mensaje', config['alias']),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (_tipoEntrega != 'retiro' && _direccionController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Por favor, ingresa una dirección de envío.')),
                  );
                  return;
                }

                // Registramos el pedido para que el vendedor lo vea en su lista
                await _service.crearPedido({
                  'producto_id': productData['id'],
                  'proveedor_id': productData['proveedor_id'],
                  'monto': price * _cantidad,
                  'metodo_pago': 'transferencia',
                  'estado': 'pendiente_pago',
                  'cantidad': _cantidad,
                  'tipo_entrega': _tipoEntrega,
                  'direccion_entrega': _tipoEntrega != 'retiro' ? _direccionController.text.trim() : null,
                });
                if (!context.mounted) return;
                _contactarVendedor(context, 'Ya realicé la transferencia.');
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 50)),
              child: const Text('Enviar Comprobante por WhatsApp'),
            )
          ],
        ),
      ),
    );
  }

  void _mostrarModalContacto(BuildContext context) {
    final String? phone = productData['perfiles_proveedores']?['whatsapp'];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Información del Productor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.store, color: Color(0xFF2E7D32)),
              title: const Text('Nombre del Productor'),
              subtitle: Text(sellerName),
            ),
            if (phone != null && phone.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.phone_android, color: Color(0xFF2E7D32)),
                title: const Text('WhatsApp / Contacto'),
                subtitle: Text(phone),
                trailing: const Icon(Icons.copy, size: 20),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: phone));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Número copiado al portapapeles'), duration: Duration(seconds: 1)),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCopiaField(BuildContext context, String label, String value) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
      trailing: const Icon(Icons.copy, size: 20),
      onTap: () {
        Clipboard.setData(ClipboardData(text: value));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label copiado al portapapeles'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
    );
  }

  Future<void> _contactarVendedor(BuildContext context, String mensajeExtra) async {
    final proveedor = productData['perfiles_proveedores'];
    final String? phone = proveedor?['whatsapp']?.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (phone == null || phone.isEmpty) return;

    final message = 'Hola $sellerName, me interesa tu producto "$title". $mensajeExtra';
    final url = Uri.https('wa.me', '/$phone', {'text': message});

    // Registrar la interacción
    await _service.registrarInteraccion(productData['id'], productData['proveedor_id'], 'clic_whatsapp');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildActionButton({
    required IconData icon, 
    required String label, 
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}