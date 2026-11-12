import 'config.dart';
import 'data/almacen_local.dart';
import 'data/autenticacion.dart';
import 'data/cliente_api.dart';
import 'data/favoritos.dart';
import 'data/repositorios_api.dart';
import 'data/servicios_web.dart' if (dart.library.io) 'data/servicios_movil.dart';
import 'data/sistema.dart';
import 'domain/repositorios.dart';

/// Inyección de dependencias manual: un único lugar donde se crean los repositorios.
/// Si Firebase está configurado se usa Firebase; si no, el modo demostración.
/// Las pantallas solo conocen las clases abstractas, así las pruebas pueden usar versiones falsas.
class Contenedor {
  Contenedor({
    required this.auth,
    required this.equipos,
    required this.reservas,
    required this.empresas,
    required this.favoritos,
    required this.ajustes,
    required this.red,
    required this.ubicacion,
    required this.limpiarDatosDeSesion,
    this.analizadorFoto = const AnalizadorFotoNinguno(),
    this.lectorTexto = const LectorTextoFotoNinguno(),
    this.buscadorDirecciones = const BuscadorDireccionesNinguno(),
    this.firebaseActivo = false,
    this.mapasActivos = Config.mapasActivos,
    DateTime Function()? reloj,
  }) : reloj = reloj ?? DateTime.now;

  final AuthRepository auth;
  final EquipoRepository equipos;
  final ReservaRepository reservas;
  final EmpresaRepository empresas;
  final FavoritosRepository favoritos;
  final AjustesRepository ajustes;
  final MonitorRed red;
  final ProveedorUbicacion ubicacion;

  /// IA del teléfono que revisa la foto del equipo (ML Kit, funciona sin internet y en ambos modos).
  final AnalizadorFoto analizadorFoto;

  /// IA del teléfono que lee el texto de la ficha RUC (ML Kit, funciona sin internet).
  final LectorTextoFoto lectorTexto;

  /// Convierte la dirección escrita al publicar en un punto del mapa.
  final BuscadorDirecciones buscadorDirecciones;

  /// Borra la caché local de datos privados al cerrar sesión (privacidad en equipos compartidos).
  final Future<void> Function() limpiarDatosDeSesion;

  final bool firebaseActivo;
  final bool mapasActivos;
  final DateTime Function() reloj;

  static Future<Contenedor> crear({required bool firebaseActivo, bool mapasActivos = Config.mapasActivos}) async {
    final almacen = await AlmacenLocal.abrir();

    late final ClienteApi api;
    final ajustes = AjustesRepositoryLocal(almacen, probador: (url) => api.salud(url));
    final AuthRepository auth = firebaseActivo ? AuthFirebase() : AuthDemo(almacen);

    api = ClienteApi(urlBase: () => ajustes.urlServidor, token: auth.tokenParaApi);

    final equipos = EquipoRepositoryApi(api, almacen);
    final reservas = ReservaRepositoryApi(api, almacen);

    return Contenedor(
      auth: auth,
      equipos: equipos,
      reservas: reservas,
      empresas: EmpresaRepositoryApi(api),
      favoritos: firebaseActivo ? FavoritosFirestore(auth) : FavoritosMemoria(),
      ajustes: ajustes,
      red: MonitorRedDispositivo(),
      ubicacion: UbicacionGeolocator(),
      analizadorFoto: crearAnalizadorFoto(),
      lectorTexto: crearLectorTexto(),
      buscadorDirecciones: crearBuscadorDirecciones(),
      limpiarDatosDeSesion: () async {
        await reservas.limpiar();
        await equipos.limpiarPropios();
      },
      firebaseActivo: firebaseActivo,
      mapasActivos: mapasActivos,
    );
  }
}
