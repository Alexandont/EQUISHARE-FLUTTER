import 'dart:math' as math;

import 'compat_kotlin.dart';
import 'modelos.dart';

/// Fechas "solo día" (sin hora) en formato ISO yyyy-MM-dd, siempre en UTC para evitar
/// errores por cambios de zona horaria del teléfono o del navegador.
class Fechas {
  Fechas._();

  static final RegExp _iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  static DateTime soloDia(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  /// Convierte "2026-10-18" en una fecha UTC. Es estricta como LocalDate.parse de Kotlin:
  /// rechaza otros formatos y fechas que no existen (por ejemplo "2026-02-30").
  static DateTime desdeIso(String iso) {
    final m = _iso.firstMatch(iso);
    if (m == null) throw FormatException('Fecha inválida: $iso');
    final anio = int.parse(m.group(1)!);
    final mes = int.parse(m.group(2)!);
    final dia = int.parse(m.group(3)!);
    final fecha = DateTime.utc(anio, mes, dia);
    if (fecha.year != anio || fecha.month != mes || fecha.day != dia) {
      throw FormatException('Fecha inválida: $iso');
    }
    return fecha;
  }

  static DateTime? desdeIsoONull(String iso) {
    try {
      return desdeIso(iso);
    } catch (_) {
      return null;
    }
  }

  static String aIso(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dia = d.day.toString().padLeft(2, '0');
    return '$y-$m-$dia';
  }
}

/// Reglas de negocio de EQUISHARE replicadas en la app para validar antes de llamar a la API
/// y mostrar el desglose de costos. El servidor vuelve a validarlas (fuente de verdad).
class ReglasNegocio {
  ReglasNegocio._();

  static const double comisionPlataforma = 0.12;
  static const double penalidadCancelacion = 0.20;
  static const int anticipacionMinimaHoras = 24;
  static const int limiteCancelacionHoras = 12;
  static const int ventanaResenaHoras = 48;
  static const int maxDiasReserva = 90;

  /// Lima está en UTC-5 todo el año (sin horario de verano).
  static const int desfaseLimaHoras = -5;
  static const int horaEntrega = 8;

  /// Igual que Kotlin: (valor * 100).roundToLong() / 100.0 (la mitad se redondea hacia arriba).
  static double redondear2(double valor) {
    if (!valor.isFinite) return valor;
    return redondearMitadArriba(valor * 100.0) / 100.0;
  }

  /// Minutos entre dos instantes igual que Duration.between(desde, hasta).toMinutes() de Kotlin.
  static int _minutosEntre(DateTime desde, DateTime hasta) {
    final us = hasta.toUtc().microsecondsSinceEpoch - desde.toUtc().microsecondsSinceEpoch;
    // Duration de Java guarda los segundos redondeados hacia abajo y toMinutes() trunca.
    final segundos = us >= 0 ? us ~/ 1000000 : -((-us + 999999) ~/ 1000000);
    return segundos ~/ 60;
  }

  /// Momento de entrega del equipo: 08:00 (hora de Lima) del día de inicio, expresado en UTC.
  static DateTime instanteInicio(DateTime fechaInicio) =>
      DateTime.utc(fechaInicio.year, fechaInicio.month, fechaInicio.day, horaEntrega - desfaseLimaHoras);

  static DateTime hoyEnLima(DateTime ahora) {
    final lima = ahora.toUtc().add(const Duration(hours: desfaseLimaHoras));
    return DateTime.utc(lima.year, lima.month, lima.day);
  }

  /// Primer día que se puede elegir como inicio cumpliendo la anticipación mínima.
  static DateTime primerDiaReservable(DateTime ahora) {
    var dia = hoyEnLima(ahora);
    while (!cumpleAnticipacion(dia, ahora)) {
      dia = dia.add(const Duration(days: 1));
    }
    return dia;
  }

  static int diasAlquiler(DateTime inicio, DateTime fin) =>
      Fechas.soloDia(fin).difference(Fechas.soloDia(inicio)).inDays + 1;

  /// El arrendatario paga el subtotal; la comisión del 12 % se descuenta al arrendador.
  static Cotizacion cotizar(double precioDia, DateTime inicio, DateTime fin, {bool disponible = true}) {
    final dias = diasAlquiler(inicio, fin);
    final subtotal = redondear2(precioDia * dias);
    final comision = redondear2(subtotal * comisionPlataforma);
    return Cotizacion(
      dias: dias,
      precioDia: redondear2(precioDia),
      subtotal: subtotal,
      comision: comision,
      montoArrendador: redondear2(subtotal - comision),
      total: subtotal,
      disponible: disponible,
    );
  }

  static bool cumpleAnticipacion(DateTime inicio, DateTime ahora) =>
      _minutosEntre(ahora, instanteInicio(inicio)) >= anticipacionMinimaHoras * 60;

  /// Devuelve el mensaje de error del rango elegido o null si es válido.
  static String? validarRango(DateTime inicio, DateTime fin, DateTime ahora) {
    if (Fechas.soloDia(fin).isBefore(Fechas.soloDia(inicio))) {
      return 'La fecha de fin no puede ser anterior a la de inicio.';
    }
    if (diasAlquiler(inicio, fin) > maxDiasReserva) {
      return 'Una reserva no puede superar $maxDiasReserva días.';
    }
    if (!cumpleAnticipacion(inicio, ahora)) {
      return 'Las reservas se hacen con al menos $anticipacionMinimaHoras horas de anticipación (entrega a las 08:00).';
    }
    return null;
  }

  /// Dos rangos (días incluidos) se cruzan si a.inicio <= b.fin y b.inicio <= a.fin.
  static bool haySolapamiento(List<RangoOcupado> ocupados, DateTime inicio, DateTime fin) {
    final i = Fechas.soloDia(inicio);
    final f = Fechas.soloDia(fin);
    for (final rango in ocupados) {
      final a = Fechas.desdeIsoONull(rango.fechaInicio);
      final b = Fechas.desdeIsoONull(rango.fechaFin);
      if (a == null || b == null) continue;
      if (!a.isAfter(f) && !i.isAfter(b)) return true;
    }
    return false;
  }

  /// Penalidad que se aplicaría si se cancela en este momento.
  static double penalidadSiCancela(DateTime fechaInicio, double total, DateTime ahora) {
    final minutos = _minutosEntre(ahora, instanteInicio(fechaInicio));
    return minutos < limiteCancelacionHoras * 60 ? redondear2(total * penalidadCancelacion) : 0.0;
  }

  /// Se puede calificar dentro de las 48 horas posteriores a la devolución.
  static bool dentroDeVentanaResena(DateTime? devueltaEn, DateTime ahora) {
    if (devueltaEn == null) return false;
    final horas = _minutosEntre(devueltaEn, ahora) / 60.0;
    return horas >= 0.0 && horas <= ventanaResenaHoras.toDouble();
  }

  /// Distancia aproximada en km entre dos coordenadas (fórmula de haversine).
  static double distanciaKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    double aRadianes(double grados) => grados / 180.0 * math.pi; // como Math.toRadians
    final dLat = aRadianes(lat2 - lat1);
    final dLng = aRadianes(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(aRadianes(lat1)) * math.cos(aRadianes(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return redondear2(2 * r * math.asin(math.sqrt(a)));
  }
}
