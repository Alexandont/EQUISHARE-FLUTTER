import 'dart:ui' show Locale;

import 'package:geocoding/geocoding.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../domain/ia/clasificador_equipo.dart';
import '../domain/modelos.dart';
import '../domain/repositorios.dart';

/*
 * Servicios del teléfono (Android): IA con ML Kit y búsqueda de direcciones.
 * Este archivo solo se usa en el teléfono; en la web se usa servicios_web.dart,
 * porque ML Kit no existe para navegadores.
 */

AnalizadorFoto crearAnalizadorFoto() => AnalizadorFotoMlKit();

LectorTextoFoto crearLectorTexto() => LectorTextoMlKit();

BuscadorDirecciones crearBuscadorDirecciones() => BuscadorDireccionesGeocoding();

/// IA en el teléfono con ML Kit Image Labeling (modelo base incluido en la app).
/// Funciona sin internet, no envía la foto a ningún servidor y no necesita Firebase.
class AnalizadorFotoMlKit implements AnalizadorFoto {
  ImageLabeler? _etiquetador;

  ImageLabeler get _instancia => _etiquetador ??= ImageLabeler(
        options: ImageLabelerOptions(confidenceThreshold: ClasificadorEquipo.confianzaMinima),
      );

  @override
  Future<List<EtiquetaFoto>?> etiquetar(String rutaFoto) async {
    try {
      final etiquetas = await _instancia.processImage(InputImage.fromFilePath(rutaFoto));
      return etiquetas.map((e) => EtiquetaFoto(e.label, e.confidence)).toList();
    } catch (_) {
      return null;
    }
  }
}

/// Lee el texto de una foto con ML Kit Text Recognition (modelo para letras latinas incluido en la app).
/// Funciona sin internet y la foto no sale del teléfono.
class LectorTextoMlKit implements LectorTextoFoto {
  TextRecognizer? _reconocedor;

  TextRecognizer get _instancia => _reconocedor ??= TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<String?> leerTexto(String rutaFoto) async {
    try {
      final reconocido = await _instancia.processImage(InputImage.fromFilePath(rutaFoto));
      return reconocido.text;
    } catch (_) {
      return null;
    }
  }
}

/// Busca una dirección escrita con el Geocoder del teléfono (servicio de Google Play).
/// Solo acepta resultados dentro del Perú, para que "Av. España 1234" no termine en España.
/// Kotlin le pasa al Geocoder el rectángulo del Perú; este paquete no permite hacerlo, así que se
/// toma el primer resultado dentro del rectángulo y, si no hay, se busca otra vez agregando "Perú".
class BuscadorDireccionesGeocoding implements BuscadorDirecciones {
  // Rectángulo que cubre el Perú (sur, oeste, norte, este), el mismo de Kotlin.
  static const double _sur = -18.4;
  static const double _oeste = -81.4;
  static const double _norte = -0.03;
  static const double _este = -68.6;

  static bool _enPeru(double lat, double lng) => lat >= _sur && lat <= _norte && lng >= _oeste && lng <= _este;

  @override
  Future<Coordenadas?> buscar(String direccion) async {
    final texto = direccion.trim();
    if (texto.length < 3) return null;
    try {
      return await _buscar(texto).timeout(const Duration(seconds: 10));
    } catch (_) {
      return null;
    }
  }

  Future<Coordenadas?> _buscar(String texto) async {
    final geocoding = Geocoding(locale: const Locale('es', 'PE'));
    if (!await geocoding.isPresent()) return null;
    return await _primeroEnPeru(geocoding, texto) ?? await _primeroEnPeru(geocoding, '$texto, Perú');
  }

  static Future<Coordenadas?> _primeroEnPeru(Geocoding geocoding, String texto) async {
    try {
      for (final lugar in await geocoding.locationFromAddress(texto)) {
        if (_enPeru(lugar.latitude, lugar.longitude)) return Coordenadas(lugar.latitude, lugar.longitude);
      }
    } catch (_) {
      // Sin resultados para este texto.
    }
    return null;
  }
}
