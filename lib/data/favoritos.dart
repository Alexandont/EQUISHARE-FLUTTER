import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/modelos.dart';
import '../domain/repositorios.dart';
import '../domain/resultado.dart';

/// Favoritos y consentimiento de privacidad en Cloud Firestore:
///   usuarios/{uid}                       -> correo y consentimiento (versión y fecha)
///   usuarios/{uid}/favoritos/{equipoId}  -> nombre, categoría y fecha
/// Las reglas de seguridad (firestore.rules) solo permiten que cada usuario lea y escriba lo suyo.
/// Firestore guarda los cambios sin conexión y los sincroniza al volver la red.
class FavoritosFirestore implements FavoritosRepository {
  FavoritosFirestore(this._auth, [FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance {
    _seguir(_auth.sesionActual?.uid);
    _auth.cambios.listen((sesion) => _seguir(sesion?.uid));
  }

  final AuthRepository _auth;
  final FirebaseFirestore _db;
  final Observable<Set<String>> _ids = Observable<Set<String>>(<String>{});
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _suscripcion;
  String? _uidActual;
  bool _iniciado = false;

  static const String _usuarios = 'usuarios';
  static const String _favoritos = 'favoritos';
  static const String _versionPolitica = '1.0-2026';

  void _seguir(String? uid) {
    if (_iniciado && uid == _uidActual) return;
    _iniciado = true;
    _uidActual = uid;
    _suscripcion?.cancel();
    _suscripcion = null;
    if (uid == null) {
      _ids.valor = <String>{};
      return;
    }
    _suscripcion = _db.collection(_usuarios).doc(uid).collection(_favoritos).snapshots().listen(
          (instantanea) {
            _ids.valor = instantanea.docs.map((d) => d.id).toSet();
          },
          onError: (Object error) {
            _ids.valor = <String>{};
          },
        );
  }

  @override
  Stream<Set<String>> observar() => _ids.stream;

  @override
  Future<Resultado<void>> establecer(Equipo equipo, bool favorito) async {
    final uid = _auth.sesionActual?.uid;
    if (uid == null) return Fallo<void>(ErrorApp(TipoError.noAutenticado));
    final referencia = _db.collection(_usuarios).doc(uid).collection(_favoritos).doc(equipo.id);
    // No se espera la confirmación del servidor: Firestore aplica el cambio localmente al instante.
    if (favorito) {
      _ids.valor = {..._ids.valor, equipo.id};
      referencia.set({
        'nombre': equipo.nombre,
        'categoria': equipo.categoria.codigo,
        'agregadoEn': FieldValue.serverTimestamp(),
      }).ignore();
    } else {
      _ids.valor = {..._ids.valor}..remove(equipo.id);
      referencia.delete().ignore();
    }
    return const Exito<void>(null);
  }

  @override
  Future<Resultado<void>> registrarConsentimiento(String? email) async {
    final uid = _auth.sesionActual?.uid;
    if (uid == null) return Fallo<void>(ErrorApp(TipoError.noAutenticado));
    _db.collection(_usuarios).doc(uid).set({
      'email': email,
      'consentimientoPrivacidad': {
        'version': _versionPolitica,
        'aceptadoEn': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true)).ignore();
    return const Exito<void>(null);
  }

  @override
  Future<Resultado<void>> borrarMisDatos() async {
    final uid = _auth.sesionActual?.uid;
    if (uid == null) return Fallo<void>(ErrorApp(TipoError.noAutenticado));
    Future<void> borrar() async {
      final usuario = _db.collection(_usuarios).doc(uid);
      final favoritos = await usuario.collection(_favoritos).get();
      for (final documento in favoritos.docs) {
        await documento.reference.delete();
      }
      await usuario.delete();
    }

    try {
      // Se espera la confirmación del servidor: si no hay internet, se avisa en lugar de dejar datos sueltos.
      await borrar().timeout(const Duration(seconds: 20));
      return const Exito<void>(null);
    } on TimeoutException {
      return Fallo<void>(ErrorApp(TipoError.sinConexion,
          mensaje: 'No se pudieron borrar tus favoritos. Revisa tu internet e inténtalo de nuevo.'));
    } catch (_) {
      return Fallo<void>(
          ErrorApp(TipoError.desconocido, mensaje: 'No se pudieron borrar tus favoritos. Inténtalo de nuevo.'));
    }
  }
}

/// Implementación en memoria para el modo demostración (sin Firebase).
class FavoritosMemoria implements FavoritosRepository {
  final Observable<Set<String>> _ids = Observable<Set<String>>(<String>{});

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
    _ids.valor = <String>{};
    return const Exito<void>(null);
  }
}
