import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:first_app/core/theme/app_colors.dart';
import 'package:first_app/features/delivery_status/presentation/delivery_view_model.dart';

class CerrarRutaDialog extends StatefulWidget {
  final DeliveryViewModel viewModel;
  final double kmInicial;
  final int fallidosCount;

  const CerrarRutaDialog({
    super.key,
    required this.viewModel,
    required this.kmInicial,
    required this.fallidosCount,
  });

  @override
  State<CerrarRutaDialog> createState() => _CerrarRutaDialogState();
}

class _CerrarRutaDialogState extends State<CerrarRutaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _kmController = TextEditingController();
  final _visitadosController = TextEditingController();

  File? _imageKmFinal;
  File? _imageCierre;
  
  bool _isUploading = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    // Pre-llenar automáticamente con la cantidad de paquetes fallidos
    _visitadosController.text = widget.fallidosCount.toString();
  }

  @override
  void dispose() {
    _kmController.dispose();
    _visitadosController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto(String type, ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 720,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        setState(() {
          if (type == 'km_final') {
            _imageKmFinal = File(pickedFile.path);
          } else {
            _imageCierre = File(pickedFile.path);
          }
          _localError = null;
        });
      }
    } catch (e) {
      setState(() {
        _localError = 'Error al capturar la foto: $e';
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageKmFinal == null) {
      setState(() {
        _localError = 'Debes capturar la foto del odómetro final.';
      });
      return;
    }
    if (_imageCierre == null) {
      setState(() {
        _localError = 'Debes capturar la foto de evidencia de cierre.';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _localError = null;
    });

    try {
      final double km = double.parse(_kmController.text);
      final int visitados = int.tryParse(_visitadosController.text) ?? 0;

      final success = await widget.viewModel.finalizarRuta(
        km,
        visitados,
        _imageKmFinal!.path,
        _imageCierre!.path,
      );

      if (success) {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _localError = widget.viewModel.errorMessage ?? 'Ocurrió un error al finalizar la ruta.';
        });
      }
    } catch (e) {
      setState(() {
        _localError = 'Error al procesar las imágenes: $e';
      });
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool requireVisitados = widget.fallidosCount > 0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.stop_circle_rounded, color: AppColors.primary, size: 30),
                    const SizedBox(width: 8.0),
                    Text(
                      'Finalizar Ruta ${widget.viewModel.idRuta}',
                      style: const TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),
                const Text(
                  'Registra la lectura del odómetro final, los domicilios visitados y captura las evidencias fotográficas.',
                  style: TextStyle(fontSize: 13.0, color: Colors.grey),
                ),
                const SizedBox(height: 16.0),
                
                // Campo de Kilometraje Final
                TextFormField(
                  controller: _kmController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'KILOMETRAJE FINAL',
                    hintText: 'Ej. Mayor a ${widget.kmInicial}',
                    prefixIcon: const Icon(Icons.speed, color: AppColors.primary),
                    labelStyle: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Este campo es obligatorio';
                    }
                    final km = double.tryParse(value);
                    if (km == null || km <= 0) {
                      return 'Ingresa un kilometraje válido';
                    }
                    if (km <= widget.kmInicial) {
                      return 'El kilometraje final debe ser mayor al inicial (${widget.kmInicial})';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),

                // Campo de Domicilios Visitados
                TextFormField(
                  controller: _visitadosController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'DOMICILIOS VISITADOS ${requireVisitados ? "*" : ""}',
                    hintText: 'Ej. 2',
                    prefixIcon: const Icon(Icons.home_outlined, color: AppColors.primary),
                    labelStyle: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (requireVisitados && (value == null || value.trim().isEmpty)) {
                      return 'Obligatorio ya que hay entregas fallidas';
                    }
                    if (value != null && value.trim().isNotEmpty) {
                      final val = int.tryParse(value);
                      if (val == null || val < 0) {
                        return 'Ingresa un número entero válido >= 0';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20.0),

                // FOTOS EVIDENCIA (DOS FOTOS)
                const Text(
                  'FOTOS REQUERIDAS',
                  style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
                ),
                const SizedBox(height: 8.0),
                
                Row(
                  children: [
                    // Foto 1: KM Final
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: _imageKmFinal != null
                                ? Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8.0),
                                        child: Image.file(_imageKmFinal!, fit: BoxFit.cover),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: CircleAvatar(
                                          backgroundColor: Colors.black.withOpacity(0.6),
                                          radius: 12,
                                          child: IconButton(
                                            icon: const Icon(Icons.edit, size: 10, color: Colors.white),
                                            padding: EdgeInsets.zero,
                                            onPressed: () => _takePhoto('km_final', ImageSource.camera),
                                          ),
                                        ),
                                      )
                                    ],
                                  )
                                : InkWell(
                                    onTap: () => _takePhoto('km_final', ImageSource.camera),
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.camera_alt_outlined, size: 28, color: Colors.grey.shade600),
                                        const SizedBox(height: 4.0),
                                        const Text(
                                          'Odómetro Final',
                                          style: TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold, color: Colors.grey),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 4.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 24)),
                                onPressed: () => _takePhoto('km_final', ImageSource.gallery),
                                child: const Text('Galería', style: TextStyle(color: Colors.grey, fontSize: 10)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    // Foto 2: Evidencia de Cierre
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: _imageCierre != null
                                ? Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8.0),
                                        child: Image.file(_imageCierre!, fit: BoxFit.cover),
                                      ),
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: CircleAvatar(
                                          backgroundColor: Colors.black.withOpacity(0.6),
                                          radius: 12,
                                          child: IconButton(
                                            icon: const Icon(Icons.edit, size: 10, color: Colors.white),
                                            padding: EdgeInsets.zero,
                                            onPressed: () => _takePhoto('cierre', ImageSource.camera),
                                          ),
                                        ),
                                      )
                                    ],
                                  )
                                : InkWell(
                                    onTap: () => _takePhoto('cierre', ImageSource.camera),
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.camera_alt_outlined, size: 28, color: Colors.grey.shade600),
                                        const SizedBox(height: 4.0),
                                        const Text(
                                          'Evidencia Cierre',
                                          style: TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold, color: Colors.grey),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 4.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton(
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 24)),
                                onPressed: () => _takePhoto('cierre', ImageSource.gallery),
                                child: const Text('Galería', style: TextStyle(color: Colors.grey, fontSize: 10)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                // Mensaje de Error
                if (_localError != null) ...[
                  const SizedBox(height: 12.0),
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: AppColors.errorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(color: AppColors.errorColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      _localError!,
                      style: const TextStyle(color: AppColors.errorColor, fontSize: 12.0),
                    ),
                  ),
                ],
                const SizedBox(height: 20.0),

                // Botones de Acción
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
                      child: const Text('CANCELAR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12.0),
                    ElevatedButton(
                      onPressed: _isUploading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: _isUploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('FINALIZAR RUTA', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
