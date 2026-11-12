import 'package:equishare_flutter/domain/ia/lector_ruc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mismas pruebas de la versión Kotlin (LectorRucTest), traducidas a Dart.
void main() {
  test('captura de Consulta RUC: lee el RUC y la razón social de la misma línea', () {
    final texto = [
      'Resultado de la Búsqueda',
      'Número de RUC: 20131312955 - CONSTRUCTORA EJEMPLO S.A.C.',
      'Tipo Contribuyente: SOCIEDAD ANONIMA CERRADA',
    ].join('\n');
    expect(LectorRuc.extraer(texto), const DatosRuc('20131312955', 'CONSTRUCTORA EJEMPLO S.A.C.'));
  });

  test('ficha RUC: lee la razón social después de su etiqueta', () {
    final texto = [
      'FICHA RUC : 20600123450',
      'Apellidos y Nombres, Denominación o Razón Social : INVERSIONES TRUJILLO E.I.R.L.',
      'Tipo de Contribuyente : EMPRESA INDIVIDUAL DE RESP. LTDA',
    ].join('\n');
    expect(LectorRuc.extraer(texto), const DatosRuc('20600123450', 'INVERSIONES TRUJILLO E.I.R.L.'));
  });

  test('ficha RUC con los datos en la línea siguiente', () {
    final texto = [
      'Número de RUC',
      '20485673211',
      'Razón Social',
      'ALQUILERES DEL NORTE S.A.C.',
      'Nombre Comercial: -',
    ].join('\n');
    expect(LectorRuc.extraer(texto), const DatosRuc('20485673211', 'ALQUILERES DEL NORTE S.A.C.'));
  });

  test('acepta un espacio que la IA metió dentro del número', () {
    expect(LectorRuc.extraer('RUC: 20 131312955 - EMPRESA SAC'), const DatosRuc('20131312955', 'EMPRESA SAC'));
  });

  test('un número con dígito verificador incorrecto no se usa', () {
    expect(LectorRuc.extraer('RUC: 20131312956 - EMPRESA SAC'), const DatosRuc(null, null));
  });

  test('prefiere el número de la línea que dice RUC', () {
    final texto = [
      'Documento del representante: 10456789124',
      'Teléfono 949123456',
      'RUC 20600123450',
    ].join('\n');
    expect(LectorRuc.extraer(texto), const DatosRuc('20600123450', null));
  });

  test('sin texto o sin RUC no inventa nada', () {
    expect(LectorRuc.extraer(null), const DatosRuc(null, null));
    expect(LectorRuc.extraer(''), const DatosRuc(null, null));
    expect(LectorRuc.extraer('Factura 001-12345 del 10/11/2026'), const DatosRuc(null, null));
  });

  test('no toma otra etiqueta como razón social', () {
    final texto = [
      'Número de RUC: 20131312955',
      'Razón Social:',
      'Tipo de Contribuyente: SOCIEDAD ANONIMA',
    ].join('\n');
    expect(LectorRuc.extraer(texto), const DatosRuc('20131312955', null));
    expect(LectorRuc.extraer('RUC: 20131312955 - 12'), const DatosRuc('20131312955', null));
  });

  test('lee la etiqueta sin tilde y limpia los espacios repetidos', () {
    final texto = [
      'RUC 20100030005',
      'RAZON SOCIAL:   ALQUILER   DE   EQUIPOS  SAC',
    ].join('\n');
    expect(LectorRuc.extraer(texto), const DatosRuc('20100030005', 'ALQUILER DE EQUIPOS SAC'));
  });
}
