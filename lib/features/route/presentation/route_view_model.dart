import 'package:flutter/foundation.dart';
import 'package:first_app/features/route/data/route_repository.dart';
import 'package:first_app/features/route/models/ruta_model.dart';

class RouteViewModel extends ChangeNotifier {
  final RouteRepository _repository;

  RouteViewModel({required RouteRepository repository}) : _repository = repository;

  List<RutaModel> _rutas = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<RutaModel> get rutas => _rutas;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Carga las rutas desde la API aplicando los filtros correspondientes.
  Future<void> loadRutas({
    int? idOperador,
    String? fecha,
    String? estatus,
    String? token,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final allRutas = await _repository.getRutas(
        idOperador: idOperador,
        fecha: fecha,
        estatus: estatus,
        token: token,
      );

      // Aplicar filtros locales de forma segura por si el servidor no los implementa o los ignora
      _rutas = allRutas.where((ruta) {
        // 1. Filtrar por fecha (formato YYYY-MM-DD)
        if (fecha != null && fecha.trim().isNotEmpty) {
          if (ruta.fecha.trim() != fecha.trim()) {
            return false;
          }
        }
        
        // 2. Filtrar por estatus (comparando en minúsculas)
        if (estatus != null && estatus.trim().isNotEmpty) {
          final estatusRuta = ruta.miEstatus.toLowerCase().trim();
          final estatusFiltro = estatus.toLowerCase().trim();
          if (estatusRuta != estatusFiltro) {
            return false;
          }
        }
        
        return true;
      }).toList();

    } on RouteException catch (e) {
      _errorMessage = e.message;
      _rutas = [];
    } catch (e) {
      _errorMessage = 'Ocurrió un error inesperado al cargar las rutas.';
      _rutas = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
