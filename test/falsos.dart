import 'dart:typed_data';

import 'package:equishare_flutter/contenedor.dart';
import 'package:equishare_flutter/domain/mapa/agrupador.dart';
import 'package:equishare_flutter/domain/modelos.dart';
import 'package:equishare_flutter/domain/repositorios.dart';
import 'package:equishare_flutter/domain/resultado.dart';

/*
 * Repositorios falsos para las pruebas: permiten probar las pantallas reales sin servidor,
 * sin Firebase, sin GPS y sin base de datos.
 */

Equipo equipoDePrueba(String id, String nombre, Categoria categoria) => Equipo(
      id: id,
      empresaId: 'demo-constructora',
      empresaNombre: 'Constructora Demo',
      nombre: nombre,
      categoria: categoria,
      descripcion: 'Equipo de prueba',
      precioDia: 80,
      fotoUrl: null,
      fotoId: null,
      lat: -8.11,
      lng: -79.03,
      direccion: 'Trujillo',
      estado: EstadoEquipo.publicado,
      calificacionPromedio: 0,
      totalResenas: 0,
      distanciaKm: null,
    );

final Equipo mezcladora = equipoDePrueba('eq-1', 'Mezcladora de concreto', Categoria.construccion);
final Equipo sonido = equipoDePrueba('eq-2', 'Equipo de sonido profesional', Categoria.eventos);
final Equipo taladro = equipoDePrueba('eq-3', 'Taladro percutor', Categoria.herramientas);

class EquiposFalsos implements EquipoRepository {
  EquiposFalsos({List<Equipo>? respuesta}) : respuestaServidor = respuesta ?? [mezcladora, sonido, taladro];

  final Observable<List<Equipo>> catalogo = Observable<List<Equipo>>([]);
  List<Equipo> respuestaServidor;
  ErrorApp? fallarCon;
  final List<FiltroCatalogo> filtrosRecibidos = [];

  @override
  Stream<List<Equipo>> observarCatalogo() => catalogo.stream;

  @override
  Future<Resultado<void>> refrescarCatalogo(FiltroCatalogo filtro) async {
    filtrosRecibidos.add(filtro);
    final error = fallarCon;
    if (error != null) return Fallo<void>(error);
    final texto = filtro.texto.trim().toLowerCase();
    catalogo.valor = respuestaServidor
        .where((e) => filtro.categoria == null || e.categoria == filtro.categoria)
        .where((e) => texto.isEmpty || e.nombre.toLowerCase().contains(texto))
        .toList();
    return const Exito<void>(null);
  }

  @override
  Stream<List<Equipo>> observarPropios() => Observable<List<Equipo>>([]).stream;

  @override
  Future<Resultado<void>> refrescarPropios() async => const Exito<void>(null);

  @override
  Future<Resultado<Equipo>> obtener(String id) async => Exito<Equipo>(mezcladora);

  @override
  Future<Resultado<Equipo>> crear(EquipoEntrada entrada) async => Exito<Equipo>(mezcladora);

  @override
  Future<Resultado<Equipo>> actualizar(String id, EquipoEntrada entrada) async => Exito<Equipo>(mezcladora);

  @override
  Future<Resultado<void>> eliminar(String id) async => const Exito<void>(null);

  @override
  Future<Resultado<FotoSubida>> subirFoto(Uint8List bytes, String nombreArchivo) async =>
      Fallo<FotoSubida>(ErrorApp(TipoError.validacion));

  @override
  Future<Resultado<List<RangoOcupado>>> disponibilidad(String id) async => const Exito<List<RangoOcupado>>([]);

  @override
  Future<Resultado<List<Resena>>> resenas(String id) async => const Exito<List<Resena>>([]);
}

class ReservasFalsas implements ReservaRepository {
  @override
  Stream<List<Reserva>> observarMias(Rol rol) => Observable<List<Reserva>>([]).stream;

  @override
  Future<Resultado<void>> refrescarMias(Rol rol) async => const Exito<void>(null);

  @override
  Future<Resultado<Cotizacion>> cotizar(String equipoId, String inicio, String fin) async =>
      Fallo<Cotizacion>(ErrorApp(TipoError.desconocido));

  @override
  Future<Resultado<Reserva>> crear(String equipoId, String inicio, String fin) async =>
      Fallo<Reserva>(ErrorApp(TipoError.desconocido));

  @override
  Future<Resultado<Reserva>> cancelar(String id) async => Fallo<Reserva>(ErrorApp(TipoError.desconocido));

  @override
  Future<Resultado<Reserva>> cambiarEstado(String id, EstadoReserva estado) async =>
      Fallo<Reserva>(ErrorApp(TipoError.desconocido));

  @override
  Future<Resultado<void>> calificar(String id, int estrellas, String comentario) async => const Exito<void>(null);
}

class EmpresasFalsas implements EmpresaRepository {
  @override
  Future<Resultado<Empresa?>> miEmpresa() async => const Exito<Empresa?>(null);

  @override
  Future<Resultado<Empresa>> guardar(String ruc, String razonSocial, String telefono) async =>
      Fallo<Empresa>(ErrorApp(TipoError.desconocido));

  int cuentasEliminadas = 0;

  @override
  Future<Resultado<void>> eliminarMiCuenta() async {
    cuentasEliminadas++;
    return const Exito<void>(null);
  }

  @override
  Future<Resultado<MetricasEmpresa>> metricas() async => Exito<MetricasEmpresa>(MetricasEmpresa.fromJson({}));
}

class FavoritosFalsos implements FavoritosRepository {
  final Observable<Set<String>> ids = Observable<Set<String>>(<String>{});

  @override
  Stream<Set<String>> observar() => ids.stream;

  @override
  Future<Resultado<void>> establecer(Equipo equipo, bool favorito) async {
    ids.valor = favorito ? {...ids.valor, equipo.id} : ({...ids.valor}..remove(equipo.id));
    return const Exito<void>(null);
  }

  @override
  Future<Resultado<void>> registrarConsentimiento(String? email) async => const Exito<void>(null);

  @override
  Future<Resultado<void>> borrarMisDatos() async {
    ids.valor = <String>{};
    return const Exito<void>(null);
  }
}

class AjustesFalsos implements AjustesRepository {
  @override
  String urlServidor = 'http://localhost:3000/';

  @override
  Categoria? categoriaFiltro;

  @override
  Future<void> guardarUrlServidor(String url) async {
    urlServidor = url;
  }

  @override
  Future<void> guardarCategoriaFiltro(Categoria? categoria) async {
    categoriaFiltro = categoria;
  }

  @override
  Future<Resultado<String>> probarServidor(String url) async => const Exito<String>('demo');

  @override
  bool bienvenidaVista = true;

  @override
  Future<void> marcarBienvenidaVista() async {
    bienvenidaVista = true;
  }

  @override
  TipoMapa tipoMapa = TipoMapa.normal;

  @override
  Future<void> guardarTipoMapa(TipoMapa tipo) async {
    tipoMapa = tipo;
  }
}

class RedFalsa implements MonitorRed {
  RedFalsa({bool enLinea = true}) : estado = Observable<bool>(enLinea);

  final Observable<bool> estado;

  @override
  bool get enLineaActual => estado.valor;

  @override
  Stream<bool> get enLinea => estado.stream;
}

class UbicacionFalsa implements ProveedorUbicacion {
  UbicacionFalsa({this.coordenadas = const Coordenadas(-8.1116, -79.0287)});

  Coordenadas? coordenadas;

  @override
  Future<bool> tienePermiso() async => true;

  @override
  Future<Coordenadas?> ubicacionActual() async => coordenadas;
}

/// Ubicación sin permiso: la persona negó el permiso de ubicación.
class UbicacionSinPermiso implements ProveedorUbicacion {
  @override
  Future<bool> tienePermiso() async => false;

  @override
  Future<Coordenadas?> ubicacionActual() async => null;
}

class AuthFalso implements AuthRepository {
  AuthFalso({this.fallar = false});

  final bool fallar;
  final Observable<Sesion?> _sesion = Observable<Sesion?>(null);
  int llamadas = 0;
  String? ultimoEmail;

  @override
  Sesion? get sesionActual => _sesion.valor;

  @override
  bool get sesionCargada => true;

  @override
  Stream<Sesion?> get cambios => _sesion.stream;

  @override
  bool get esModoDemo => true;

  @override
  Future<Resultado<Sesion>> iniciarSesion(String email, String password) async {
    llamadas++;
    ultimoEmail = email;
    if (fallar) return Fallo<Sesion>(ErrorApp(TipoError.noAutenticado, mensaje: 'Correo o contraseña incorrectos.'));
    final s = Sesion(uid: 'demo-prueba', email: email, esDemo: true);
    _sesion.valor = s;
    return Exito<Sesion>(s);
  }

  @override
  Future<Resultado<Sesion>> registrar(String email, String password) => iniciarSesion(email, password);

  @override
  Future<void> cerrarSesion() async {
    _sesion.valor = null;
  }

  @override
  Future<String?> tokenParaApi() async => null;

  @override
  Future<Resultado<void>> enviarVerificacion() async => const Exito<void>(null);

  @override
  Future<Resultado<bool>> revisarVerificacion() async => const Exito<bool>(true);

  @override
  Future<Resultado<void>> recuperarContrasena(String email) async => const Exito<void>(null);

  @override
  Future<Resultado<void>> confirmarContrasena(String password) async => const Exito<void>(null);

  @override
  Future<Resultado<void>> cambiarContrasena(String actual, String nueva) async => const Exito<void>(null);

  @override
  Future<Resultado<void>> eliminarUsuario() async {
    _sesion.valor = null;
    return const Exito<void>(null);
  }
}

Contenedor contenedorDePrueba({
  AuthRepository? auth,
  EquipoRepository? equipos,
  FavoritosRepository? favoritos,
  MonitorRed? red,
  ProveedorUbicacion? ubicacion,
  AjustesRepository? ajustes,
}) =>
    Contenedor(
      auth: auth ?? AuthFalso(),
      equipos: equipos ?? EquiposFalsos(),
      reservas: ReservasFalsas(),
      empresas: EmpresasFalsas(),
      favoritos: favoritos ?? FavoritosFalsos(),
      ajustes: ajustes ?? AjustesFalsos(),
      red: red ?? RedFalsa(),
      ubicacion: ubicacion ?? UbicacionFalsa(),
      limpiarDatosDeSesion: () async {},
      mapasActivos: false,
    );
