import 'compat_kotlin.dart';
import 'reglas_negocio.dart';

/// Formatos de presentación (moneda en soles y fechas en español), idénticos a los de Kotlin.
class Formato {
  Formato._();

  static const Set<String> _sociedades = {'SAC', 'SA', 'SRL', 'EIRL', 'SAA', 'DE', 'DEL', 'LA', 'EL', 'LOS', 'LAS', 'Y'};
  static final RegExp _separadoresNombre = RegExp(r'[ \-,]');

  /// Iniciales para el círculo del perfil: "Constructora Norte S.A.C." -> "CN".
  static String iniciales(String? nombre) {
    final palabras = (nombre ?? '')
        .split(_separadoresNombre)
        .map((p) => filtrarCaracteres(p, esLetra))
        .where((p) => p.length > 1 && !_sociedades.contains(p.toUpperCase()))
        .toList();
    final letras = palabras.take(2).map((p) => p[0].toUpperCase()).join();
    return letras.isEmpty ? 'EQ' : letras;
  }

  static String _agrupar(String entero) {
    final buffer = StringBuffer();
    for (var i = 0; i < entero.length; i++) {
      if (i > 0 && (entero.length - i) % 3 == 0) buffer.write(',');
      buffer.write(entero[i]);
    }
    return buffer.toString();
  }

  /// 1250.5 -> "S/ 1,250.50" (igual que "%,.2f" con el idioma es-PE en Kotlin).
  static String soles(double monto) {
    final fijo = fijoComoJava(monto, 2);
    if (!monto.isFinite) return 'S/ $fijo';
    final negativo = fijo.startsWith('-');
    final partes = (negativo ? fijo.substring(1) : fijo).split('.');
    return 'S/ ${negativo ? '-' : ''}${_agrupar(partes[0])}.${partes[1]}';
  }

  /// "2026-10-18" -> "18/10/2026". Si no es una fecha válida, la devuelve tal cual (como Kotlin).
  static String fecha(String iso) {
    final d = Fechas.desdeIsoONull(iso);
    if (d == null) return iso;
    final dia = d.day.toString().padLeft(2, '0');
    final mes = d.month.toString().padLeft(2, '0');
    final anio = d.year.toString().padLeft(4, '0');
    return '$dia/$mes/$anio';
  }

  static String rango(String inicio, String fin) => inicio == fin ? fecha(inicio) : '${fecha(inicio)} al ${fecha(fin)}';

  static String calificacion(double promedio, int total) =>
      total == 0 ? 'Sin calificaciones' : '${fijoComoJava(promedio, 1)} / 5 ($total)';

  static String? distancia(double? km) {
    if (km == null) return null;
    if (km < 1.0) return '${aIntComoKotlin(km * 1000)} m';
    return '${fijoComoJava(km, 1)} km';
  }
}
