import 'package:equishare_flutter/domain/formato.dart';
import 'package:equishare_flutter/domain/modelos.dart';
import 'package:equishare_flutter/domain/reglas_negocio.dart';
import 'package:equishare_flutter/domain/resultado.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mismas pruebas de la versión Kotlin (ReglasNegocioTest), traducidas a Dart.
void main() {
  final ahora = DateTime.utc(2026, 10, 16, 17); // 12:00 en Lima
  DateTime dia(String iso) => Fechas.desdeIso(iso);

  test('cotización: aplica la comisión del 12 % al arrendador', () {
    final c = ReglasNegocio.cotizar(80, dia('2026-10-18'), dia('2026-10-20'));
    expect(c.dias, 3);
    expect(c.subtotal, closeTo(240, 0.001));
    expect(c.comision, closeTo(28.8, 0.001));
    expect(c.montoArrendador, closeTo(211.2, 0.001));
    expect(c.total, closeTo(240, 0.001));
  });

  test('anticipación: exige 24 horas antes de la entrega', () {
    expect(ReglasNegocio.cumpleAnticipacion(dia('2026-10-17'), ahora), isFalse); // 20 h
    expect(ReglasNegocio.cumpleAnticipacion(dia('2026-10-18'), ahora), isTrue); // 44 h
    expect(ReglasNegocio.primerDiaReservable(ahora), dia('2026-10-18'));
  });

  test('validarRango: detecta fin anterior y exceso de días', () {
    expect(ReglasNegocio.validarRango(dia('2026-10-20'), dia('2026-10-19'), ahora), isNotNull);
    expect(ReglasNegocio.validarRango(dia('2026-10-20'), dia('2027-02-20'), ahora), isNotNull);
    expect(ReglasNegocio.validarRango(dia('2026-10-20'), dia('2026-10-22'), ahora), isNull);
  });

  test('solapamiento: considera los días incluidos', () {
    const ocupados = [RangoOcupado('2026-10-20', '2026-10-22')];
    expect(ReglasNegocio.haySolapamiento(ocupados, dia('2026-10-22'), dia('2026-10-23')), isTrue);
    expect(ReglasNegocio.haySolapamiento(ocupados, dia('2026-10-23'), dia('2026-10-24')), isFalse);
  });

  test('penalidad: solo si faltan menos de 12 horas', () {
    final inicio = dia('2026-10-18'); // entrega 13:00 UTC
    expect(ReglasNegocio.penalidadSiCancela(inicio, 240, DateTime.utc(2026, 10, 17, 12)), closeTo(0, 0.001));
    expect(ReglasNegocio.penalidadSiCancela(inicio, 240, DateTime.utc(2026, 10, 18, 5)), closeTo(48, 0.001));
  });

  test('ventana de reseña de 48 horas', () {
    final devuelta = DateTime.utc(2026, 10, 10, 12);
    expect(ReglasNegocio.dentroDeVentanaResena(devuelta, DateTime.utc(2026, 10, 11, 12)), isTrue);
    expect(ReglasNegocio.dentroDeVentanaResena(devuelta, DateTime.utc(2026, 10, 13, 12, 1)), isFalse);
    expect(ReglasNegocio.dentroDeVentanaResena(null, ahora), isFalse);
  });

  test('distancia Trujillo - Huanchaco (~10 km)', () {
    final d = ReglasNegocio.distanciaKm(-8.1116, -79.0287, -8.0792, -79.1199);
    expect(d, inInclusiveRange(9, 12));
  });

  test('los códigos HTTP se traducen a tipos de error', () {
    expect(TipoError.desdeCodigoHttp(400), TipoError.validacion);
    expect(TipoError.desdeCodigoHttp(401), TipoError.noAutenticado);
    expect(TipoError.desdeCodigoHttp(403), TipoError.prohibido);
    expect(TipoError.desdeCodigoHttp(404), TipoError.noEncontrado);
    expect(TipoError.desdeCodigoHttp(409), TipoError.conflicto);
    expect(TipoError.desdeCodigoHttp(422), TipoError.reglaNegocio);
    expect(TipoError.desdeCodigoHttp(503), TipoError.servidor);
  });

  test('formato de moneda y fechas', () {
    expect(Formato.soles(1250.5), 'S/ 1,250.50');
    expect(Formato.fecha('2026-10-18'), '18/10/2026');
    expect(Formato.rango('2026-10-18', '2026-10-20'), '18/10/2026 al 20/10/2026');
  });
}
