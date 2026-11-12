package com.equishare.equishare_flutter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Igual que BuildConfig.MAPS_ENABLED de la versión Kotlin: avisa a Dart si hay clave de Google Maps.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "equishare/configuracion")
            .setMethodCallHandler { llamada, resultado ->
                if (llamada.method == "hayClaveMaps") {
                    resultado.success(BuildConfig.MAPS_ENABLED)
                } else {
                    resultado.notImplemented()
                }
            }
    }
}
