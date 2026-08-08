import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:first_app/core/network/api_config.dart';

class LocationService {
  static StreamSubscription<Position>? _positionStreamSubscription;
  
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

    // 2. Si ya hay una suscripción corriendo, la cancelamos primero para no duplicar procesos
    await detenerTrackingAutomatico();

    // 3. Configurar los ajustes de Geolocator para el segundo plano según la plataforma
    late final LocationSettings locationSettings;

    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20, // Notifica cada 20 metros recorridos
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 15),
        // Crea una notificación permanente en la barra de tareas de Android para mantener el servicio activo en background
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "SPB Móvil está registrando tu ruta de trabajo en segundo plano.",
          notificationTitle: "Rastreo de ubicación activo",
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.fitness,
        distanceFilter: 20, // Notifica cada 20 metros recorridos
        pauseLocationUpdatesAutomatically: true,
        // Habilita el indicador azul de localización en la barra de estado de iOS cuando la app se minimiza
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      );
    }

    // 4. Iniciar la escucha del Stream de geolocalización
    try {
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((Position position) async {
        debugPrint('Ubicación obtenida automáticamente: ${position.latitude}, ${position.longitude}');
        
        // Enviar coordenadas a la base de datos mediante la API PHP
        bool enviado = await enviarUbicacion(idUsuario, position, token: token);
        if (enviado) {
          debugPrint('Ubicación reportada exitosamente al panel.');
        } else {
          debugPrint('Error al enviar la ubicación al panel.');
        }
      }, onError: (dynamic error) {
        debugPrint('Error en el flujo de ubicación: $error');
      });

      trackingActivoNotifier.value = true;
      debugPrint('Tracking automático activado con éxito.');
    } catch (e) {
      debugPrint('No se pudo inicializar el stream de ubicación: $e');
    }
  }

  /// Detiene el rastreo automático de ubicación.
  static Future<void> detenerTrackingAutomatico() async {
    if (_positionStreamSubscription != null) {
      await _positionStreamSubscription!.cancel();
      _positionStreamSubscription = null;
      trackingActivoNotifier.value = false;
      debugPrint('Tracking automático detenido.');
    }
  }

  /// Obtiene la ubicación actual del usuario una única vez.
  /// Retorna `null` si falla u ocurre algún error o falta de permisos.
  static Future<Position?> obtenerUbicacionActual() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }

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

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        return body['success'] == true;
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
}
