import 'dart:typed_data';

import '../config.dart';
import '../domain/mapa/agrupador.dart';
import '../domain/modelos.dart';
import '../domain/repositorios.dart';
import '../domain/resultado.dart';
import 'almacen_local.dart';
import 'cliente_api.dart';

List<Map<String, dynamic>> _items(dynamic datos) {
  if (datos is! Map) throw const FormatException('Se esperaba un objeto con "items".');
  final items = datos['items'];
  if (items is! List) return [];
  return items.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
}

Map<String, dynamic> _objeto(dynamic datos) {
  if (datos is! Map) throw const FormatException('Se esperaba un objeto JSON.');
  return Map<String, dynamic>.from(datos);
}

String _id(String id) => Uri.encodeComponent(id);

/// Nombre y tipo con que se envía la foto, según su contenido real (sus primeros bytes).
/// En Kotlin la foto siempre se convierte a JPEG; el selector de fotos de Flutter ya la entrega
/// reducida y en JPEG, salvo imágenes con transparencia, que llegan en PNG.
({String nombre, String tipo}) formatoDeImagen(Uint8List bytes) {
  bool empiezaCon(List<int> firma, [int desde = 0]) {
    if (bytes.length < desde + firma.length) return false;
    for (var i = 0; i < firma.length; i++) {
      if (bytes[desde + i] != firma[i]) return false;
    }
    return true;
  }

  if (empiezaCon([0x89, 0x50, 0x4E, 0x47])) return (nombre: 'foto.png', tipo: 'image/png');
  if (empiezaCon([0x52, 0x49, 0x46, 0x46]) && empiezaCon([0x57, 0x45, 0x42, 0x50], 8)) {
    return (nombre: 'foto.webp', tipo: 'image/webp');
  }
  return (nombre: 'foto.jpg', tipo: 'image/jpeg');
}

/// Repositorio "offline-first": la UI siempre lee lo guardado en el teléfono; la red solo lo actualiza.
class EquipoRepositoryApi implements EquipoRepository {
  EquipoRepositoryApi(this._api, this._local)
      : _catalogo = Observable<List<Equipo>>([]),
        _propios = Observable<List<Equipo>>([]) {
    _catalogo.valor = _leer(claveCatalogo);
    _propios.valor = _leer(clavePropios);
  }

  static const String claveCatalogo = 'equipos_CATALOGO';
  static const String clavePropios = 'equipos_PROPIOS';

  final ClienteApi _api;
  final AlmacenLocal _local;
  final Observable<List<Equipo>> _catalogo;
  final Observable<List<Equipo>> _propios;

  List<Equipo> _leer(String clave) => _local.leerLista(clave).map(Equipo.fromJson).toList();

  Future<void> _guardar(String clave, Observable<List<Equipo>> destino, List<Equipo> lista) async {
    destino.valor = lista;
    await _local.guardarLista(clave, lista.map((e) => e.toJson()).toList());
  }

  @override
  Stream<List<Equipo>> observarCatalogo() => _catalogo.stream;

  @override
  Stream<List<Equipo>> observarPropios() => _propios.stream;

  @override
  Future<Resultado<void>> refrescarCatalogo(FiltroCatalogo filtro) async {
    final texto = filtro.texto.trim();
    final r = await _api.llamar<List<Equipo>>(() async {
      final datos = await _api.get('api/equipos', query: {
        'q': texto.isEmpty ? null : texto,
        'categoria': filtro.categoria?.codigo,
        'lat': filtro.ubicacion?.lat,
        'lng': filtro.ubicacion?.lng,
        'radioKm': filtro.radioKm,
      });
      return _items(datos).map(Equipo.fromJson).toList();
    });
    if (r is Fallo<List<Equipo>>) return Fallo<void>(r.error);
    await _guardar(claveCatalogo, _catalogo, (r as Exito<List<Equipo>>).datos);
    return const Exito<void>(null);
  }

  @override
  Future<Resultado<void>> refrescarPropios() async {
    final r = await _api.llamar<List<Equipo>>(() async {
      final datos = await _api.get('api/equipos/mios');
      return _items(datos).map(Equipo.fromJson).toList();
    });
    if (r is Fallo<List<Equipo>>) return Fallo<void>(r.error);
    await _guardar(clavePropios, _propios, (r as Exito<List<Equipo>>).datos);
    return const Exito<void>(null);
  }

  @override
  Future<Resultado<Equipo>> obtener(String id) async {
    final r = await _api.llamar<Equipo>(() async => Equipo.fromJson(_objeto(await _api.get('api/equipos/${_id(id)}'))));
    if (r is Fallo<Equipo>) {
      final tipo = r.error.tipo;
      if (tipo == TipoError.sinConexion || tipo == TipoError.tiempoAgotado) {
        // Sin conexión: se muestra la copia guardada si existe.
        for (final e in [..._catalogo.valor, ..._propios.valor]) {
          if (e.id == id) return Exito<Equipo>(e);
        }
      }
    }
    return r;
  }

  @override
  Future<Resultado<Equipo>> crear(EquipoEntrada entrada) async {
    final r = await _api.llamar<Equipo>(() async => Equipo.fromJson(_objeto(await _api.post('api/equipos', entrada.toJson()))));
    if (r.esExito) await refrescarPropios();
    return r;
  }

  @override
  Future<Resultado<Equipo>> actualizar(String id, EquipoEntrada entrada) async {
    final r = await _api
        .llamar<Equipo>(() async => Equipo.fromJson(_objeto(await _api.put('api/equipos/${_id(id)}', entrada.toJson()))));
    if (r.esExito) await refrescarPropios();
    return r;
  }

  @override
  Future<Resultado<void>> eliminar(String id) async {
    final r = await _api.llamar<void>(() async {
      await _api.delete('api/equipos/${_id(id)}');
    });
    if (r.esExito) {
      await _guardar(clavePropios, _propios, _propios.valor.where((e) => e.id != id).toList());
      await _guardar(claveCatalogo, _catalogo, _catalogo.valor.where((e) => e.id != id).toList());
    }
    return r;
  }

  @override
  Future<Resultado<FotoSubida>> subirFoto(Uint8List bytes, String nombreArchivo) async {
    if (bytes.isEmpty) {
      return Fallo<FotoSubida>(ErrorApp(TipoError.validacion, mensaje: 'No se pudo leer la imagen seleccionada.'));
    }
    final formato = formatoDeImagen(bytes);
    return _api.llamar<FotoSubida>(() async {
      final datos = _objeto(
        await _api.subirArchivo('api/equipos/fotos', 'foto', bytes, formato.nombre, tipoContenido: formato.tipo),
      );
      return FotoSubida('${datos['id'] ?? ''}', '${datos['url'] ?? ''}');
    });
  }

  @override
  Future<Resultado<List<RangoOcupado>>> disponibilidad(String id) => _api.llamar<List<RangoOcupado>>(() async {
        final datos = _objeto(await _api.get('api/equipos/${_id(id)}/disponibilidad'));
        final ocupados = datos['ocupados'];
        if (ocupados is! List) return <RangoOcupado>[];
        return ocupados.whereType<Map>().map((m) => RangoOcupado.fromJson(Map<String, dynamic>.from(m))).toList();
      });

  @override
  Future<Resultado<List<Resena>>> resenas(String id) => _api.llamar<List<Resena>>(() async {
        final datos = await _api.get('api/equipos/${_id(id)}/resenas');
        return _items(datos).map(Resena.fromJson).toList();
      });

  /// Borra los equipos propios guardados (al cerrar sesión, por privacidad).
  Future<void> limpiarPropios() async {
    _propios.valor = [];
    await _local.borrar(clavePropios);
  }
}

class ReservaRepositoryApi implements ReservaRepository {
  ReservaRepositoryApi(this._api, this._local) {
    for (final rol in Rol.values) {
      _porRol[rol] = Observable<List<Reserva>>(_local.leerLista(_clave(rol)).map(Reserva.fromJson).toList());
    }
  }

  final ClienteApi _api;
  final AlmacenLocal _local;
  final Map<Rol, Observable<List<Reserva>>> _porRol = {};

  static String _clave(Rol rol) => 'reservas_${rol.codigo}';

  Observable<List<Reserva>> _observable(Rol rol) => _porRol[rol]!;

  @override
  Stream<List<Reserva>> observarMias(Rol rol) => _observable(rol).stream;

  @override
  Future<Resultado<void>> refrescarMias(Rol rol) async {
    final r = await _api.llamar<List<Reserva>>(() async {
      final datos = await _api.get('api/reservas/mias', query: {'rol': rol.parametroApi});
      return _items(datos).map(Reserva.fromJson).toList();
    });
    if (r is Fallo<List<Reserva>>) return Fallo<void>(r.error);
    final datos = (r as Exito<List<Reserva>>).datos;
    _observable(rol).valor = datos;
    await _local.guardarLista(_clave(rol), datos.map((e) => e.toJson()).toList());
    return const Exito<void>(null);
  }

  @override
  Future<Resultado<Cotizacion>> cotizar(String equipoId, String inicio, String fin) => _api.llamar<Cotizacion>(
        () async => Cotizacion.fromJson(_objeto(await _api.post('api/reservas/cotizacion', {
              'equipoId': equipoId,
              'fechaInicio': inicio,
              'fechaFin': fin,
            }))),
      );

  @override
  Future<Resultado<Reserva>> crear(String equipoId, String inicio, String fin) async {
    final r = await _api.llamar<Reserva>(
      () async => Reserva.fromJson(_objeto(await _api.post('api/reservas', {
            'equipoId': equipoId,
            'fechaInicio': inicio,
            'fechaFin': fin,
          }))),
    );
    if (r.esExito) await refrescarMias(Rol.arrendatario);
    return r;
  }

  @override
  Future<Resultado<Reserva>> cancelar(String id) => _actualizarYRefrescar(
        () async => Reserva.fromJson(_objeto(await _api.patch('api/reservas/${_id(id)}/cancelar'))),
      );

  @override
  Future<Resultado<Reserva>> cambiarEstado(String id, EstadoReserva estado) => _actualizarYRefrescar(
        () async => Reserva.fromJson(_objeto(await _api.patch('api/reservas/${_id(id)}/estado', {'estado': estado.codigo}))),
      );

  @override
  Future<Resultado<void>> calificar(String id, int estrellas, String comentario) async {
    final r = await _api.llamar<void>(() async {
      await _api.post('api/reservas/${_id(id)}/resenas', {'estrellas': estrellas, 'comentario': comentario.trim()});
    });
    if (r.esExito) {
      await refrescarMias(Rol.arrendatario);
      await refrescarMias(Rol.arrendador);
    }
    return r;
  }

  Future<Resultado<Reserva>> _actualizarYRefrescar(Future<Reserva> Function() accion) async {
    final r = await _api.llamar<Reserva>(accion);
    if (r.esExito) {
      await refrescarMias(Rol.arrendatario);
      await refrescarMias(Rol.arrendador);
    }
    return r;
  }

  /// Borra las reservas guardadas (al cerrar sesión, por privacidad).
  Future<void> limpiar() async {
    for (final rol in Rol.values) {
      _observable(rol).valor = [];
      await _local.borrar(_clave(rol));
    }
  }
}

class EmpresaRepositoryApi implements EmpresaRepository {
  EmpresaRepositoryApi(this._api);

  final ClienteApi _api;

  @override
  Future<Resultado<Empresa?>> miEmpresa() async {
    final r = await _api.llamar<Empresa>(() async => Empresa.fromJson(_objeto(await _api.get('api/empresas/me'))));
    if (r is Exito<Empresa>) return Exito<Empresa?>(r.datos);
    final error = (r as Fallo<Empresa>).error;
    // Solo un 404 propio de la API significa "empresa aún no registrada".
    if (error.tipo == TipoError.noEncontrado && error.codigo == 'NO_ENCONTRADO') {
      return const Exito<Empresa?>(null);
    }
    return Fallo<Empresa?>(error);
  }

  @override
  Future<Resultado<Empresa>> guardar(String ruc, String razonSocial, String telefono) => _api.llamar<Empresa>(
        () async => Empresa.fromJson(_objeto(await _api.put('api/empresas/me', {
              'ruc': ruc.trim(),
              'razonSocial': razonSocial.trim(),
              'telefono': telefono.trim(),
            }))),
      );

  @override
  Future<Resultado<MetricasEmpresa>> metricas() => _api.llamar<MetricasEmpresa>(
        () async => MetricasEmpresa.fromJson(_objeto(await _api.get('api/empresas/me/metricas'))),
      );

  @override
  Future<Resultado<void>> eliminarMiCuenta() => _api.llamar<void>(() async {
        await _api.delete('api/empresas/me');
      });
}

class AjustesRepositoryLocal implements AjustesRepository {
  AjustesRepositoryLocal(this._local, {required this.probador});

  final AlmacenLocal _local;
  final Future<Resultado<String>> Function(String url) probador;

  static const String _claveUrl = 'url_servidor';
  static const String _claveCategoria = 'categoria_filtro';
  static const String _claveBienvenida = 'bienvenida_vista';
  static const String _claveTipoMapa = 'tipo_mapa';

  @override
  String get urlServidor => _local.leerAjuste(_claveUrl) ?? Config.urlServidorPorDefecto;

  @override
  Categoria? get categoriaFiltro => Categoria.desde(_local.leerAjuste(_claveCategoria));

  @override
  Future<void> guardarUrlServidor(String url) => _local.guardarAjuste(_claveUrl, url);

  @override
  Future<void> guardarCategoriaFiltro(Categoria? categoria) => _local.guardarAjuste(_claveCategoria, categoria?.codigo);

  @override
  Future<Resultado<String>> probarServidor(String url) => probador(url);

  @override
  bool get bienvenidaVista => _local.leerAjuste(_claveBienvenida) == 'si';

  @override
  Future<void> marcarBienvenidaVista() => _local.guardarAjuste(_claveBienvenida, 'si');

  @override
  TipoMapa get tipoMapa => TipoMapa.desde(_local.leerAjuste(_claveTipoMapa));

  @override
  Future<void> guardarTipoMapa(TipoMapa tipo) => _local.guardarAjuste(_claveTipoMapa, tipo.codigo);
}
