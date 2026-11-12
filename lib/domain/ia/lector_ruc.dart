import '../compat_kotlin.dart';
import '../validadores.dart';

/// Datos encontrados en la foto de la ficha RUC. Cada uno es null si no se encontró.
class DatosRuc {
  const DatosRuc(this.ruc, this.razonSocial);
  final String? ruc;
  final String? razonSocial;

  @override
  bool operator ==(Object other) => other is DatosRuc && other.ruc == ruc && other.razonSocial == razonSocial;

  @override
  int get hashCode => Object.hash(ruc, razonSocial);

  @override
  String toString() => 'DatosRuc($ruc, $razonSocial)';
}

class _Candidato {
  const _Candidato(this.ruc, this.linea, this.fin, this.conEtiqueta);
  final String ruc;
  final int linea;
  final int fin;
  final bool conEtiqueta;
}

/// Busca el RUC y la razón social en el texto que la IA leyó de una foto (ficha RUC de SUNAT
/// o captura de la "Consulta RUC"). Es Dart puro y se prueba con flutter test.
///
/// Para no inventar datos, solo acepta un RUC que pase la misma validación del formulario
/// (11 dígitos, prefijo 10, 15, 16, 17 o 20 y dígito verificador correcto).
class LectorRuc {
  LectorRuc._();

  // En Kotlin, \s solo reconoce espacios ASCII; aquí se escriben explícitos para que sea igual.
  static const String _espacio = r'[ \t\n\x0B\f\r]';

  /// 11 dígitos seguidos; acepta un espacio o guion suelto entre grupos, porque la IA a veces los agrega.
  static final RegExp _numeroRuc = RegExp(r'(?<![0-9])([0-9]{2})[ -]?([0-9]{8})[ -]?([0-9])(?![0-9])');
  static final RegExp _etiquetaRazon = RegExp('raz[oó0]n$_espacio+social', caseSensitive: false);
  static final RegExp _palabraRuc = RegExp('ruc', caseSensitive: false);
  static final RegExp _separadorInicial = RegExp('^(?:$_espacio|[:\\-–—])+');
  static final RegExp _separadorFinal = RegExp('(?:$_espacio|[:\\-–—])+\$');
  static final RegExp _espacios = RegExp('$_espacio+');
  static final RegExp _saltosDeLinea = RegExp(r'\r\n|\n|\r');

  static DatosRuc extraer(String? texto) {
    if (texto == null || texto.trim().isEmpty) return const DatosRuc(null, null);
    final lineas = texto.split(_saltosDeLinea).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    final candidatos = <_Candidato>[];
    for (var i = 0; i < lineas.length; i++) {
      final linea = lineas[i];
      for (final m in _numeroRuc.allMatches(linea)) {
        final ruc = '${m.group(1)}${m.group(2)}${m.group(3)}';
        if (Validadores.ruc(ruc) == null) {
          candidatos.add(_Candidato(ruc, i, m.end, _palabraRuc.hasMatch(linea)));
        }
      }
    }
    if (candidatos.isEmpty) return const DatosRuc(null, null);
    // Se prefiere el número que está en la línea que dice "RUC".
    final elegido = candidatos.firstWhere((c) => c.conEtiqueta, orElse: () => candidatos.first);

    final razon = _razonJuntoAlRuc(lineas[elegido.linea], elegido.fin) ?? _razonPorEtiqueta(lineas);
    return DatosRuc(elegido.ruc, razon);
  }

  /// Formato de la Consulta RUC: "Número de RUC: 20131312955 - EMPRESA S.A.C.".
  static String? _razonJuntoAlRuc(String linea, int finDelNumero) {
    final despuesDelGuion = linea.substring(finDelNumero).trimLeft();
    if (despuesDelGuion.isEmpty || !'-–—'.contains(despuesDelGuion[0])) return null;
    return _limpiar(despuesDelGuion);
  }

  /// Formato de la ficha RUC: "Razón Social: EMPRESA S.A.C." o el nombre en la línea siguiente.
  static String? _razonPorEtiqueta(List<String> lineas) {
    for (var i = 0; i < lineas.length; i++) {
      final m = _etiquetaRazon.firstMatch(lineas[i]);
      if (m == null) continue;
      final enLaMismaLinea = _limpiar(lineas[i].substring(m.end));
      if (enLaMismaLinea != null) return enLaMismaLinea;
      if (i + 1 < lineas.length) {
        final enLaSiguiente = _limpiar(lineas[i + 1]);
        if (enLaSiguiente != null) return enLaSiguiente;
      }
    }
    return null;
  }

  static String? _limpiar(String valor) {
    final texto = valor
        .replaceAll(_separadorInicial, '')
        .replaceAll(_separadorFinal, '')
        .replaceAll(_espacios, ' ')
        .trim();
    if (contarCaracteres(texto, esLetra) < 3) return null;
    if (texto.contains(':')) return null; // Es otra etiqueta del documento, no un nombre.
    if (_etiquetaRazon.hasMatch(texto)) return null;
    if (Validadores.razonSocial(texto) != null) return null;
    return texto;
  }
}
