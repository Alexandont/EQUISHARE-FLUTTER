import 'package:firebase_auth/firebase_auth.dart';

import '../domain/modelos.dart';
import '../domain/repositorios.dart';
import '../domain/resultado.dart';
import 'almacen_local.dart';

/// Códigos de Firebase que equivalen a cada excepción de la versión Kotlin.
const Set<String> _contrasenaDebil = {'weak-password'};
const Set<String> _credencialInvalida = {
  'invalid-credential',
  'invalid-login-credentials',
  'wrong-password',
  'invalid-email',
};
const Set<String> _usuarioInvalido = {
  'user-not-found',
  'user-disabled',
  'user-token-expired',
  'invalid-user-token',
  'requires-recent-login',
  'user-mismatch',
};
const Set<String> _cuentaRepetida = {
  'email-already-in-use',
  'credential-already-in-use',
  'account-exists-with-different-credential',
};
const String _sinRed = 'network-request-failed';
const String _muchosIntentos = 'too-many-requests';

/// Autenticación con Firebase Authentication (correo y contraseña).
class AuthFirebase implements AuthRepository {
  AuthFirebase([FirebaseAuth? auth]) : _auth = auth ?? FirebaseAuth.instance {
    _sesion = Observable<Sesion?>(_aSesion(_auth.currentUser));
    // Los correos de verificación y de cambio de contraseña llegan en español.
    _auth.setLanguageCode('es').ignore();
    // El primer evento llega cuando Firebase terminó de restaurar la sesión guardada.
    _auth.authStateChanges().listen((usuario) {
      _cargada = true;
      _sesion.valor = _aSesion(usuario);
    });
  }

  final FirebaseAuth _auth;
  late final Observable<Sesion?> _sesion;
  bool _cargada = false;

  static const String _sinSesion = 'Tu sesión terminó. Vuelve a iniciar sesión.';

  static Sesion? _aSesion(User? u) => u == null
      ? null
      : Sesion(uid: u.uid, email: u.email, esDemo: false, correoVerificado: u.emailVerified);

  @override
  Sesion? get sesionActual => _sesion.valor;

  @override
  bool get sesionCargada => _cargada;

  @override
  Stream<Sesion?> get cambios => _sesion.stream;

  @override
  bool get esModoDemo => false;

  @override
  Future<Resultado<Sesion>> iniciarSesion(String email, String password) => _ejecutar(() async {
        final credencial = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
        return credencial.user;
      });

  @override
  Future<Resultado<Sesion>> registrar(String email, String password) => _ejecutar(() async {
        final credencial = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
        final usuario = credencial.user;
        // Seguridad: se envía el enlace de verificación. Si falla, la pantalla "Revisa tu correo" permite reenviarlo.
        try {
          await usuario?.sendEmailVerification();
        } catch (_) {
          // Se puede reenviar desde la pantalla "Revisa tu correo".
        }
        return usuario;
      });

  @override
  Future<void> cerrarSesion() => _auth.signOut();

  @override
  Future<Resultado<void>> enviarVerificacion() => _operacion<void>(() async {
        final usuario = _auth.currentUser;
        if (usuario == null) throw const _SinSesion();
        await usuario.sendEmailVerification();
      });

  @override
  Future<Resultado<bool>> revisarVerificacion() => _operacion<bool>(() async {
        final usuario = _auth.currentUser;
        if (usuario == null) throw const _SinSesion();
        await usuario.reload();
        final actual = _auth.currentUser;
        if (actual == null) throw const _SinSesion();
        if (actual.emailVerified) {
          // Se pide un token nuevo para que el servidor también vea el correo como verificado.
          await actual.getIdToken(true);
          _sesion.valor = _aSesion(actual);
        }
        return actual.emailVerified;
      });

  @override
  Future<Resultado<void>> recuperarContrasena(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return const Exito<void>(null);
    } on FirebaseAuthException catch (e) {
      // Misma respuesta exista o no la cuenta: así nadie puede averiguar qué correos están registrados.
      if (_usuarioInvalido.contains(e.code)) return const Exito<void>(null);
      return Fallo<void>(_traducir(e));
    } catch (e) {
      return Fallo<void>(_traducir(e));
    }
  }

  @override
  Future<Resultado<void>> confirmarContrasena(String password) => _operacion<void>(() async {
        final usuario = _auth.currentUser;
        final email = usuario?.email;
        if (usuario == null || email == null) throw const _SinSesion();
        await usuario.reauthenticateWithCredential(EmailAuthProvider.credential(email: email, password: password));
      });

  @override
  Future<Resultado<void>> cambiarContrasena(String actual, String nueva) => _operacion<void>(() async {
        final usuario = _auth.currentUser;
        final email = usuario?.email;
        if (usuario == null || email == null) throw const _SinSesion();
        await usuario.reauthenticateWithCredential(EmailAuthProvider.credential(email: email, password: actual));
        await usuario.updatePassword(nueva);
      });

  @override
  Future<Resultado<void>> eliminarUsuario() => _operacion<void>(() async {
        final usuario = _auth.currentUser;
        if (usuario == null) throw const _SinSesion();
        await usuario.delete();
        await _auth.signOut();
        _sesion.valor = null;
      });

  @override
  Future<String?> tokenParaApi() async {
    final usuario = _auth.currentUser;
    if (usuario == null) return null;
    try {
      return await usuario.getIdToken().timeout(const Duration(seconds: 10));
    } catch (_) {
      return null;
    }
  }

  /// Ejecuta una operación de la cuenta y convierte los errores de Firebase en mensajes claros.
  Future<Resultado<T>> _operacion<T>(Future<T> Function() accion) async {
    try {
      return Exito<T>(await accion());
    } catch (e) {
      return Fallo<T>(_traducir(e));
    }
  }

  static ErrorApp _traducir(Object e) {
    if (e is _SinSesion) return ErrorApp(TipoError.noAutenticado, mensaje: _sinSesion);
    if (e is FirebaseAuthException) {
      if (_contrasenaDebil.contains(e.code)) {
        return ErrorApp(TipoError.validacion,
            mensaje: 'La contraseña es muy débil. Usa al menos 8 caracteres con letras y números.');
      }
      if (_credencialInvalida.contains(e.code)) {
        return ErrorApp(TipoError.noAutenticado, mensaje: 'La contraseña no es correcta.');
      }
      if (_usuarioInvalido.contains(e.code)) {
        return ErrorApp(TipoError.noAutenticado, mensaje: 'Tu sesión ya no es válida. Vuelve a iniciar sesión.');
      }
      if (e.code == _muchosIntentos) {
        return ErrorApp(TipoError.validacion,
            mensaje: 'Hiciste muchos intentos seguidos. Espera unos minutos y vuelve a intentarlo.');
      }
      if (e.code == _sinRed) {
        return ErrorApp(TipoError.sinConexion,
            mensaje: 'Sin conexión a internet. Revisa tu conexión e inténtalo de nuevo.');
      }
    }
    final mensaje = e is FirebaseException ? e.message : null;
    return ErrorApp(TipoError.desconocido, mensaje: mensaje ?? 'No se pudo completar la operación.');
  }

  Future<Resultado<Sesion>> _ejecutar(Future<User?> Function() accion) async {
    try {
      final usuario = await accion();
      if (usuario == null) {
        return Fallo<Sesion>(ErrorApp(TipoError.desconocido, mensaje: 'No se pudo iniciar la sesión.'));
      }
      final sesion = _aSesion(usuario)!;
      _cargada = true;
      _sesion.valor = sesion;
      return Exito<Sesion>(sesion);
    } on FirebaseAuthException catch (e) {
      if (_contrasenaDebil.contains(e.code)) {
        return Fallo<Sesion>(ErrorApp(TipoError.validacion,
            mensaje: 'La contraseña es muy débil. Usa al menos 8 caracteres con letras y números.'));
      }
      if (_credencialInvalida.contains(e.code)) {
        return Fallo<Sesion>(ErrorApp(TipoError.noAutenticado, mensaje: 'Correo o contraseña incorrectos.'));
      }
      if (_usuarioInvalido.contains(e.code)) {
        return Fallo<Sesion>(
            ErrorApp(TipoError.noAutenticado, mensaje: 'No existe una cuenta con ese correo o fue deshabilitada.'));
      }
      if (_cuentaRepetida.contains(e.code)) {
        return Fallo<Sesion>(ErrorApp(TipoError.conflicto, mensaje: 'Ya existe una cuenta con ese correo. Inicia sesión.'));
      }
      if (e.code == _sinRed) {
        return Fallo<Sesion>(ErrorApp(TipoError.sinConexion, mensaje: 'Sin conexión a internet para validar tu cuenta.'));
      }
      return Fallo<Sesion>(
          ErrorApp(TipoError.desconocido, mensaje: e.message ?? 'No se pudo completar la autenticación.'));
    } catch (e) {
      final mensaje = e is FirebaseException ? e.message : null;
      return Fallo<Sesion>(ErrorApp(TipoError.desconocido, mensaje: mensaje ?? 'No se pudo completar la autenticación.'));
    }
  }
}

/// No hay sesión abierta (equivale a la IllegalStateException de la versión Kotlin).
class _SinSesion implements Exception {
  const _SinSesion();
}

/// MODO DEMOSTRACIÓN (cuando Firebase no está configurado).
/// No valida contraseñas: el identificador se deriva del correo para usar las empresas de prueba
/// del servidor (constructora@demo.pe, eventos@demo.pe, taller@demo.pe). Solo para desarrollo.
class AuthDemo implements AuthRepository {
  AuthDemo(this._local) {
    final uid = _local.leerAjuste(_claveUid);
    _sesion = Observable<Sesion?>(
      (uid == null || uid.trim().isEmpty) ? null : Sesion(uid: uid, email: _local.leerAjuste(_claveEmail), esDemo: true),
    );
  }

  final AlmacenLocal _local;
  late final Observable<Sesion?> _sesion;

  static const String _claveUid = 'demo_uid';
  static const String _claveEmail = 'demo_email';
  static const String sinCorreos = 'En el modo demostración no se envían correos.';

  static String uidDesdeEmail(String email) {
    var local = email.trim().toLowerCase().split('@').first.replaceAll(RegExp(r'[^a-z0-9-]'), '-');
    local = local.replaceAll(RegExp(r'^-+|-+$'), '');
    if (local.length > 40) local = local.substring(0, 40);
    if (local.trim().isEmpty) local = 'usuario';
    return 'demo-$local';
  }

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
    final correo = email.trim().toLowerCase();
    final sesion = Sesion(uid: uidDesdeEmail(correo), email: correo, esDemo: true);
    await _local.guardarAjuste(_claveUid, sesion.uid);
    await _local.guardarAjuste(_claveEmail, sesion.email);
    _sesion.valor = sesion;
    return Exito<Sesion>(sesion);
  }

  @override
  Future<Resultado<Sesion>> registrar(String email, String password) => iniciarSesion(email, password);

  @override
  Future<void> cerrarSesion() async {
    await _local.guardarAjuste(_claveUid, null);
    await _local.guardarAjuste(_claveEmail, null);
    _sesion.valor = null;
  }

  @override
  Future<String?> tokenParaApi() async {
    final s = _sesion.valor;
    return s == null ? null : 'demo:${s.uid}';
  }

  // En el modo demostración no hay un proveedor real: no se envían correos ni hay contraseñas guardadas.
  @override
  Future<Resultado<void>> enviarVerificacion() async => const Exito<void>(null);

  @override
  Future<Resultado<bool>> revisarVerificacion() async => const Exito<bool>(true);

  @override
  Future<Resultado<void>> recuperarContrasena(String email) async =>
      Fallo<void>(ErrorApp(TipoError.validacion, mensaje: sinCorreos));

  @override
  Future<Resultado<void>> confirmarContrasena(String password) async => const Exito<void>(null);

  @override
  Future<Resultado<void>> cambiarContrasena(String actual, String nueva) async =>
      Fallo<void>(ErrorApp(TipoError.validacion, mensaje: 'En el modo demostración no se guardan contraseñas.'));

  @override
  Future<Resultado<void>> eliminarUsuario() async {
    await cerrarSesion();
    return const Exito<void>(null);
  }
}
