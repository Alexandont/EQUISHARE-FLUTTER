import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'config.dart';
import 'contenedor.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var firebaseActivo = false;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    firebaseActivo = true;
  } catch (e) {
    debugPrint('EQUISHARE: Firebase no está configurado, se usa el modo demostración. Detalle: $e');
  }

  final mapasActivos = Config.mapasActivos && await _hayClaveMaps();
  final contenedor = await Contenedor.crear(firebaseActivo: firebaseActivo, mapasActivos: mapasActivos);
  runApp(EquishareApp(contenedor: contenedor));
}

/// Igual que MAPS_ENABLED en Kotlin: si falta MAPS_API_KEY en android/local.properties, la app muestra
/// la lista de equipos en lugar de un mapa gris.
Future<bool> _hayClaveMaps() async {
  try {
    return await const MethodChannel('equishare/configuracion').invokeMethod<bool>('hayClaveMaps') ?? true;
  } catch (_) {
    return true; // En la web (u otra plataforma sin el canal) se usa la configuración normal.
  }
}
