import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cotizador_de_productos_locales/supabase_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _service = SupabaseService();
  final _formKey = GlobalKey<FormState>();

  // Perfil General
  final _nombreComercialController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _regionController = TextEditingController();
  String _metodoPago = 'whatsapp'; // Cambiamos el valor por defecto inicial

  // Configuración de Pago (Adaptada para Chile)
  final _titularController = TextEditingController();
  final _rutController = TextEditingController();
  final _bancoController = TextEditingController();
  final _tipoCuentaController = TextEditingController();
  final _numeroCuentaController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  Future<void> _cargarPerfil() async {
    try {
      final perfil = await _service.obtenerMiPerfil();
      if (perfil != null && mounted) {
        setState(() {
          _nombreComercialController.text = perfil['nombre_comercial'] ?? '';
          _whatsappController.text = perfil['whatsapp'] ?? '';
          _descripcionController.text = perfil['descripcion'] ?? '';
          _regionController.text = perfil['region'] ?? '';
          
          // Validamos que el valor de la DB exista en nuestras opciones del Dropdown
          _metodoPago = perfil['metodo_pago'] ?? 'transferencia';
          const opcionesValidas = ['whatsapp', 'transferencia', 'mercado_pago', 'ambos'];
          if (!opcionesValidas.contains(_metodoPago)) {
            _metodoPago = 'whatsapp';
          }


          final config = perfil['config_pago'] ?? {};
          _titularController.text = config['titular'] ?? '';
          _rutController.text = config['rut'] ?? '';
          _bancoController.text = config['banco'] ?? '';
          _tipoCuentaController.text = config['tipo_cuenta'] ?? '';
          _numeroCuentaController.text = config['numero_cuenta'] ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar perfil: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _validarRut(String rut) {
    if (rut.isEmpty) return false;
    String cleanRut = rut.replaceAll('.', '').replaceAll('-', '').toUpperCase();
    if (cleanRut.length < 2) return false;

    String dv = cleanRut.substring(cleanRut.length - 1);
    String numberStr = cleanRut.substring(0, cleanRut.length - 1);

    int? number = int.tryParse(numberStr);
    if (number == null) return false;

    int sum = 0;
    int multiplier = 2;
    for (int i = numberStr.length - 1; i >= 0; i--) {
      sum += int.parse(numberStr[i]) * multiplier;
      multiplier = multiplier == 7 ? 2 : multiplier + 1;
    }

    int expectedRes = 11 - (sum % 11);
    String expectedDv;
    if (expectedRes == 11) {
      expectedDv = '0';
    } else if (expectedRes == 10) {
      expectedDv = 'K';
    } else {
      expectedDv = expectedRes.toString();
    }

    return dv == expectedDv;
  }

  Future<void> _guardarPerfil() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final user = _service.usuarioActual;
      if (user == null) return;

      final perfil = {
        'id': user.id,
        'nombre_comercial': _nombreComercialController.text.trim(),
        'whatsapp': _whatsappController.text.trim(),
        'descripcion': _descripcionController.text.trim(),
        'region': _regionController.text.trim(),
        'metodo_pago': _metodoPago,
        'config_pago': {
          'titular': _titularController.text.trim(),
          'rut': _rutController.text.trim(),
          'banco': _bancoController.text.trim(),
          'tipo_cuenta': _tipoCuentaController.text.trim(),
          'numero_cuenta': _numeroCuentaController.text.trim(),
        }
      };

      await _service.actualizarPerfil(perfil);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado correctamente')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nombreComercialController.dispose();
    _whatsappController.dispose();
    _descripcionController.dispose();
    _regionController.dispose();
    _titularController.dispose();
    _rutController.dispose();
    _bancoController.dispose();
    _tipoCuentaController.dispose();
    _numeroCuentaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const greenColor = Color(0xFF2E7D32);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil Comercial'),
        backgroundColor: greenColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: greenColor))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text('Datos Públicos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: greenColor)),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _nombreComercialController,
                    decoration: const InputDecoration(labelText: 'Nombre Comercial / Tienda', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Ingresa el nombre de tu negocio' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _whatsappController,
                    decoration: const InputDecoration(labelText: 'WhatsApp (Ej: 56912345678)', border: OutlineInputBorder()),
                    keyboardType: TextInputType.phone,
                    validator: (v) => v!.isEmpty ? 'Requerido para contacto' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _regionController,
                    decoration: const InputDecoration(labelText: 'Región de origen', border: OutlineInputBorder()),
                    validator: (v) => v!.isEmpty ? 'Indica tu región' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _descripcionController,
                    decoration: const InputDecoration(labelText: 'Sobre mis productos...', border: OutlineInputBorder()),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 30),
                  const Divider(),
                  const SizedBox(height: 10),
                  const Text('Configuración de Pagos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: greenColor)),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    initialValue: _metodoPago,
                    decoration: const InputDecoration(
                      labelText: '¿Cómo prefieres recibir tus pagos?',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'whatsapp', child: Text('Solo WhatsApp')),
                      DropdownMenuItem(value: 'transferencia', child: Text('Solo Transferencia Bancaria')),
                      DropdownMenuItem(value: 'mercado_pago', child: Text('Solo Mercado Pago (Online)')),
                      DropdownMenuItem(value: 'ambos', child: Text('Ambos (Transferencia y Mercado Pago)')),
                    ],
                    onChanged: (val) => setState(() => _metodoPago = val!),
                  ),
                  if (_metodoPago == 'mercado_pago' || _metodoPago == 'ambos') ...[
                    const SizedBox(height: 10),
                    const Card(
                      color: Color(0xFFE3F2FD),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Nota: Para Mercado Pago usaremos la cuenta vinculada a la plataforma. Asegúrate de que tus datos de contacto sean correctos.', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),
                  const Text('Datos de Transferencia (Chile)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: greenColor)),
                  const SizedBox(height: 15),
                  TextFormField(controller: _titularController, decoration: const InputDecoration(labelText: 'Titular de la Cuenta')),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _rutController,
                    decoration: const InputDecoration(labelText: 'RUT (Ej: 12.345.678-9)', border: OutlineInputBorder()),
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'El RUT es necesario para transferencias';
                      if (!_validarRut(v)) return 'RUT inválido (Verifica el dígito verificador)';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(controller: _bancoController, decoration: const InputDecoration(labelText: 'Banco (Ej: BancoEstado, BCI)')),
                  const SizedBox(height: 10),
                  TextFormField(controller: _tipoCuentaController, decoration: const InputDecoration(labelText: 'Tipo de Cuenta (Ej: Cuenta RUT, Corriente)')),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _numeroCuentaController,
                    decoration: const InputDecoration(labelText: 'Número de Cuenta', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'El número de cuenta es obligatorio';
                      if (v.length < 5) return 'Número de cuenta demasiado corto';
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  // Tip BancoEstado
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tip BancoEstado: En Cuenta RUT, el número suele ser tu RUT sin dígito verificador.',
                            style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  _isSaving
                      ? const Center(child: CircularProgressIndicator(color: greenColor))
                      : ElevatedButton(
                          onPressed: _guardarPerfil,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: greenColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Guardar Cambios', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                ],
              ),
            ),
    );
  }
}