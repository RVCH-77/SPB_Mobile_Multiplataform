import 'package:flutter/foundation.dart';
import 'package:first_app/features/delivery_status/data/delivery_repository.dart';
import 'package:first_app/features/delivery_status/models/paquete_model.dart';

class DeliveryViewModel extends ChangeNotifier {
  final DeliveryRepository _repository;
  final int idRuta;
  final int idChofer;
  final String? token;

  DeliveryViewModel({
    required DeliveryRepository repository,
    required this.idRuta,
    required this.idChofer,
    this.token,
  }) : _repository = repository;

  List<PaqueteModel> _paquetes = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _currentIndex = 0;
  Map<String, dynamic> _rutaInfo = {};
  Map<String, dynamic> _resumen = {};

  List<PaqueteModel> get paquetes => _paquetes;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get currentIndex => _currentIndex;
  Map<String, dynamic> get rutaInfo => _rutaInfo;
  Map<String, dynamic> get resumen => _resumen;

  /// Retorna el paquete activo en la vista "Uno por Uno"
  PaqueteModel? get activePaquete =>
      (_paquetes.isNotEmpty && _currentIndex >= 0 && _currentIndex < _paquetes.length)
          ? _paquetes[_currentIndex]
          : null;

  /// Retorna si todos los paquetes asignados ya han sido procesados
  bool get allCompleted =>
      _paquetes.isNotEmpty &&
      _paquetes.every((p) => p.estatus == 'exitoso' || p.estatus == 'fallido');

  int get totalPaquetes => _paquetes.length;
  int get exitososCount => _paquetes.where((p) => p.estatus == 'exitoso').length;
  int get fallidosCount => _paquetes.where((p) => p.estatus == 'fallido').length;
  int get pendientesCount => _paquetes.where((p) => p.estatus == 'pendiente').length;

  /// Carga la lista de paquetes y detalles desde la API
  Future<void> loadPaquetes() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _repository.obtenerDetallesRuta(idRuta, idChofer, token: token);
      _rutaInfo = data['ruta'] as Map<String, dynamic>? ?? {};
      _resumen = data['resumen'] as Map<String, dynamic>? ?? {};
      _paquetes = data['paquetes'] as List<PaqueteModel>? ?? [];

      // Posicionar en el primer paquete PENDIENTE
      _autoPosicionarPrimerPendiente();
    } on DeliveryException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Error inesperado al cargar los paquetes de la ruta.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Busca el primer paquete pendiente y se posiciona en él
  void _autoPosicionarPrimerPendiente() {
    final index = _paquetes.indexWhere((p) => p.estatus == 'pendiente');
    if (index != -1) {
      _currentIndex = index;
    } else {
      _currentIndex = 0; // Si no hay pendientes, ir al primero
    }
  }

  /// Permite cambiar manualmente de paquete en la UI
  void setIndex(int index) {
    if (index >= 0 && index < _paquetes.length) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  /// Registra la entrega y avanza al siguiente paquete pendiente
  Future<bool> registrarEntrega({
    required int idPaquete,
    required String estatus,
    String? codigoEscaneado,
    String? motivoFallo,
    String? fotoEvidenciaBase64,
    double? latitud,
    double? longitud,
    double? precision,
    bool? visitaDomiciliaria,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final paqueteActualizado = await _repository.actualizarEntrega(
        idPaquete: idPaquete,
        idRuta: idRuta,
        idChofer: idChofer,
        estatus: estatus,
        codigoEscaneado: codigoEscaneado,
        motivoFallo: motivoFallo,
        fotoEvidenciaBase64: fotoEvidenciaBase64,
        latitud: latitud,
        longitud: longitud,
        precision: precision,
        visitaDomiciliaria: visitaDomiciliaria,
        token: token,
      );

      // Actualizar el paquete en la lista local
      final localIdx = _paquetes.indexWhere((p) => p.idPaquete == idPaquete);
      if (localIdx != -1) {
        _paquetes[localIdx] = paqueteActualizado;
      }

      // Buscar el siguiente paquete pendiente
      _avanzarAlSiguientePendiente();
      _isLoading = false;
      notifyListeners();
      return true;
    } on DeliveryException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Ocurrió un error inesperado al registrar la entrega.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Busca el siguiente pendiente a partir de la posición actual, si no hay, busca desde el principio
  void _avanzarAlSiguientePendiente() {
    // Buscar adelante
    int nextIdx = -1;
    for (int i = _currentIndex + 1; i < _paquetes.length; i++) {
      if (_paquetes[i].estatus == 'pendiente') {
        nextIdx = i;
        break;
      }
    }
    // Si no encontró adelante, buscar desde el principio
    if (nextIdx == -1) {
      for (int i = 0; i < _currentIndex; i++) {
        if (_paquetes[i].estatus == 'pendiente') {
          nextIdx = i;
          break;
        }
      }
    }

    if (nextIdx != -1) {
      _currentIndex = nextIdx;
    }
    // Si no hay ningún pendiente, se mantiene en el actual
  }

  /// Permite buscar por código físico o guía y saltar a ese paquete directamente
  bool buscarYSaltarAPaquete(String codigo) {
    if (codigo.trim().isEmpty) return false;
    final term = codigo.trim().toLowerCase();

    final index = _paquetes.indexWhere((p) =>
        p.codigoPaquete.toLowerCase() == term ||
        (p.guiaFisicaSupervisor?.toLowerCase() == term) ||
        (p.guiaFisicaOperador?.toLowerCase() == term));

    if (index != -1) {
      _currentIndex = index;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Inicia la ruta enviando el kilometraje inicial y la foto
  Future<bool> iniciarRuta(double kmInicial, String fotoPath) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _repository.actualizarEstadoRuta(
        idRuta: idRuta,
        idChofer: idChofer,
        accion: 'iniciar_ruta',
        kilometraje: kmInicial,
        fotoPath1: fotoPath,
        token: token,
      );
      if (success) {
        await loadPaquetes();
        return true;
      }
      return false;
    } on DeliveryException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Error al intentar iniciar la ruta.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Finaliza la ruta enviando el kilometraje final, visitados y fotos de evidencia
  Future<bool> finalizarRuta(
    double kmFinal,
    int domiciliosVisitados,
    String fotoKmFinalPath,
    String fotoCierrePath,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _repository.actualizarEstadoRuta(
        idRuta: idRuta,
        idChofer: idChofer,
        accion: 'finalizar_ruta',
        kilometraje: kmFinal,
        domiciliosVisitados: domiciliosVisitados,
        fotoPath1: fotoKmFinalPath,
        fotoPath2: fotoCierrePath,
        token: token,
      );
      _isLoading = false;
      notifyListeners();
      return success;
    } on DeliveryException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Error al intentar finalizar la ruta.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
