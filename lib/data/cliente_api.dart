import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../domain/resultado.dart';

/// Respuesta de error de la API: { "error": { "codigo", "mensaje", "detalles" } }
class ApiExcepcion implements Exception {
  ApiExcepcion(this.status, this.codigo, this.mensaje, this.detalles);

  final int status;
  final String? codigo;
  final String? mensaje;
  final List<String> detalles;

  @override
  String toString() => 'ApiExcepcion($status, $codigo, $mensaje)';
}

/// Cliente de la API REST de EQUISHARE (Node.js + Express). Equivale a Retrofit + OkHttp.
/// Agrega el token de Firebase (o de demostración) en la cabecera Authorization.
class ClienteApi {
  ClienteApi({
    required this.urlBase,
    required this.token,
    this.alResultadoRed,
    http.Client? cliente,
  }) : _http = cliente ?? http.Client();

  final String Function() urlBase;
  final Future<String?> Function() token;

  /// Avisa si el servidor respondió (true) o si no se pudo llegar a él (false).
  final void Function(bool enLinea)? alResultadoRed;

  final http.Client _http;

  static const Duration _limite = Duration(seconds: 20);
  static const Duration _limiteSubida = Duration(seconds: 60);

  Uri _uri(String ruta, {Map<String, Object?>? query, String? base}) {
    final uri = Uri.parse(base ?? urlBase()).resolve(ruta);
    final parametros = <String, String>{
      for (final entrada in (query ?? const <String, Object?>{}).entries)
        if (entrada.value != null) entrada.key: '${entrada.value}',
    };
    return parametros.isEmpty ? uri : uri.replace(queryParameters: parametros);
  }

  Future<Map<String, String>> _cabeceras({bool conJson = false}) async {
    final cabeceras = <String, String>{'Accept': 'application/json'};
    if (conJson) cabeceras['Content-Type'] = 'application/json; charset=utf-8';
    final t = await token();
    if (t != null) cabeceras['Authorization'] = 'Bearer $t';
    return cabeceras;
  }

  Future<dynamic> get(String ruta, {Map<String, Object?>? query, String? base}) async {
    final respuesta =
        await _http.get(_uri(ruta, query: query, base: base), headers: await _cabeceras()).timeout(_limite);
    return _procesar(respuesta);
  }

  Future<dynamic> post(String ruta, [Map<String, Object?>? cuerpo]) async {
    final respuesta = await _http
        .post(_uri(ruta), headers: await _cabeceras(conJson: cuerpo != null), body: cuerpo == null ? null : jsonEncode(cuerpo))
        .timeout(_limite);
    return _procesar(respuesta);
  }

  Future<dynamic> put(String ruta, Map<String, Object?> cuerpo) async {
    final respuesta =
        await _http.put(_uri(ruta), headers: await _cabeceras(conJson: true), body: jsonEncode(cuerpo)).timeout(_limite);
    return _procesar(respuesta);
  }

  Future<dynamic> patch(String ruta, [Map<String, Object?>? cuerpo]) async {
    final respuesta = await _http
        .patch(_uri(ruta), headers: await _cabeceras(conJson: cuerpo != null), body: cuerpo == null ? null : jsonEncode(cuerpo))
        .timeout(_limite);
    return _procesar(respuesta);
  }

  Future<dynamic> delete(String ruta) async {
    final respuesta = await _http.delete(_uri(ruta), headers: await _cabeceras()).timeout(_limite);
    return _procesar(respuesta);
  }

  /// Envía un archivo en un formulario multipart (campo "foto" para las fotos de equipos).
  /// [tipoContenido] es el tipo del archivo, por ejemplo "image/jpeg" (como en Kotlin).
  Future<dynamic> subirArchivo(
    String ruta,
    String campo,
    Uint8List bytes,
    String nombreArchivo, {
    String? tipoContenido,
  }) async {
    final peticion = http.MultipartRequest('POST', _uri(ruta));
    peticion.headers.addAll(await _cabeceras());
    peticion.files.add(http.MultipartFile.fromBytes(
      campo,
      bytes,
      filename: nombreArchivo,
      contentType: tipoContenido == null ? null : MediaType.parse(tipoContenido),
    ));
    final enviada = await _http.send(peticion).timeout(_limiteSubida);
    final respuesta = await http.Response.fromStream(enviada).timeout(_limiteSubida);
    return _procesar(respuesta);
  }

  dynamic _procesar(http.Response respuesta) {
    dynamic cuerpo;
    if (respuesta.bodyBytes.isNotEmpty) {
      try {
        cuerpo = jsonDecode(utf8.decode(respuesta.bodyBytes));
      } catch (_) {
        cuerpo = null;
      }
    }
    if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) return cuerpo;

    String? codigo;
    String? mensaje;
    final detalles = <String>[];
    if (cuerpo is Map && cuerpo['error'] is Map) {
      final error = cuerpo['error'] as Map;
      codigo = error['codigo']?.toString();
      mensaje = error['mensaje']?.toString();
      final lista = error['detalles'];
      if (lista is List) {
        for (final d in lista) {
          if (d is String) {
            detalles.add(d);
          } else if (d is Map && d['mensaje'] != null) {
            detalles.add('${d['mensaje']}');
          }
        }
      }
    }
    throw ApiExcepcion(respuesta.statusCode, codigo, mensaje, detalles);
  }

  /// Ejecuta una llamada y convierte cualquier fallo en un [Fallo] con un mensaje entendible:
  /// errores HTTP (400, 401, 403, 404, 409, 422, 5xx), falta de conexión y tiempo agotado.
  Future<Resultado<T>> llamar<T>(Future<T> Function() bloque) async {
    try {
      final datos = await bloque();
      alResultadoRed?.call(true);
      return Exito<T>(datos);
    } on ApiExcepcion catch (e) {
      alResultadoRed?.call(true);
      final mensaje = (e.mensaje == null || e.mensaje!.trim().isEmpty) ? null : e.mensaje;
      return Fallo<T>(ErrorApp(TipoError.desdeCodigoHttp(e.status), mensaje: mensaje, codigo: e.codigo, detalles: e.detalles));
    } on TimeoutException {
      alResultadoRed?.call(false);
      return Fallo<T>(ErrorApp(TipoError.tiempoAgotado));
    } on http.ClientException {
      alResultadoRed?.call(false);
      return Fallo<T>(ErrorApp(TipoError.sinConexion));
    } on FormatException {
      return Fallo<T>(ErrorApp(
        TipoError.desconocido,
        mensaje: 'La dirección del servidor o su respuesta no es válida. Revísala en Perfil > Conexión con el servidor.',
      ));
    } catch (e) {
      final texto = '$e';
      if (texto.contains('Socket') || texto.contains('Connection') || texto.contains('XMLHttpRequest')) {
        alResultadoRed?.call(false);
        return Fallo<T>(ErrorApp(TipoError.sinConexion));
      }
      return Fallo<T>(ErrorApp(TipoError.desconocido, mensaje: 'Ocurrió un error inesperado: $texto'));
    }
  }

  /// GET /api/health en la dirección indicada. Devuelve el modo de autenticación del servidor.
  Future<Resultado<String>> salud(String url) => llamar<String>(() async {
        final datos = await get('api/health', base: url);
        if (datos is Map) return '${datos['modoAutenticacion'] ?? 'desconocido'}';
        throw const FormatException('Respuesta inesperada de /api/health');
      });
}
