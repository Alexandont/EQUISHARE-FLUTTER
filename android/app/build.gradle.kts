import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Valores locales que NO se suben al repositorio (android/local.properties), igual que la versión Kotlin.
val propiedadesLocales = Properties().apply {
    val archivo = rootProject.file("local.properties")
    if (archivo.exists()) archivo.inputStream().use { load(it) }
}
val mapsApiKey: String = propiedadesLocales.getProperty("MAPS_API_KEY", "").trim()

android {
    namespace = "com.equishare.equishare_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.equishare.equishare_flutter"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // La versión (0.16.0) y el número de compilación salen de pubspec.yaml.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // La clave de Google Maps se lee de local.properties y se inserta en el manifiesto al compilar.
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
        // Sin clave, la app muestra la lista de equipos en lugar del mapa (igual que MAPS_ENABLED en Kotlin).
        buildConfigField("boolean", "MAPS_ENABLED", mapsApiKey.isNotEmpty().toString())
    }

    buildFeatures {
        buildConfig = true
    }

    buildTypes {
        release {
            // Se firma con la clave de depuración para que `flutter run --release` funcione.
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
