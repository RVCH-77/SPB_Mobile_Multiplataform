import 'package:flutter/material.dart';
import 'package:first_app/core/theme/app_colors.dart';
import 'package:first_app/features/auth/presentation/auth_view_model.dart';
import 'package:first_app/features/route/data/route_repository.dart';
import 'package:first_app/features/route/models/ruta_model.dart';
import 'package:first_app/features/route/presentation/route_view_model.dart';
import 'package:first_app/features/delivery_status/data/delivery_repository.dart';
import 'package:first_app/features/delivery_status/presentation/delivery_page.dart';
import 'package:first_app/features/delivery_status/presentation/delivery_view_model.dart';
import 'package:first_app/features/delivery_status/presentation/iniciar_ruta_dialog.dart';

class RoutePage extends StatefulWidget {
  final AuthViewModel authViewModel;

  const RoutePage({super.key, required this.authViewModel});

  @override
  State<RoutePage> createState() => _RoutePageState();
}

class _RoutePageState extends State<RoutePage> {
  late final RouteViewModel _viewModel;
  String? _selectedEstatus;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _viewModel = RouteViewModel(repository: RouteRepository());
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _loadData() {
    final user = widget.authViewModel.currentUser;
    if (user == null) return;

    String? dateStr;
    if (_selectedDate != null) {
      dateStr =
          "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";
    }

    _viewModel.loadRutas(
      idOperador: user.idChofer ?? user.idUsuario,
      fecha: dateStr,
      estatus: _selectedEstatus,
      token: user.token,
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadData();
    }
  }

  void _clearDate() {
    setState(() {
      _selectedDate = null;
    });
    _loadData();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'terminado':
      case 'completada':
        return AppColors.successColor;
      case 'en_proceso':
      case 'en progreso':
        return AppColors.warningColor;
      case 'pendiente':
      case 'activa':
      default:
        return Colors.grey.shade600;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'terminado':
      case 'completada':
        return 'Terminada';
      case 'en_proceso':
      case 'en progreso':
        return 'En Proceso';
      case 'pendiente':
      case 'activa':
      default:
        return 'Pendiente';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authViewModel.currentUser;
    final isOperador = user?.rol == 'operador';
    final canOperate = isOperador || (user?.idChofer != null && user?.idChofer != 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(isOperador ? 'Mis Rutas Asignadas' : 'Control Global de Rutas'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Sección de Filtros
          Container(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Fila de Filtro de Fecha e Info de Estado
                Row(
                  children: [
                    // Botón Selector de Fecha
                    OutlinedButton.icon(
                      onPressed: () => _selectDate(context),
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        _selectedDate == null
                            ? 'Seleccionar Fecha'
                            : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                      ),
                    ),
                    if (_selectedDate != null) ...[
                      const SizedBox(width: 4.0),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: _clearDate,
                        tooltip: 'Limpiar Fecha',
                      ),
                    ],
                    const Spacer(),
                    Text(
                      'Filtros Activos',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),

                // Desplazamiento horizontal de ChoiceChips para Estatus
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusChip('Todas', null),
                      _buildStatusChip('Pendientes', 'pendiente'),
                      _buildStatusChip('En Proceso', 'en_proceso'),
                      _buildStatusChip('Terminadas', 'terminado'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Listado de Rutas (Usa ListenableBuilder para escuchar el ViewModel)
          Expanded(
            child: ListenableBuilder(
              listenable: _viewModel,
              builder: (context, _) {
                if (_viewModel.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  );
                }

                if (_viewModel.errorMessage != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: AppColors.errorColor),
                          const SizedBox(height: 12),
                          Text(
                            _viewModel.errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadData,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (_viewModel.rutas.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.route_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No se encontraron rutas asignadas.',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _loadData(),
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _viewModel.rutas.length,
                    itemBuilder: (context, index) {
                      final ruta = _viewModel.rutas[index];
                      return _buildRutaCard(ruta, canOperate);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, String? value) {
    final isSelected = _selectedEstatus == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primary.withOpacity(0.15),
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : Colors.grey.shade700,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _selectedEstatus = value;
            });
            _loadData();
          }
        },
      ),
    );
  }

  Widget _buildRutaCard(RutaModel ruta, bool isOperador) {
    final statusColor = _getStatusColor(ruta.miEstatus);
    final statusText = _getStatusLabel(ruta.miEstatus);
    
    // Si es foránea la ponemos purpura, si es local azul
    final isForanea = ruta.tipoRuta.toLowerCase().contains('for');
    final typeColor = isForanea ? Colors.deepPurple : Colors.blue.shade700;

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            backgroundColor: Colors.white,
            collapsedBackgroundColor: Colors.white,
            title: Row(
              children: [
                Text(
                  'Ruta ${ruta.ruta}',
                  style: const TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8.0),
                // Tipo de Ruta Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Text(
                    ruta.tipoRuta,
                    style: TextStyle(
                      fontSize: 10.0,
                      fontWeight: FontWeight.bold,
                      color: typeColor,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4.0),
                      Text(
                        ruta.destino,
                        style: const TextStyle(fontSize: 13.0, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4.0),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4.0),
                      Text(
                        ruta.fecha,
                        style: const TextStyle(fontSize: 13.0, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Estatus Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 11.0,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(height: 6.0),
                // Cantidad de paquetes
                Text(
                  isOperador 
                      ? '${ruta.misPaquetes} / ${ruta.totalPaquetes} pq' 
                      : '${ruta.totalPaquetes} pq',
                  style: const TextStyle(
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            children: [
              const Divider(height: 1, indent: 16, endIndent: 16),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Detalles Generales
                    if (ruta.cliente != null) ...[
                      _buildDetailRow('Cliente:', ruta.cliente!.nombre),
                      const SizedBox(height: 6.0),
                    ],
                    if (ruta.choferPrincipal != null) ...[
                      _buildDetailRow(
                        'Chofer Principal:',
                        '${ruta.choferPrincipal!.nombre} (${ruta.choferPrincipal!.paquetesAsignados ?? 0} pq)',
                      ),
                      const SizedBox(height: 6.0),
                    ],
                    if (ruta.vehiculoId != null) ...[
                      _buildDetailRow('Vehículo ID:', ruta.vehiculoId.toString()),
                      const SizedBox(height: 6.0),
                    ],
                    _buildDetailRow('Tu Rol:', ruta.rol.toUpperCase(), valueColor: AppColors.primary),
                    
                    // Notas (Si existen)
                    if (ruta.notas.trim().isNotEmpty) ...[
                      const SizedBox(height: 12.0),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(6.0),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.amber.shade900),
                            const SizedBox(width: 6.0),
                            Expanded(
                              child: Text(
                                ruta.notas,
                                style: TextStyle(
                                  fontSize: 12.0,
                                  color: Colors.amber.shade900,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Lista de Apoyos (Para supervisor o si hay apoyos)
                    if (ruta.apoyos.isNotEmpty) ...[
                      const SizedBox(height: 12.0),
                      const Text(
                        'Conductores de Apoyo:',
                        style: TextStyle(
                          fontSize: 13.0,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Wrap(
                        spacing: 6.0,
                        runSpacing: 4.0,
                        children: ruta.apoyos.map((apoyo) {
                          return Chip(
                            backgroundColor: Colors.grey.shade50,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            label: Text(
                              '${apoyo.nombre} (${apoyo.paquetesAsignados} pq)',
                              style: const TextStyle(fontSize: 11.0),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    // Botones de Acción para el Operador
                    if (isOperador) ...[
                      const SizedBox(height: 16.0),
                      const Divider(height: 1),
                      const SizedBox(height: 12.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (ruta.miEstatus.toLowerCase() == 'pendiente') ...[
                            ElevatedButton.icon(
                              onPressed: () async {
                                final int idChofer = widget.authViewModel.currentUser?.idChofer ??
                                    widget.authViewModel.currentUser?.idUsuario ??
                                    0;
                                final deliveryVM = DeliveryViewModel(
                                  repository: DeliveryRepository(),
                                  idRuta: ruta.id,
                                  idChofer: idChofer,
                                  token: widget.authViewModel.currentUser?.token,
                                );
                                final started = await showDialog<bool>(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => IniciarRutaDialog(viewModel: deliveryVM),
                                );
                                if (started == true) {
                                  _loadData();
                                }
                              },
                              icon: const Icon(Icons.play_arrow, color: Colors.white),
                              label: const Text('INICIAR RUTA', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                              ),
                            ),
                          ] else if (ruta.miEstatus.toLowerCase() == 'en_proceso' ||
                              ruta.miEstatus.toLowerCase() == 'en progreso') ...[
                            ElevatedButton.icon(
                              onPressed: () async {
                                final int idChofer = widget.authViewModel.currentUser?.idChofer ??
                                    widget.authViewModel.currentUser?.idUsuario ??
                                    0;
                                final deliveryVM = DeliveryViewModel(
                                  repository: DeliveryRepository(),
                                  idRuta: ruta.id,
                                  idChofer: idChofer,
                                  token: widget.authViewModel.currentUser?.token,
                                );
                                final refresh = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DeliveryPage(viewModel: deliveryVM),
                                  ),
                                );
                                if (refresh == true) {
                                  _loadData();
                                }
                              },
                              icon: const Icon(Icons.delivery_dining, color: Colors.white),
                              label: const Text('IR A ENTREGAS', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                              ),
                            ),
                          ] else ...[
                            OutlinedButton.icon(
                              onPressed: null,
                              icon: const Icon(Icons.check, color: Colors.grey),
                              label: const Text('RUTA COMPLETADA'),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.0,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(width: 6.0),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13.0,
              fontWeight: FontWeight.w500,
              color: valueColor ?? const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}
