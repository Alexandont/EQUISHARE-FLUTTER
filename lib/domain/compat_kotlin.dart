import 'dart:typed_data';

/*
 * Ayudas para que la versión Flutter dé EXACTAMENTE los mismos resultados que la versión Kotlin.
 *
 * Dart y Kotlin/Java no siempre redondean ni clasifican caracteres igual. Ejemplos:
 *  - String.format("%.1f", 4.35) da "4.4" en Kotlin, pero 4.35.toStringAsFixed(1) da "4.3" en Dart.
 *  - Math.round(-2.5) da -2 en Java, pero (-2.5).round() da -3 en Dart.
 *  - Kotlin revisa las letras carácter por carácter (UTF-16); aquí se hace igual.
 *  - La confianza de ML Kit es un Float (32 bits) en Kotlin; aquí se redondea a 32 bits igual.
 *  - sortedBy de Kotlin es estable; List.sort de Dart no lo garantiza.
 * Todo está probado en test/compat_kotlin_test.dart.
 */

final RegExp _letra = RegExp(r'\p{L}', unicode: true);
final RegExp _digito = RegExp(r'\p{Nd}', unicode: true);
final RegExp _mayuscula = RegExp(r'\p{Lu}', unicode: true);
final RegExp _minuscula = RegExp(r'\p{Ll}', unicode: true);

/// Revisa cada unidad UTF-16 por separado, como Char de Kotlin.
bool _unidadCumple(int unidad, RegExp patron) => patron.hasMatch(String.fromCharCode(unidad));

/// Char.isLetter() de Kotlin.
bool esLetra(int unidad) => _unidadCumple(unidad, _letra);

/// Char.isDigit() de Kotlin (cualquier dígito decimal Unicode).
bool esDigito(int unidad) => _unidadCumple(unidad, _digito);

/// Char.isUpperCase() de Kotlin.
bool esMayuscula(int unidad) => _unidadCumple(unidad, _mayuscula);

/// Char.isLowerCase() de Kotlin.
bool esMinuscula(int unidad) => _unidadCumple(unidad, _minuscula);

/// Char.isLetterOrDigit() de Kotlin.
bool esLetraODigito(int unidad) => esLetra(unidad) || esDigito(unidad);

/// true si algún carácter del texto cumple [condicion] (como String.any de Kotlin).
bool algunCaracter(String texto, bool Function(int unidad) condicion) => texto.codeUnits.any(condicion);

/// Cantidad de caracteres del texto que cumplen [condicion] (como String.count de Kotlin).
int contarCaracteres(String texto, bool Function(int unidad) condicion) =>
    texto.codeUnits.where(condicion).length;

/// Deja solo los caracteres que cumplen [condicion] (como String.filter de Kotlin).
String filtrarCaracteres(String texto, bool Function(int unidad) condicion) =>
    String.fromCharCodes(texto.codeUnits.where(condicion));

final Float32List _float = Float32List(1);

/// Redondea a precisión Float (32 bits), como un Float de Kotlin.
double aFloat(double valor) {
  _float[0] = valor;
  return _float[0];
}

/// Math.round(double) de Java: redondea la mitad hacia arriba (2.5 -> 3, -2.5 -> -2).
/// Devuelve un double entero para funcionar igual en Android y en la web.
double redondearMitadArriba(double valor) {
  if (!valor.isFinite) return valor;
  final piso = valor.floorToDouble();
  return (valor - piso) >= 0.5 ? piso + 1.0 : piso;
}

/// Double.toInt() de Kotlin: trunca hacia cero; NaN da 0 y se limita al rango de Int.
int aIntComoKotlin(double valor) {
  if (valor.isNaN) return 0;
  if (valor >= 2147483647.0) return 2147483647;
  if (valor <= -2147483648.0) return -2147483648;
  return valor.truncate();
}

/// String.format("%.Nf") de Java/Kotlin: parte de la escritura decimal más corta del número
/// (la misma que muestra Double.toString) y redondea la mitad hacia arriba.
String fijoComoJava(double valor, int decimales) {
  if (valor.isNaN) return 'NaN';
  if (valor.isInfinite) return valor > 0 ? 'Infinity' : '-Infinity';
  final negativo = valor.isNegative; // también -0.0, igual que Java ("-0.00")

  // Dígitos y posición del punto a partir de la escritura más corta ("4.35", "1e-7", "1.5e+21").
  var texto = valor.abs().toString();
  var exponente = 0;
  final e = texto.indexOf('e');
  if (e >= 0) {
    exponente = int.parse(texto.substring(e + 1));
    texto = texto.substring(0, e);
  }
  final punto = texto.indexOf('.');
  var digitos = punto >= 0 ? texto.replaceFirst('.', '') : texto;
  var posicionPunto = (punto >= 0 ? punto : texto.length) + exponente;
  if (posicionPunto <= 0) {
    digitos = '${'0' * (1 - posicionPunto)}$digitos';
    posicionPunto = 1;
  }
  final necesarios = posicionPunto + decimales + 1;
  if (digitos.length < necesarios) digitos = digitos.padRight(necesarios, '0');

  // Se conservan [posicionPunto + decimales] dígitos y se mira el siguiente para redondear.
  final cifras = digitos.substring(0, posicionPunto + decimales).codeUnits.map((c) => c - 48).toList();
  if (digitos.codeUnitAt(posicionPunto + decimales) >= 53) {
    // '5' o más: se suma 1 llevando el acarreo.
    var i = cifras.length - 1;
    while (i >= 0) {
      if (cifras[i] == 9) {
        cifras[i] = 0;
        i--;
      } else {
        cifras[i]++;
        break;
      }
    }
    if (i < 0) {
      cifras.insert(0, 1);
      posicionPunto++;
    }
  }

  var entero = cifras.sublist(0, posicionPunto).join().replaceFirst(RegExp(r'^0+(?=\d)'), '');
  if (entero.isEmpty) entero = '0';
  final fraccion = cifras.sublist(posicionPunto).join();
  final cuerpo = decimales > 0 ? '$entero.$fraccion' : entero;
  return negativo ? '-$cuerpo' : cuerpo;
}

/// Ordena sin cambiar el orden de los elementos que empatan (como sortedBy/sortedWith de Kotlin).
List<T> ordenEstable<T>(Iterable<T> elementos, int Function(T a, T b) comparar) {
  final indexados = elementos.toList().asMap().entries.toList();
  indexados.sort((a, b) {
    final c = comparar(a.value, b.value);
    return c != 0 ? c : a.key.compareTo(b.key);
  });
  return indexados.map((e) => e.value).toList();
}
