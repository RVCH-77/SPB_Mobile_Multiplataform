import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:first_app/core/theme/app_colors.dart';
import 'package:first_app/features/delivery_status/presentation/delivery_view_model.dart';

class IniciarRutaDialog extends StatefulWidget {
  final DeliveryViewModel viewModel;

  const IniciarRutaDialog({super.key, required this.viewModel});

  @override
  State<IniciarRutaDialog> createState() => _IniciarRutaDialogState();
}

class _IniciarRutaDialogState extends State<IniciarRutaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _kmController = TextEditingController();
  File? _imageFile;
  bool _isUploading = false;
  String? _localError;

  @override
  void dispose() {
    _kmController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto(ImageSource source) async {
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
          _imageFile = File(pickedFile.path);
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
    if (_imageFile == null) {
      setState(() {
        _localError = 'Debes capturar una foto del kilometraje inicial.';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _localError = null;
    });

    try {
      final double km = double.parse(_kmController.text);
      final success = await widget.viewModel.iniciarRuta(km, _imageFile!.path);

      if (success) {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _localError = widget.viewModel.errorMessage ?? 'Ocurrió un error al iniciar la ruta.';
        });
      }
    } catch (e) {
      setState(() {
        _localError = 'Error al procesar la imagen: $e';
      });
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    const Icon(Icons.play_circle_fill, color: AppColors.primary, size: 30),
                    const SizedBox(width: 8.0),
                    Text(
                      'Iniciar Ruta ${widget.viewModel.idRuta}',
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
                  'Registra el kilometraje inicial del vehículo y toma una foto clara del odómetro para iniciar.',
                  style: TextStyle(fontSize: 13.0, color: Colors.grey),
                ),
                const SizedBox(height: 16.0),
                
                // Campo de Kilometraje
                TextFormField(
                  controller: _kmController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'KILOMETRAJE INICIAL',
                    hintText: 'Ej. 45000.5',
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
                      return 'Ingresa un kilometraje válido mayor a 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20.0),

                // Vista Previa de Imagen o Botón de Captura
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: _imageFile != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: Image.file(_imageFile!, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: CircleAvatar(
                                backgroundColor: Colors.black.withOpacity(0.6),
                                radius: 16,
                                child: IconButton(
                                  icon: const Icon(Icons.edit, size: 14, color: Colors.white),
                                  onPressed: () => _takePhoto(ImageSource.camera),
                                ),
                              ),
                            )
                          ],
                        )
                      : InkWell(
                          onTap: () => _takePhoto(ImageSource.camera),
                          borderRadius: BorderRadius.circular(8.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt_outlined, size: 40, color: Colors.grey.shade600),
                              const SizedBox(height: 8.0),
                              Text(
                                'TOMAR FOTO DEL ODÓMETRO',
                                style: TextStyle(
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 8.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: () => _takePhoto(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 16, color: Colors.grey),
                      label: const Text('Subir de Galería', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
                          : const Text('INICIAR RUTA', style: TextStyle(fontWeight: FontWeight.bold)),
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
