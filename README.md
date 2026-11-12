# EQUISHARE (Flutter) — versión 0.16.0

Migración a Flutter/Dart de la app Android EQUISHARE (Kotlin + Jetpack Compose, MVVM).
Consume la misma API Node.js (`equishare-api`) y el mismo proyecto de Firebase (`equishare-upn`).

## Requisitos
- Flutter 3.47 o superior (Dart 3.13).
- Emulador o teléfono Android 8.0 (API 26) o superior.
- Servidor `equishare-api` encendido en la PC (`http://10.0.2.2:3000/` desde el emulador).

## Configuración local (no se sube al repositorio)
Archivo `android/local.properties`:

```
MAPS_API_KEY=tu_clave_de_google_maps
```

Sin esa clave la app funciona igual, pero muestra la lista de equipos en lugar del mapa
(mismo comportamiento que la versión Kotlin).

## Comandos
```
flutter pub get
flutter analyze
flutter test
flutter run
flutter build apk --release
```

## Seguridad
- `android:allowBackup="false"`: los datos de la sesión no se copian a la nube del teléfono.
- Versión final: solo HTTPS, salvo el servidor local del emulador (`10.0.2.2` y `localhost`).
- Versión de depuración: permite HTTP para probar con el servidor en la red local.
