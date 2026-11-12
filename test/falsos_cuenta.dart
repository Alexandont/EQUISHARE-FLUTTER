import 'dart:async';

import 'package:equishare_flutter/contenedor.dart';
import 'package:equishare_flutter/domain/ia/clasificador_equipo.dart';
import 'package:equishare_flutter/domain/modelos.dart';
import 'package:equishare_flutter/domain/repositorios.dart';
import 'package:equishare_flutter/domain/resultado.dart';

import 'falsos.dart';

/*
 * Repositorios falsos para las pruebas de cuenta y seguridad (equivalen a FakeAuth,
 * FakeEmpresaRepository, FakeFavoritos y FakeLectorTexto de la versión Kotlin).
 */

class AuthCuentaFalsa implements AuthRepository {
  AuthCuentaFalsa({Sesion? sesionInicial, this.esModoDemo = true, this.fallar = false})
      : _sesion = Observable<Sesion?>(sesionInicial);

  final bool fallar;
  final Observable<Sesion?> _sesion;
  int llamadas = 0;

  /// Nombre de cada operación de cuenta llamada, en orden.
  final List<String> acciones = [];

  /// Operaciones que deben fallar, con su error.
  final Map<String, ErrorApp> errores = {};

  /// Lo que responde "revisarVerificacion" (si el correo ya se verificó).
  bool correoYaVerificado = false;
  String? ultimoCorreoRecuperar;

  @override
  final bool esModoDemo;

  @override
  Sesion? get sesionActual => _sesion.valor;

  @override
  bool get sesionCargada => true;

  @override
  Stream<Sesion?> get cambios => _sesion.stream;

  @override
  Future<Resultado<Sesion>> iniciarSesion(String email, String password) async {
    llamadas++;
    if (fallar) return Fallo<Sesion>(ErrorApp(TipoError.noAutenticado, mensaje: 'Correo o contraseña incorrectos.'));
    final s = Sesion(uid: 'demo-x', email: email, esDemo: true);
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
  Future<String?> tokenParaApi() async {
    final s = _sesion.valor;
    return s == null ? null : 'demo:${s.uid}';
  }

  Resultado<T> _accion<T>(String nombre, T valor) {
    acciones.add(nombre);
    final error = errores[nombre];
    return error != null ? Fallo<T>(error) : Exito<T>(valor);
  }

  @override
  Future<Resultado<void>> enviarVerificacion() async => _accion<void>('enviarVerificacion', null);

  @override
  Future<Resultado<bool>> revisarVerificacion() async {
    final r = _accion<bool>('revisarVerificacion', correoYaVerificado);
    final s = _sesion.valor;
    if (r is Exito<bool> && r.datos && s != null) {
      _sesion.valor = Sesion(uid: s.uid, email: s.email, esDemo: s.esDemo, correoVerificado: true);
    }
    return r;
  }

  @override
  Future<Resultado<void>> recuperarContrasena(String email) async {
    ultimoCorreoRecuperar = email;
    return _accion<void>('recuperarContrasena', null);
  }

  @override
  Future<Resultado<void>> confirmarContrasena(String password) async => _accion<void>('confirmarContrasena', null);

  @override
  Future<Resultado<void>> cambiarContrasena(String actual, String nueva) async =>
      _accion<void>('cambiarContrasena', null);

  @override
  Future<Resultado<void>> eliminarUsuario() async {
    final r = _accion<void>('eliminarUsuario', null);
    if (r.esExito) _sesion.valor = null;
    return r;
  }
}

/// Registro de empresa falso: guarda lo que recibe para revisarlo en la prueba.
class EmpresasCuentaFalsas implements EmpresaRepository {
  final List<(String, String, String)> guardadas = [];
  Empresa? miEmpresaActual;
  bool eliminada = false;
  ErrorApp? errorEliminar;

  @override
  Future<Resultado<Empresa?>> miEmpresa() async => Exito<Empresa?>(miEmpresaActual);

  @override
  Future<Resultado<Empresa>> guardar(String ruc, String razonSocial, String telefono) async {
    guardadas.add((ruc, razonSocial, telefono));
    return Exito<Empresa>(Empresa(
      id: 'empresa-1',
      razonSocial: razonSocial,
      ruc: ruc,
      telefono: telefono,
      email: null,
      verificada: true,
      calificacionComoArrendatario: 0,
      totalResenasComoArrendatario: 0,
    ));
  }

  @override
  Future<Resultado<void>> eliminarMiCuenta() async {
    final error = errorEliminar;
    if (error != null) return Fallo<void>(error);
    eliminada = true;
    return const Exito<void>(null);
  }

  /// Mismos números de prueba que la versión Kotlin.
  Resultado<MetricasEmpresa> metricasActuales = const Exito<MetricasEmpresa>(MetricasEmpresa(
    equiposPublicados: 3,
    equiposTotales: 4,
    reservasPendientes: 2,
    reservasActivas: 1,
    reservasComoCliente: 0,
    alquileresCompletados: 5,
    ingresosEstimados: 1250.5,
    equipoMasAlquilado: 'Mezcladora',
    vecesMasAlquilado: 3,
  ));

  @override
  Future<Resultado<MetricasEmpresa>> metricas() async => metricasActuales;
}

class FavoritosCuentaFalsos implements FavoritosRepository {
  final Observable<Set<String>> _ids = Observable<Set<String>>(<String>{});
  bool borrado = false;
  ErrorApp? errorBorrar;

  @override
  Stream<Set<String>> observar() => _ids.stream;

  @override
  Future<Resultado<void>> establecer(Equipo equipo, bool favorito) async {
    _ids.valor = favorito ? {..._ids.valor, equipo.id} : ({..._ids.valor}..remove(equipo.id));
    return const Exito<void>(null);
  }

  @override
  Future<Resultado<void>> registrarConsentimiento(String? email) async => const Exito<void>(null);

  @override
  Future<Resultado<void>> borrarMisDatos() async {
    final error = errorBorrar;
    if (error != null) return Fallo<void>(error);
    borrado = true;
    return const Exito<void>(null);
  }
}

/// IA falsa que "lee" el texto configurado de cualquier foto.
class LectorTextoFalso implements LectorTextoFoto {
  LectorTextoFalso(this.texto);

  String? texto;
  Object? lanzar;
  final List<String> pedidas = [];

  @override
  Future<String?> leerTexto(String rutaFoto) async {
    pedidas.add(rutaFoto);
    final error = lanzar;
    if (error != null) throw error;
    return texto;
  }
}

Contenedor contenedorDeCuenta({
  AuthRepository? auth,
  EmpresaRepository? empresas,
  FavoritosRepository? favoritos,
  LectorTextoFoto? lector,
  Future<void> Function()? limpiar,
}) =>
    Contenedor(
      auth: auth ?? AuthCuentaFalsa(),
      equipos: EquiposFalsos(),
      reservas: ReservasFalsas(),
      empresas: empresas ?? EmpresasCuentaFalsas(),
      favoritos: favoritos ?? FavoritosCuentaFalsos(),
      ajustes: AjustesFalsos(),
      red: RedFalsa(),
      ubicacion: UbicacionFalsa(),
      lectorTexto: lector ?? const LectorTextoFotoNinguno(),
      limpiarDatosDeSesion: limpiar ?? () async {},
      mapasActivos: false,
    );

/// Deja que terminen las tareas pendientes (equivale al despachador inmediato de las pruebas de Kotlin).
Future<void> esperarTareas() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// IA de fotos falsa: responde lo configurado. Las fotos en [esperarEn] quedan "pensando" hasta que
/// la prueba llame a [responder], para simular una IA lenta.
class AnalizadorFotoFalso implements AnalizadorFoto {
  AnalizadorFotoFalso([this.respuesta = const []]);

  List<EtiquetaFoto>? respuesta;
  Object? lanzar;
  Set<String> esperarEn = {};
  final List<String> pedidas = [];
  final Map<String, Completer<List<EtiquetaFoto>?>> _pendientes = {};

  @override
  Future<List<EtiquetaFoto>?> etiquetar(String rutaFoto) async {
    pedidas.add(rutaFoto);
    final error = lanzar;
    if (error != null) throw error;
    if (esperarEn.contains(rutaFoto)) return _pendientes.putIfAbsent(rutaFoto, Completer.new).future;
    return respuesta;
  }

  void responder(String rutaFoto, List<EtiquetaFoto>? etiquetas) {
    _pendientes.putIfAbsent(rutaFoto, Completer.new).complete(etiquetas);
  }
}
