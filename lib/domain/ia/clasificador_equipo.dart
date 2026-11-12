import '../compat_kotlin.dart';
import '../modelos.dart';

/// Algo que el modelo de IA ve en la foto, con su confianza (de 0 a 1). Ejemplo: "Computer", 0.92.
/// La confianza se guarda con precisión Float, igual que en Kotlin, para que los cálculos coincidan.
class EtiquetaFoto {
  EtiquetaFoto(this.texto, double confianza) : confianza = aFloat(confianza);
  final String texto;
  final double confianza;

  @override
  bool operator ==(Object other) => other is EtiquetaFoto && other.texto == texto && other.confianza == confianza;

  @override
  int get hashCode => Object.hash(texto, confianza);

  @override
  String toString() => 'EtiquetaFoto($texto, $confianza)';
}

/// Una pista que apoya la categoría sugerida, ya traducida. Ejemplo: "computadora", 92.
class PistaIa {
  const PistaIa(this.nombre, this.porcentaje);
  final String nombre;
  final int porcentaje;

  @override
  bool operator ==(Object other) => other is PistaIa && other.nombre == nombre && other.porcentaje == porcentaje;

  @override
  int get hashCode => Object.hash(nombre, porcentaje);

  @override
  String toString() => 'PistaIa($nombre, $porcentaje)';
}

/// Resultado de revisar la foto con IA.
/// [categoria] es null cuando la IA no está segura. [pareceOtraCosa] dice qué parece la foto
/// cuando claramente no es un equipo (por ejemplo "una selfie" o "comida").
class SugerenciaFoto {
  const SugerenciaFoto({required this.categoria, required this.pistas, required this.pareceOtraCosa});
  final Categoria? categoria;
  final List<PistaIa> pistas;
  final String? pareceOtraCosa;

  /// Texto corto con lo que vio la IA. Ejemplo: "computadora (92 %), celular (71 %)".
  String textoPistas() => pistas.map((p) => '${p.nombre} (${p.porcentaje} %)').join(', ');
}

class _Pista {
  const _Pista(this.categoria, this.nombre, this.peso);
  final Categoria categoria;
  final String nombre;
  final double peso;
}

class _Acierto {
  const _Acierto(this.etiqueta, this.pista);
  final EtiquetaFoto etiqueta;
  final _Pista pista;
}

/// Convierte lo que ve el modelo de IA del teléfono (ML Kit, etiquetas en inglés) en una categoría
/// de EQUISHARE. Es Dart puro: no depende de Flutter y se prueba con flutter test.
///
/// Cómo decide: cada etiqueta conocida suma "confianza × peso" a su categoría. Gana la categoría
/// con más puntos, solo si llega a [puntajeMinimo]. Si no llega, no adivina.
/// Los nombres de las etiquetas son los del modelo base de ML Kit (página "Label map").
class ClasificadorEquipo {
  ClasificadorEquipo._();

  /// Las etiquetas con menos confianza que esto se ignoran (también se usa en ML Kit).
  static const double confianzaMinima = 0.5;

  /// Puntos que necesita una categoría para sugerirse.
  static const double puntajeMinimo = 0.6;

  /// Máximo de pistas que se muestran al usuario.
  static const int maximoPistas = 3;

  static const Map<String, _Pista> _pistas = {
    // Tecnología
    'computer': _Pista(Categoria.tecnologia, 'computadora', 1.0),
    'mobile phone': _Pista(Categoria.tecnologia, 'celular', 1.0),
    'television': _Pista(Categoria.tecnologia, 'televisor', 1.0),
    // Eventos
    'chair': _Pista(Categoria.eventos, 'sillas', 1.0),
    'bench': _Pista(Categoria.eventos, 'bancas', 1.0),
    'couch': _Pista(Categoria.eventos, 'sofá', 1.0),
    'loveseat': _Pista(Categoria.eventos, 'sofá', 1.0),
    'tablecloth': _Pista(Categoria.eventos, 'mantel', 1.0),
    'centrepiece': _Pista(Categoria.eventos, 'centro de mesa', 1.0),
    'tableware': _Pista(Categoria.eventos, 'vajilla', 1.0),
    'cutlery': _Pista(Categoria.eventos, 'cubiertos', 1.0),
    'balloon': _Pista(Categoria.eventos, 'globos', 1.0),
    'party': _Pista(Categoria.eventos, 'fiesta', 1.0),
    'event': _Pista(Categoria.eventos, 'evento', 1.0),
    'concert': _Pista(Categoria.eventos, 'concierto', 1.0),
    'marriage': _Pista(Categoria.eventos, 'boda', 1.0),
    'ballroom': _Pista(Categoria.eventos, 'salón de eventos', 1.0),
    'subwoofer': _Pista(Categoria.eventos, 'parlante', 1.0),
    'musical instrument': _Pista(Categoria.eventos, 'instrumento musical', 1.0),
    'piano': _Pista(Categoria.eventos, 'piano', 1.0),
    'deejay': _Pista(Categoria.eventos, 'equipo de DJ', 1.0),
    'umbrella': _Pista(Categoria.eventos, 'sombrilla', 1.0),
    // Construcción
    'tractor': _Pista(Categoria.construccion, 'maquinaria pesada', 1.0),
    'construction': _Pista(Categoria.construccion, 'obra de construcción', 1.0),
    'wheelbarrow': _Pista(Categoria.construccion, 'carretilla', 1.0),
    'brick': _Pista(Categoria.construccion, 'ladrillos', 0.8),
    'vehicle': _Pista(Categoria.construccion, 'vehículo', 0.5),
    'asphalt': _Pista(Categoria.construccion, 'asfalto', 0.4),
    'infrastructure': _Pista(Categoria.construccion, 'obra', 0.4),
  };

  /// Etiquetas que indican que la foto no muestra un equipo, con lo que parece en español.
  static const Map<String, String> _otraCosa = {
    'selfie': 'una selfie',
    'person': 'personas',
    'smile': 'personas',
    'dude': 'personas',
    'baby': 'personas',
    'crowd': 'personas',
    'hand': 'una mano',
    'food': 'comida',
    'cuisine': 'comida',
    'meal': 'comida',
    'fast food': 'comida',
    'pizza': 'comida',
    'lunch': 'comida',
    'supper': 'comida',
    'dog': 'una mascota',
    'cat': 'una mascota',
    'pet': 'una mascota',
    'bird': 'un animal',
    'horse': 'un animal',
    'screenshot': 'una captura de pantalla',
    'web page': 'una captura de pantalla',
    'sky': 'un paisaje',
    'sunset': 'un paisaje',
    'beach': 'un paisaje',
    'mountain': 'un paisaje',
  };

  static String _clave(String texto) => texto.trim().toLowerCase();

  static SugerenciaFoto clasificar(List<EtiquetaFoto> etiquetas) {
    final validas = ordenEstable(
      etiquetas.where((e) => e.confianza.isFinite && e.confianza >= confianzaMinima),
      (EtiquetaFoto a, EtiquetaFoto b) => b.confianza.compareTo(a.confianza),
    );

    // Cada etiqueta conocida suma puntos a su categoría (una etiqueta repetida cuenta una vez).
    final usadas = <String>{};
    final aciertos = <_Acierto>[];
    for (final etiqueta in validas) {
      final k = _clave(etiqueta.texto);
      final pista = _pistas[k];
      if (pista != null && usadas.add(k)) aciertos.add(_Acierto(etiqueta, pista));
    }
    final puntajes = <Categoria, double>{}; // conserva el orden de aparición, como groupBy
    for (final a in aciertos) {
      puntajes[a.pista.categoria] = (puntajes[a.pista.categoria] ?? 0.0) + a.etiqueta.confianza * a.pista.peso;
    }

    final ordenadas = ordenEstable(
      puntajes.entries,
      (MapEntry<Categoria, double> a, MapEntry<Categoria, double> b) {
        final porPuntos = b.value.compareTo(a.value);
        return porPuntos != 0 ? porPuntos : a.key.index.compareTo(b.key.index);
      },
    );
    final Categoria? ganadora =
        (ordenadas.isNotEmpty && ordenadas.first.value >= puntajeMinimo - 1e-9) ? ordenadas.first.key : null;

    if (ganadora != null) {
      final pistas = <PistaIa>[];
      final nombres = <String>{};
      for (final a in aciertos.where((a) => a.pista.categoria == ganadora)) {
        final porcentaje = redondearMitadArriba(aFloat(a.etiqueta.confianza.clamp(0.0, 1.0).toDouble() * 100.0)).toInt();
        if (nombres.add(a.pista.nombre)) pistas.add(PistaIa(a.pista.nombre, porcentaje));
        if (pistas.length == maximoPistas) break;
      }
      return SugerenciaFoto(categoria: ganadora, pistas: pistas, pareceOtraCosa: null);
    }

    // Sin categoría: si lo más seguro que vio la IA es algo que no es un equipo, se avisa.
    final principal = validas.isEmpty ? null : _otraCosa[_clave(validas.first.texto)];
    return SugerenciaFoto(categoria: null, pistas: const [], pareceOtraCosa: principal);
  }
}
