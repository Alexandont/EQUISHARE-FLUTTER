import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/modelos.dart';
import '../domain/repositorios.dart';

/// Ubicación con el paquete geolocator (Fused Location en Android y la API del navegador en web).
/// Precisión media (de cuadra): suficiente para ordenar por cercanía y con menor consumo de batería.
/// Igual que Kotlin: espera la posición actual hasta 10 segundos y, si no llega, usa la última conocida.
/// La ubicación solo se envía como parámetro de búsqueda y no se almacena.
class UbicacionGeolocator implements ProveedorUbicacion {
  static bool _concedido(LocationPermission p) =>
      p == LocationPermission.always || p == LocationPermission.whileInUse;

  @override
  Future<bool> tienePermiso() async {
    try {
      return _concedido(await Geolocator.checkPermission());
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Coordenadas?> ubicacionActual() async {
    try {
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) permiso = await Geolocator.requestPermission();
      if (!_concedido(permiso)) return null;
    } catch (_) {
      return null;
    }
    try {
      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 10),
        ),
      );
      return Coordenadas(posicion.latitude, posicion.longitude);
    } catch (_) {
      if (kIsWeb) return null;
      try {
        final ultima = await Geolocator.getLastKnownPosition();
        return ultima == null ? null : Coordenadas(ultima.latitude, ultima.longitude);
      } catch (_) {
        return null;
      }
    }
  }
}

/// Observa la red del teléfono (como ConnectivityManager en Kotlin) para mostrar el aviso "Sin conexión".
class MonitorRedDispositivo implements MonitorRed {
  MonitorRedDispositivo([Connectivity? conectividad]) : _conectividad = conectividad ?? Connectivity() {
    _conectividad.checkConnectivity().then(_actualizar, onError: (Object _) {});
    _conectividad.onConnectivityChanged.listen(_actualizar, onError: (Object _) {});
  }

  final Connectivity _conectividad;
  final Observable<bool> _estado = Observable<bool>(true);

  static bool _hayRed(List<ConnectivityResult> tipos) => tipos.any((t) => t != ConnectivityResult.none);

  void _actualizar(List<ConnectivityResult> tipos) {
    final enLinea = _hayRed(tipos);
    if (enLinea != _estado.valor) _estado.valor = enLinea;
  }

  @override
  bool get enLineaActual => _estado.valor;

  @override
  Stream<bool> get enLinea => _estado.stream.distinct();
}
