import 'package:equishare_flutter/domain/validadores.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mismas pruebas de la versión Kotlin (ValidadoresTest), traducidas a Dart.
void main() {
  test('RUC válido con dígito verificador', () {
    expect(Validadores.ruc('20131312955'), isNull);
    expect(Validadores.ruc('20100047218'), isNull);
  });

  test('RUC inválido', () {
    expect(Validadores.ruc('20131312954'), isNotNull); // dígito verificador
    expect(Validadores.ruc('30131312955'), isNotNull); // prefijo
    expect(Validadores.ruc('2013131295'), isNotNull); // longitud
    expect(Validadores.ruc('2013131295A'), isNotNull);
  });

  test('correo y contraseña', () {
    expect(Validadores.email('ventas@empresa.pe'), isNull);
    expect(Validadores.email('ventas@empresa'), isNotNull);
    expect(Validadores.email(''), isNotNull);
    expect(Validadores.password('clave2026'), isNull);
    expect(Validadores.password('corta1'), isNotNull);
    expect(Validadores.password('solamenteletras'), isNotNull);
    expect(Validadores.confirmacion('clave2026', 'clave2025'), isNotNull);
  });

  test('teléfono celular peruano', () {
    expect(Validadores.telefono('987654321'), isNull);
    expect(Validadores.telefono('87654321'), isNotNull);
    expect(Validadores.telefono('187654321'), isNotNull);
  });

  test('precio: acepta coma y respeta el rango', () {
    expect(Validadores.precio('80'), isNull);
    expect(Validadores.precio('80,50'), isNull);
    expect(Validadores.precioComoNumero('80,50'), closeTo(80.5, 0.0001));
    expect(Validadores.precio('0'), isNotNull);
    expect(Validadores.precio('abc'), isNotNull);
    expect(Validadores.precio('60000'), isNotNull);
  });

  test('textos del equipo', () {
    expect(Validadores.nombreEquipo('Mezcladora'), isNull);
    expect(Validadores.nombreEquipo('ab'), isNotNull);
    expect(Validadores.descripcion('corta'), isNotNull);
    expect(Validadores.descripcion('Mezcladora en buen estado con manual.'), isNull);
    expect(Validadores.comentario('ok'), isNotNull);
    expect(Validadores.estrellas(0), isNotNull);
    expect(Validadores.estrellas(5), isNull);
  });

  test('la URL del servidor se normaliza', () {
    expect(Validadores.normalizarUrlServidor('10.0.2.2:3000'), 'http://10.0.2.2:3000/');
    expect(Validadores.normalizarUrlServidor('http://192.168.1.50:3000'), 'http://192.168.1.50:3000/');
    expect(Validadores.normalizarUrlServidor('https://api.equishare.pe/'), 'https://api.equishare.pe/');
    expect(Validadores.normalizarUrlServidor('no es url'), isNull);
    expect(Validadores.normalizarUrlServidor(''), isNull);
  });
}
