import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:geolocator/geolocator.dart';
import 'package:first_app/core/theme/app_colors.dart';
import 'package:first_app/core/services/location_service.dart';
import 'package:first_app/features/delivery_status/presentation/delivery_view_model.dart';
import 'package:first_app/features/delivery_status/presentation/cerrar_ruta_dialog.dart';
import 'package:first_app/features/delivery_status/models/paquete_model.dart';

class DeliveryPage extends StatefulWidget {
  final DeliveryViewModel viewModel;

  const DeliveryPage({super.key, required this.viewModel});

  @override
  State<DeliveryPage> createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _manualCodeController = TextEditingController();
  
  // Guardamos temporalmente el código escaneado en campo para el paquete activo
  // Clave: idPaquete, Valor: código escaneado
  final Map<int, String> _scannedCodesInField = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.viewModel.loadPaquetes();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _manualCodeController.dispose();
    super.dispose();
  }

  // Abre el lector de cámara para escanear un código de barras
  Future<String?> _openScanner() async {
    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.8,
              child: Column(
                children: [
                  AppBar(
                    backgroundColor: Colors.grey.shade900,
                    title: const Text('Escanear Guía Física', style: TextStyle(color: Colors.white)),
                    leading: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.keyboard, color: Colors.white),
                        onPressed: () async {
                          // Entrada manual
                          _manualCodeController.clear();
                          final manualCode = await showDialog<String>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Ingresar Código Manual'),
                              content: TextField(
                                controller: _manualCodeController,
                                decoration: const InputDecoration(
                                  labelText: 'Código de barras / Guía',
                                  hintText: 'Ej. 9786079250614',
                                ),
                                autofocus: true,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('CANCELAR'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context, _manualCodeController.text);
                                  },
                                  child: const Text('ACEPTAR'),
                                ),
                              ],
                            ),
                          );
                          if (manualCode != null && manualCode.trim().isNotEmpty) {
                            if (mounted) {
                              Navigator.pop(context, manualCode.trim());
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        MobileScanner(
                          onDetect: (capture) {
                            final List<Barcode> barcodes = capture.barcodes;
                            for (final barcode in barcodes) {
                              if (barcode.rawValue != null) {
                                final String code = barcode.rawValue!;
                                Navigator.pop(context, code);
                                break;
                              }
                            }
                          },
                        ),
                        // Cuadro de enfoque de guía visual
                        Container(
                          width: 280,
                          height: 120,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.green, width: 2.0),
                            color: Colors.transparent,
                          ),
                        ),
                        const Positioned(
                          bottom: 40,
                          child: Text(
                            'Alinea el código de barras dentro del recuadro',
                            style: TextStyle(color: Colors.white, fontSize: 13.0, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Flujo para asociar/escanear la guía del paquete activo
  Future<void> _escanearGuiaActiva(PaqueteModel paquete) async {
    final code = await _openScanner();
    if (code != null && code.isNotEmpty) {
      setState(() {
        _scannedCodesInField[paquete.idPaquete] = code;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Guía vinculada temporalmente: $code'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Flujo para realizar una entrega exitosa
  Future<void> _entregarConFoto(PaqueteModel paquete) async {
    final String? codigoEscaneado = _scannedCodesInField[paquete.idPaquete];
    
    // Alerta/Confirmación si no ha escaneado la guía física
    if (codigoEscaneado == null && paquete.guiaFisicaSupervisor != null) {
      final proceder = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Proceder sin escaneo?'),
          content: const Text(
            'No has escaneado la guía física de este paquete. ¿Deseas entregar el paquete sin vincular el código de barras?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('PROCEDER'),
            ),
          ],
        ),
      ) ?? false;

      if (!proceder) return;
    }

    // Capturar foto de evidencia
    XFile? file;
    try {
      final ImagePicker picker = ImagePicker();
      file = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        maxHeight: 720,
        imageQuality: 70,
      );
    } catch (e) {
      _showErrorSnackBar('Error al abrir la cámara: $e');
      return;
    }

    if (file == null) return; // Canceló la foto

    // Mostrar loader
    _showProgressOverlay();

    // Obtener GPS
    double? lat;
    double? lng;
    double? accuracy;
    try {
      final Position? pos = await LocationService.obtenerUbicacionActual();
      if (pos != null) {
        lat = pos.latitude;
        lng = pos.longitude;
        accuracy = pos.accuracy;
      }
    } catch (e) {
      debugPrint('No se pudo obtener el GPS: $e');
    }

    try {
      final List<int> bytes = await File(file.path).readAsBytes();
      final String base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      final success = await widget.viewModel.registrarEntrega(
        idPaquete: paquete.idPaquete,
        estatus: 'exitoso',
        codigoEscaneado: codigoEscaneado ?? paquete.guiaFisicaSupervisor,
        fotoEvidenciaBase64: base64Image,
        latitud: lat,
        longitud: lng,
        precision: accuracy,
      );

      // Ocultar loader
      if (mounted) Navigator.pop(context);

      if (success) {
        _showSuccessSnackBar('Entrega registrada exitosamente');
      } else {
        _showErrorSnackBar(widget.viewModel.errorMessage ?? 'Error al registrar entrega');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showErrorSnackBar('Error al procesar la entrega: $e');
    }
  }

  // Flujo para reportar fallo en la entrega
  Future<void> _reportarFallo(PaqueteModel paquete) async {
    // 1. Mostrar diálogo de selección de motivo de fallo
    final Map<String, dynamic>? dialogResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        String seleccionado = 'Domicilio cerrado / Cliente ausente';
        bool visitaChecked = true;
        final motivos = [
          'Domicilio cerrado / Cliente ausente',
          'Dirección incorrecta o no encontrada',
          'Rechazado por el cliente',
          'Paquete dañado',
          'Otro / Problemas logísticos',
        ];
        return AlertDialog(
          title: const Text('Motivo de No Entrega'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...motivos.map((m) {
                      return RadioListTile<String>(
                        title: Text(m, style: const TextStyle(fontSize: 14.0)),
                        value: m,
                        groupValue: seleccionado,
                        activeColor: AppColors.primary,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              seleccionado = val;
                            });
                          }
                        },
                      );
                    }).toList(),
                    const Divider(),
                    CheckboxListTile(
                      title: const Text(
                        '¿Se realizó visita domiciliaria?',
                        style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'Actívalo si acudiste físicamente al domicilio del cliente',
                        style: TextStyle(fontSize: 10.0),
                      ),
                      value: visitaChecked,
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setDialogState(() {
                          visitaChecked = val ?? false;
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, {
                'motivo': seleccionado,
                'visita': visitaChecked,
              }),
              child: const Text('ACEPTAR'),
            ),
          ],
        );
      },
    );

    if (dialogResult == null) return;
    final String motivo = dialogResult['motivo'] as String;
    final bool visitaDomiciliaria = dialogResult['visita'] as bool;

    // Capturar foto de fachada/evidencia
    XFile? file;
    try {
      final ImagePicker picker = ImagePicker();
      file = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        maxHeight: 720,
        imageQuality: 70,
      );
    } catch (e) {
      _showErrorSnackBar('Error al abrir la cámara: $e');
      return;
    }

    if (file == null) return; // Canceló

    _showProgressOverlay();

    // Obtener GPS
    double? lat;
    double? lng;
    double? accuracy;
    try {
      final Position? pos = await LocationService.obtenerUbicacionActual();
      if (pos != null) {
        lat = pos.latitude;
        lng = pos.longitude;
        accuracy = pos.accuracy;
      }
    } catch (e) {
      debugPrint('No se pudo obtener el GPS: $e');
    }

    try {
      final List<int> bytes = await File(file.path).readAsBytes();
      final String base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      final success = await widget.viewModel.registrarEntrega(
        idPaquete: paquete.idPaquete,
        estatus: 'fallido',
        codigoEscaneado: _scannedCodesInField[paquete.idPaquete] ?? paquete.guiaFisicaSupervisor,
        motivoFallo: motivo,
        fotoEvidenciaBase64: base64Image,
        latitud: lat,
        longitud: lng,
        precision: accuracy,
        visitaDomiciliaria: visitaDomiciliaria,
      );

      if (mounted) Navigator.pop(context);

      if (success) {
        _showSuccessSnackBar('Fallo registrado correctamente');
      } else {
        _showErrorSnackBar(widget.viewModel.errorMessage ?? 'Error al registrar fallo');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showErrorSnackBar('Error al procesar la no entrega: $e');
    }
  }

  // Abre el CerrarRutaDialog
  Future<void> _cerrarRuta() async {
    final double kmInicial = double.tryParse(widget.viewModel.rutaInfo['km_inicial']?.toString() ?? '') ??
        double.tryParse(widget.viewModel.rutaInfo['kmInicial']?.toString() ?? '') ??
        0.0;

    final closed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CerrarRutaDialog(
        viewModel: widget.viewModel,
        kmInicial: kmInicial,
        fallidosCount: widget.viewModel.fallidosCount,
      ),
    );

    if (closed == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ruta finalizada y cerrada con éxito.'),
            backgroundColor: AppColors.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(true); // Regresar a la lista de rutas
      }
    }
  }

  void _showProgressOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)),
                SizedBox(height: 16),
                Text('Procesando datos y subiendo evidencia...', style: TextStyle(fontSize: 13.0)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Entrega de Paquetes - Ruta ${widget.viewModel.idRuta}'),
        elevation: 0,
      ),
      body: ListenableBuilder(
        listenable: widget.viewModel,
        builder: (context, _) {
          final activePaquete = widget.viewModel.activePaquete;

          if (widget.viewModel.isLoading && widget.viewModel.paquetes.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)),
            );
          }

          if (widget.viewModel.errorMessage != null && widget.viewModel.paquetes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.errorColor),
                    const SizedBox(height: 12),
                    Text(
                      widget.viewModel.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => widget.viewModel.loadPaquetes(),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (widget.viewModel.paquetes.isEmpty) {
            return const Center(
              child: Text('No hay paquetes asignados para esta ruta.'),
            );
          }

          return RefreshIndicator(
            onRefresh: () => widget.viewModel.loadPaquetes(),
            color: AppColors.primary,
            child: Column(
              children: [
                // 1. Panel de Progreso
                _buildProgressHeader(),

                // 2. Buscador y Escáner
                _buildSearchAndScanBar(),

                // 3. Contenedor de Tarjeta Activa (Uno por Uno)
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (activePaquete != null) ...[
                          _buildActivePaqueteCard(activePaquete),
                        ] else ...[
                          // Todos procesados pero no cerrado
                          _buildAllCompletedCard(),
                        ],
                        const SizedBox(height: 24.0),
                        
                        // Lista rápida/Selector horizontal de paquetes
                        _buildHorizontalSelector(),
                      ],
                    ),
                  ),
                ),

                // 4. Panel de Cierre de Ruta
                if (widget.viewModel.allCompleted) ...[
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton.icon(
                        onPressed: _cerrarRuta,
                        icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                        label: const Text(
                          'FINALIZAR Y CERRAR RUTA',
                          style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                          elevation: 3,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgressHeader() {
    final double percentage = widget.viewModel.totalPaquetes > 0
        ? (widget.viewModel.exitososCount + widget.viewModel.fallidosCount) / widget.viewModel.totalPaquetes
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progreso de Entregas',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800),
              ),
              Text(
                '${widget.viewModel.exitososCount + widget.viewModel.fallidosCount} / ${widget.viewModel.totalPaquetes} (${(percentage * 100).toStringAsFixed(0)}%)',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          ClipRRect(
            borderRadius: BorderRadius.circular(10.0),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 10.0,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 12.0),
          // Contadores rápidos
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCounterBadge('${widget.viewModel.pendientesCount} pnd', Colors.grey.shade600, Colors.grey.shade100),
              _buildCounterBadge('${widget.viewModel.exitososCount} ext', AppColors.successColor, Colors.green.shade50),
              _buildCounterBadge('${widget.viewModel.fallidosCount} fal', AppColors.errorColor, Colors.red.shade50),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCounterBadge(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Text(
        label,
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12.0),
      ),
    );
  }

  Widget _buildSearchAndScanBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Colors.grey.shade50,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar paquete por folio o guía...',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(vertical: 0.0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
                fillColor: Colors.white,
                filled: true,
              ),
              onChanged: (val) {
                widget.viewModel.buscarYSaltarAPaquete(val);
              },
            ),
          ),
          const SizedBox(width: 8.0),
          InkWell(
            onTap: () async {
              final code = await _openScanner();
              if (code != null && code.isNotEmpty) {
                _searchController.text = code;
                final found = widget.viewModel.buscarYSaltarAPaquete(code);
                if (found) {
                  final activePaq = widget.viewModel.activePaquete;
                  if (activePaq != null) {
                    setState(() {
                      _scannedCodesInField[activePaq.idPaquete] = code;
                    });
                    if (activePaq.estatus == 'pendiente') {
                      _showSuccessSnackBar('Guía vinculada. Selecciona "ENTREGAR" o "NO ENTREGAR" abajo.');
                    } else {
                      _showSuccessSnackBar('El paquete ya está marcado como ${activePaq.estatus}');
                    }
                  }
                } else {
                  _showErrorSnackBar('No se encontró el paquete con guía: $code');
                }
              }
            },
            borderRadius: BorderRadius.circular(10.0),
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: const Icon(Icons.qr_code_scanner, color: Colors.white),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActivePaqueteCard(PaqueteModel paquete) {
    final String? codigoEscaneado = _scannedCodesInField[paquete.idPaquete] ?? paquete.guiaFisicaOperador;
    final bool coincide = codigoEscaneado != null &&
        paquete.guiaFisicaSupervisor != null &&
        codigoEscaneado == paquete.guiaFisicaSupervisor;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Fila de encabezado de la tarjeta
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'PAQUETE ACTIVO',
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    letterSpacing: 1.0,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Text(
                    paquete.estatus.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),

            // Código Estándar Interno
            Text(
              paquete.codigoPaquete,
              style: const TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20.0),
            const Divider(),
            const SizedBox(height: 12.0),

            // Info de Guía Registrada por Supervisor
            _buildInfoRow(
              'Guía Bodega (Supervisor):',
              paquete.guiaFisicaSupervisor ?? 'Sin guía asignada',
              Icons.inventory_2_outlined,
            ),
            const SizedBox(height: 16.0),

            // Info de Guía Escaneada en Campo
            _buildValidationStatusBox(codigoEscaneado, coincide),
            const SizedBox(height: 24.0),

            // Botones de Operación del Operador
            ElevatedButton.icon(
              onPressed: () => _escanearGuiaActiva(paquete),
              icon: const Icon(Icons.qr_code_scanner, size: 20),
              label: Text(codigoEscaneado == null ? 'VINCULAR GUÍA FÍSICA' : 'RE-ESCANEAR GUÍA'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
              ),
            ),
            const SizedBox(height: 12.0),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _reportarFallo(paquete),
                    icon: const Icon(Icons.cancel_outlined, color: AppColors.errorColor),
                    label: const Text('NO ENTREGADO', style: TextStyle(color: AppColors.errorColor)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      side: const BorderSide(color: AppColors.errorColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _entregarConFoto(paquete),
                    icon: const Icon(Icons.camera_alt, color: Colors.white),
                    label: const Text('ENTREGAR', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValidationStatusBox(String? codigoEscaneado, bool coincide) {
    if (codigoEscaneado == null) {
      return Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.qr_code_scanner_outlined, color: Colors.red.shade700, size: 24),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ESCANEO PENDIENTE',
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    'Por favor, escanea el código del paquete antes de reportar.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.red.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (coincide) {
      return Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 24),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✓ GUÍA VERIFICADA',
                    style: TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    '¡Coincide! Escaneado: $codigoEscaneado',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.green.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // No coincide
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_outlined, color: Colors.amber.shade800, size: 24),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⚠️ GUÍA NO COINCIDE',
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: 2.0),
                Text(
                  'Escaneado: $codigoEscaneado (Verifica si es el paquete correcto)',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.amber.shade900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12.0, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4.0),
              Text(
                value,
                style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAllCompletedCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(Icons.check_circle, size: 56, color: AppColors.successColor),
            const SizedBox(height: 16),
            const Text(
              '¡Entregas Completadas!',
              style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            Text(
              'Has procesado todos tus paquetes asignados (${widget.viewModel.totalPaquetes}). Ya puedes proceder al cierre de la ruta.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.0, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LISTADO DE PAQUETES ASIGNADOS',
          style: TextStyle(fontSize: 11.0, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
        ),
        const SizedBox(height: 8.0),
        SizedBox(
          height: 70,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: widget.viewModel.paquetes.length,
            itemBuilder: (context, index) {
              final p = widget.viewModel.paquetes[index];
              final isCurrent = index == widget.viewModel.currentIndex;
              
              Color statusColor = Colors.grey.shade400;
              if (p.estatus == 'exitoso') statusColor = AppColors.successColor;
              if (p.estatus == 'fallido') statusColor = AppColors.errorColor;

              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        p.codigoPaquete.split('-').last,
                        style: TextStyle(
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent ? AppColors.primary : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                      )
                    ],
                  ),
                  selected: isCurrent,
                  selectedColor: AppColors.primary.withOpacity(0.15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
                  onSelected: (selected) {
                    if (selected) {
                      widget.viewModel.setIndex(index);
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
