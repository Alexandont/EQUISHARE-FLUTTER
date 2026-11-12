import 'package:flutter/foundation.dart';

/// Configuración general de la app.
class Config {
  Config._();

  static const String version = '0.16.0 (Flutter)';

  /// Para ejecutar sin Google Maps: flutter run --dart-define=MAPAS=false
  static const bool mapasActivos = bool.fromEnvironment('MAPAS', defaultValue: true);

  /// En el emulador de Android la PC se llama 10.0.2.2; en el navegador es localhost.
  static String get urlServidorPorDefecto => kIsWeb ? 'http://localhost:3000/' : 'http://10.0.2.2:3000/';

  /// Centro de Trujillo (posición inicial de los mapas).
  static const double trujilloLat = -8.1116;
  static const double trujilloLng = -79.0287;
}
