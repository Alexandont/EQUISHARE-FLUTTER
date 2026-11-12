import 'package:equishare_flutter/domain/compat_kotlin.dart';
import 'package:equishare_flutter/domain/formato.dart';
import 'package:equishare_flutter/domain/modelos.dart';
import 'package:equishare_flutter/domain/reglas_negocio.dart';
import 'package:equishare_flutter/domain/resultado.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pruebas extra de la versión Flutter: comprueban que Dart da los mismos resultados que Kotlin
/// en los casos donde los dos lenguajes se comportan distinto por defecto.
void main() {
  test('los decimales se redondean como String.format de Kotlin', () {
    expect(fijoComoJava(1250.5, 2), '1250.50');
    expect(fijoComoJava(4.35, 1), '4.4'); // toStringAsFixed de Dart daría "4.3"
    expect(fijoComoJava(1.005, 2), '1.01'); // toStringAsFixed de Dart daría "1.00"
    expect(fijoComoJava(0.125, 2), '0.13');
    expect(fijoComoJava(9.995, 2), '10.00');
    expect(fijoComoJava(0.0000001, 2), '0.00');
    expect(fijoComoJava(2e21, 1), '2000000000000000000000.0');
  });

  test('la calificación, la distancia y los soles usan ese mismo redondeo', () {
    expect(Formato.calificacion(4.35, 20), '4.4 / 5 (20)');
    expect(Formato.calificacion(4.0, 0), 'Sin calificaciones');
    expect(Formato.distancia(0.4567), '456 m');
    expect(Formato.distancia(12.25), '12.3 km');
    expect(Formato.distancia(null), isNull);
    expect(Formato.soles(1234567.005), 'S/ 1,234,567.01');
    expect(Formato.soles(0), 'S/ 0.00');
  });

  test('Math.round de Java: la mitad siempre hacia arriba', () {
    expect(redondearMitadArriba(2.5), 3);
    expect(redondearMitadArriba(-2.5), -2); // (-2.5).round() de Dart daría -3
    expect(redondearMitadArriba(2.4999), 2);
    expect(ReglasNegocio.redondear2(28.8), 28.8);
  });

  test('las fechas son estrictas como LocalDate.parse de Kotlin', () {
    expect(Fechas.desdeIsoONull('2026-10-18'), DateTime.utc(2026, 10, 18));
    expect(Fechas.desdeIsoONull('2026-02-30'), isNull);
    expect(Fechas.desdeIsoONull('2026-10-18T10:00:00Z'), isNull);
    expect(Formato.fecha('2026-10-18T10:00:00Z'), '2026-10-18T10:00:00Z');
  });

  test('los minutos se cuentan como Duration.toMinutes de Kotlin', () {
    final devuelta = DateTime.utc(2026, 10, 10, 12);
    // 30 s antes de la devolución: Kotlin cuenta 0 minutos y permite calificar.
    expect(ReglasNegocio.dentroDeVentanaResena(devuelta, devuelta.subtract(const Duration(seconds: 30))), isTrue);
    // 59,5 s antes: Kotlin cuenta -1 minuto y no permite calificar.
    expect(
      ReglasNegocio.dentroDeVentanaResena(devuelta, devuelta.subtract(const Duration(milliseconds: 59500))),
      isFalse,
    );
  });

  test('el orden estable conserva los empates en su posición original', () {
    final r = ordenEstable(['b1', 'a1', 'b2', 'a2'], (String x, String y) => x[0].compareTo(y[0]));
    expect(r, ['a1', 'a2', 'b1', 'b2']);
  });

  test('las letras se revisan carácter por carácter como Char de Kotlin', () {
    expect(contarCaracteres('Ñandú 12', esLetra), 5);
    expect(filtrarCaracteres('S.A.C.', esLetra), 'SAC');
  });

  test('las métricas del panel se leen igual que en Kotlin', () {
    final m = MetricasEmpresa.fromJson({
      'equiposPublicados': 3,
      'equiposTotales': 4,
      'reservasPendientes': 1,
      'reservasActivas': 2,
      'reservasComoCliente': 5,
      'alquileresCompletados': 7,
      'ingresosEstimados': 1520.5,
      'equipoMasAlquilado': {'nombre': 'Mezcladora', 'veces': 6},
    });
    expect(m.equiposPublicados, 3);
    expect(m.ingresosEstimados, 1520.5);
    expect(m.equipoMasAlquilado, 'Mezcladora');
    expect(m.vecesMasAlquilado, 6);

    final sinEquipo = MetricasEmpresa.fromJson({
      'equipoMasAlquilado': {'nombre': '  ', 'veces': 2},
    });
    expect(sinEquipo.equipoMasAlquilado, isNull);
    expect(sinEquipo.vecesMasAlquilado, 2);
    expect(sinEquipo.equiposTotales, 0);
    expect(MetricasEmpresa.fromJson({}).vecesMasAlquilado, 0);
  });

  test('la sesión y el resultado se comportan como en Kotlin', () {
    expect(const Sesion(uid: 'u', email: null, esDemo: true).correoVerificado, isTrue);
    final exito = const Exito<int>(2).mapear((n) => n * 10);
    expect(exito.datosONull, 20);
    final fallo = Fallo<int>(ErrorApp(TipoError.conflicto)).mapear((n) => '$n');
    expect(fallo.errorONull?.tipo, TipoError.conflicto);
  });
}
