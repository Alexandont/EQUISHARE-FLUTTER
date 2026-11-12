import 'dart:convert';
import 'dart:typed_data';

import 'package:equishare_flutter/data/cliente_api.dart';
import 'package:equishare_flutter/data/repositorios_api.dart';
import 'package:equishare_flutter/domain/resultado.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Pruebas de la capa de datos con un servidor falso (equivale a MockWebServer de la versión Kotlin):
/// rutas, token, lectura de las respuestas y traducción de errores, igual que en Kotlin.
void main() {
  final peticiones = <http.Request>[];

  ClienteApi cliente(http.Response Function(http.Request) responder) => ClienteApi(
        urlBase: () => 'http://servidor.prueba/',
        token: () async => 'demo:demo-prueba',
        cliente: MockClient((peticion) async {
          peticiones.add(peticion);
          return responder(peticion);
        }),
      );

  http.Response json(Object cuerpo, int estado) => http.Response(
        jsonEncode(cuerpo),
        estado,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  setUp(peticiones.clear);

  test('las métricas del panel se piden con el token y se leen completas', () async {
    final empresas = EmpresaRepositoryApi(cliente((_) => json({
          'equiposPublicados': 2,
          'equiposTotales': 3,
          'reservasPendientes': 1,
          'reservasActivas': 1,
          'reservasComoCliente': 4,
          'alquileresCompletados': 5,
          'ingresosEstimados': 850.5,
          'equipoMasAlquilado': {'nombre': 'Mezcladora de concreto', 'veces': 3},
        }, 200)));

    final r = await empresas.metricas();

    expect(peticiones.single.method, 'GET');
    expect(peticiones.single.url.toString(), 'http://servidor.prueba/api/empresas/me/metricas');
    expect(peticiones.single.headers['Authorization'], 'Bearer demo:demo-prueba');
    final m = r.datosONull!;
    expect(m.equiposTotales, 3);
    expect(m.ingresosEstimados, 850.5);
    expect(m.equipoMasAlquilado, 'Mezcladora de concreto');
    expect(m.vecesMasAlquilado, 3);
  });

  test('eliminar la cuenta usa DELETE y acepta la respuesta 204', () async {
    final empresas = EmpresaRepositoryApi(cliente((_) => http.Response('', 204)));

    final r = await empresas.eliminarMiCuenta();

    expect(r.esExito, isTrue);
    expect(peticiones.single.method, 'DELETE');
    expect(peticiones.single.url.path, '/api/empresas/me');
  });

  test('si hay reservas activas, el mensaje del servidor llega tal cual (409)', () async {
    final empresas = EmpresaRepositoryApi(cliente((_) => json({
          'error': {'codigo': 'CONFLICTO', 'mensaje': 'Tienes reservas activas.', 'detalles': []},
        }, 409)));

    final error = (await empresas.eliminarMiCuenta()).errorONull!;

    expect(error.tipo, TipoError.conflicto);
    expect(error.mensaje, 'Tienes reservas activas.');
    expect(error.codigo, 'CONFLICTO');
  });

  test('solo el 404 propio de la API significa "empresa sin registrar"', () async {
    final sinRegistrar = EmpresaRepositoryApi(cliente((_) => json({
          'error': {'codigo': 'NO_ENCONTRADO', 'mensaje': 'Registra tu empresa.'},
        }, 404)));
    final r1 = await sinRegistrar.miEmpresa();
    expect(r1.esExito, isTrue);
    expect(r1.datosONull, isNull);

    final rutaInexistente = EmpresaRepositoryApi(cliente((_) => http.Response('Not Found', 404)));
    expect((await rutaInexistente.miEmpresa()).errorONull?.tipo, TipoError.noEncontrado);
  });

  test('la foto se envía en el campo "foto" con su tipo de imagen, como en Kotlin', () async {
    final api = cliente((_) => json({'id': 'f1', 'url': 'http://servidor.prueba/uploads/f1.jpg'}, 201));
    final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3]);
    final formato = formatoDeImagen(jpeg);

    await api.subirArchivo('api/equipos/fotos', 'foto', jpeg, formato.nombre, tipoContenido: formato.tipo);

    final cuerpo = latin1.decode(peticiones.single.bodyBytes);
    expect(peticiones.single.url.path, '/api/equipos/fotos');
    expect(cuerpo, contains('name="foto"'));
    expect(cuerpo, contains('filename="foto.jpg"'));
    expect(cuerpo.toLowerCase(), contains('content-type: image/jpeg'));
  });

  test('el tipo de la foto se reconoce por su contenido', () {
    expect(formatoDeImagen(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xDB])).tipo, 'image/jpeg');
    expect(formatoDeImagen(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A])).nombre, 'foto.png');
    final webp = Uint8List.fromList([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50]);
    expect(formatoDeImagen(webp).tipo, 'image/webp');
  });

  test('sin conexión con el servidor se informa como SIN_CONEXION', () async {
    final api = ClienteApi(
      urlBase: () => 'http://servidor.prueba/',
      token: () async => null,
      cliente: MockClient((_) async => throw http.ClientException('Connection refused')),
    );
    final r = await EmpresaRepositoryApi(api).metricas();
    expect(r.errorONull?.tipo, TipoError.sinConexion);
  });
}
