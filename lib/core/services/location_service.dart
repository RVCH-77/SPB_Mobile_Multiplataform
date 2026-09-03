import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:first_app/core/network/api_config.dart';

class LocationService {
  static StreamSubscription<Position>? _positionStreamSubscription;
  static StreamSubscription<ServiceStatus>? _serviceStatusSubscription;
  static Timer? _trackingTimer;
  static Position? _ultimaPosicion;
  static GlobalKey<NavigatorState>? navigatorKey;
  static bool _dialogoGpsAbierto = false;
  
  /// Notificador reactivo para saber en la UI si el tracking está activo o apagado.
  static final ValueNotifier<bool> trackingActivoNotifier = ValueNotifier<bool>(false);

  /// Solicita los permisos de ubicación al usuario de forma nativa.
  /// Si el GPS está apagado, le pide al usuario activarlo y le abre la configuración nativa del GPS.
  static Future<bool> solicitarPermisosUbicacion(BuildContext context) async {
    // 1. Verificar si los servicios de localización (GPS) están habilitados en el dispositivo.
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        // Alerta personalizada para abrir la configuración nativa del GPS
        bool abrirGps = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.gps_off, color: Colors.orange, size: 28),
                  SizedBox(width: 8),
                  Text('GPS Desactivado'),
                ],
              ),
              content: const Text(
                'Para registrar tu ruta de trabajo en tiempo real, activa el servicio de ubicación (GPS) de tu dispositivo.',
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Activar GPS'),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        ) ?? false;

        if (abrirGps) {
          // Abre la pantalla de ajustes nativos de GPS en Android/iOS
          await Geolocator.openLocationSettings();
        }
      }
      return false;
    }

    // 2. Verificar los permisos actuales de la aplicación
    LocationPermission permission = await Geolocator.checkPermission();

    // Si ya tiene permisos, retornamos true
    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      return true;
    }

    // Si los permisos fueron denegados permanentemente, no se puede lanzar la alerta nativa.
    // Debemos alertarle que vaya a Ajustes de la aplicación.
    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        _mostrarDialogoAjustes(context);
      }
      return false;
    }

    // Si están denegados (primera vez o estado inicial), lanzamos la alerta nativa directamente
    if (permission == LocationPermission.denied) {
      // Dispara la ventana nativa de iOS o Android inmediatamente
      permission = await Geolocator.requestPermission();
      
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        return true;
      } else if (permission == LocationPermission.deniedForever) {
        if (context.mounted) {
          _mostrarDialogoAjustes(context);
        }
      } else {
        if (context.mounted) {
          _mostrarSnackBar(context, 'El permiso de ubicación fue denegado.');
        }
      }
    }

    return false;
  }

  /// Inicia el rastreo de ubicación automático en segundo plano.
  /// Escucha los cambios del sensor y los reporta automáticamente a la API en PHP.
  static Future<void> iniciarTrackingAutomatico(BuildContext context, int idUsuario, {String? token}) async {
    // 1. Asegurar permisos antes de arrancar
    bool hasPermission = await solicitarPermisosUbicacion(context);
    if (!hasPermission) {
      debugPrint('No se pudo iniciar el tracking automático por falta de permisos o GPS apagado.');
      return;
    }

    // 2. Si ya hay una suscripción o temporizador corriendo, los cancelamos primero para no duplicar procesos
    await detenerTrackingAutomatico();

    // 3. Obtener y enviar ubicación inicial de inmediato (evita esperar el primer minuto del timer)
    try {
      final Position? posInicial = await obtenerUbicacionActual();
      if (posInicial != null) {
        _ultimaPosicion = posInicial;
        debugPrint('Ubicación inicial obtenida: ${posInicial.latitude}, ${posInicial.longitude}');
        await enviarUbicacion(idUsuario, posInicial, token: token);
      }
    } catch (e) {
      debugPrint('Error al enviar la ubicación inicial: $e');
    }

    // 4. Configurar los ajustes de Geolocator para el segundo plano según la plataforma
    late final LocationSettings locationSettings;

    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Filtro más corto para actualizar la caché más seguido si hay movimiento
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 15),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.fitness,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: true,
        // Habilita el indicador azul de localización en la barra de estado de iOS cuando la app se minimiza
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
    }

    // 5. Iniciar la escucha del Stream de geolocalización para actualizar _ultimaPosicion en caché
    try {
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((Position position) {
        _ultimaPosicion = position;
        debugPrint('Ubicación actualizada en caché: ${position.latitude}, ${position.longitude}');
      }, onError: (dynamic error) {
        debugPrint('Error en el flujo de ubicación: $error');
        if (error is LocationServiceDisabledException || error.toString().contains('disabled')) {
          mostrarAlertaGpsDesactivadoGlobal();
        }
      });

      // 6. Configurar el Timer periódico para enviar la ubicación cada 1 minuto
      _trackingTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
        Position? posAEnviar = _ultimaPosicion;
        if (posAEnviar == null) {
          debugPrint('Caché vacía, intentando obtener ubicación en tiempo real...');
          posAEnviar = await obtenerUbicacionActual();
        }
        if (posAEnviar != null) {
          debugPrint('Timer de 1 min: Enviando ubicación: ${posAEnviar.latitude}, ${posAEnviar.longitude}');
          bool enviado = await enviarUbicacion(idUsuario, posAEnviar, token: token);
          if (enviado) {
            debugPrint('Ubicación reportada exitosamente por el Timer.');
          } else {
            debugPrint('Error al enviar la ubicación en el Timer.');
          }
        } else {
          debugPrint('Timer de 1 min: No se pudo obtener ninguna ubicación para enviar.');
        }
      });

      // Escuchar cambios del servicio GPS (activado/desactivado en el sistema)
      _serviceStatusSubscription ??= Geolocator.getServiceStatusStream().listen((ServiceStatus status) {
        if (status == ServiceStatus.disabled) {
          mostrarAlertaGpsDesactivadoGlobal();
        } else if (status == ServiceStatus.enabled) {
          trackingActivoNotifier.value = true;
        }
      });

      trackingActivoNotifier.value = true;
      debugPrint('Tracking automático con Timer de 1 min activado con éxito.');
    } catch (e) {
      debugPrint('No se pudo inicializar el stream de ubicación: $e');
    }
  }

  /// Detiene el rastreo automático de ubicación.
  static Future<void> detenerTrackingAutomatico() async {
    if (_trackingTimer != null) {
      _trackingTimer!.cancel();
      _trackingTimer = null;
      debugPrint('Timer de tracking cancelado.');
    }
    _ultimaPosicion = null;

    if (_positionStreamSubscription != null) {
      await _positionStreamSubscription!.cancel();
      _positionStreamSubscription = null;
      trackingActivoNotifier.value = false;
      debugPrint('Tracking automático detenido.');
    }
    if (_serviceStatusSubscription != null) {
      await _serviceStatusSubscription!.cancel();
      _serviceStatusSubscription = null;
    }
  }

  /// Obtiene la ubicación actual del usuario una única vez.
  /// Retorna `null` si falla u ocurre algún error o falta de permisos.
  static Future<Position?> obtenerUbicacionActual() async {
    try {
      // 1. Si el tracking en segundo plano está activo y tenemos una ubicación reciente (menos de 5 minutos),
      // la usamos de inmediato. Esto evita que el GPS se recalcule desde cero dentro de edificios o casas
      // (donde se pierde la señal de los satélites directos, dando un margen de error de ~40m o quedándose en espera).
      if (_ultimaPosicion != null) {
        final diferenciaTiempo = DateTime.now().difference(_ultimaPosicion!.timestamp);
        if (diferenciaTiempo.inMinutes < 5) {
          debugPrint('Ubicación obtenida de caché caliente (precisión del sensor reciente): ${_ultimaPosicion!.latitude}, ${_ultimaPosicion!.longitude}');
          return _ultimaPosicion;
        }
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }

      // 2. Si no hay posición reciente en caché, solicitamos una nueva al GPS
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
    } catch (e) {
      debugPrint('Error al obtener la ubicación actual: $e');
      return null;
    }
  }

  /// Envía las coordenadas del operador al backend PHP.
  static Future<bool> enviarUbicacion(int idUsuario, Position position, {String? token}) async {
    try {
      final response = await http.post(
        ApiConfig.guardarUbicacionUri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'id_usuario': idUsuario,
          'latitud': position.latitude,
          'longitud': position.longitude,
          'accuracy': position.accuracy,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }),
      );

      if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
        try {
          final dynamic body = jsonDecode(response.body);
          if (body is Map<String, dynamic>) {
            return body['success'] == true;
          }
        } catch (e) {
          debugPrint('Error al decodificar respuesta de ubicación: $e');
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error de red al enviar la ubicación al panel: $e');
      return false;
    }
  }

  /// Diálogo que se muestra si los permisos están bloqueados en el sistema.
  static void _mostrarDialogoAjustes(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.settings, color: Colors.redAccent, size: 28),
              SizedBox(width: 8),
              Text('Permisos Bloqueados'),
            ],
          ),
          content: const Text(
            'Has denegado el acceso a la ubicación de forma permanente. Para continuar usando las funciones de tracking, ve a la configuración de la aplicación en tu celular y activa la localización manualmente.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Ir a Ajustes'),
              onPressed: () {
                Navigator.of(context).pop();
                Geolocator.openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }

  static void _mostrarSnackBar(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Muestra una alerta global informando al usuario que debe reactivar su GPS
  static void mostrarAlertaGpsDesactivadoGlobal() async {
    final context = navigatorKey?.currentState?.overlay?.context;
    if (context == null || !context.mounted) return;
    if (_dialogoGpsAbierto) return;

    _dialogoGpsAbierto = true;
    trackingActivoNotifier.value = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.gps_off, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text('GPS Desactivado'),
            ],
          ),
          content: const Text(
            'Se ha desactivado la ubicación. Para continuar reportando tu ruta en tiempo real, activa el servicio de ubicación (GPS) de tu dispositivo.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Entendido', style: TextStyle(color: Colors.grey)),
              onPressed: () {
                _dialogoGpsAbierto = false;
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7A1C2E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Activar GPS'),
              onPressed: () async {
                _dialogoGpsAbierto = false;
                Navigator.of(context).pop();
                await Geolocator.openLocationSettings();
              },
            ),
          ],
        );
      },
    );
  }
}
