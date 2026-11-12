import 'dart:async';
import 'dart:typed_data';

import 'ia/clasificador_equipo.dart';
import 'mapa/agrupador.dart';
import 'modelos.dart';
import 'resultado.dart';

/*
 * Contratos del patrón Repository. Los ViewModel dependen de estas clases abstractas y no de
 * http, Hive o Firebase; así cada capa se puede probar por separado con implementaciones falsas.
 */

/// Valor observable: guarda el último valor y avisa los cambios (equivale a StateFlow de Kotlin).
class Observable<T> {
  Observable(this._valor);

  T _valor;
  final StreamController<T> _cambios = StreamController<T>.broadcast();

  T get valor => _valor;

  set valor(T nuevo) {
    _valor = nuevo;
    if (!_cambios.isClosed) _cambios.add(nuevo);
  }

  /// Emite primero el valor actual y luego cada cambio.
  Stream<T> get stream {
    late StreamController<T> salida;
    StreamSubscription<T>? sub;
    salida = StreamController<T>(
      onListen: () {
        salida.add(_valor);
        sub = _cambios.stream.listen(salida.add);
      },
      onCancel: () => sub?.cancel(),
    );
    return salida.stream;
  }

  void cerrar() => _cambios.close();
}

abstract class EquipoRepository {
  /// Catálogo guardado en el teléfono (fuente única de verdad para la UI, funciona sin conexión).
  Stream<List<Equipo>> observarCatalogo();
  Future<Resultado<void>> refrescarCatalogo(FiltroCatalogo filtro);
  Stream<List<Equipo>> observarPropios();
  Future<Resultado<void>> refrescarPropios();
  Future<Resultado<Equipo>> obtener(String id);
  Future<Resultado<Equipo>> crear(EquipoEntrada entrada);
  Future<Resultado<Equipo>> actualizar(String id, EquipoEntrada entrada);
  Future<Resultado<void>> eliminar(String id);
  Future<Resultado<FotoSubida>> subirFoto(Uint8List bytes, String nombreArchivo);
  Future<Resultado<List<RangoOcupado>>> disponibilidad(String id);
  Future<Resultado<List<Resena>>> resenas(String id);
}

abstract class ReservaRepository {
  Stream<List<Reserva>> observarMias(Rol rol);
  Future<Resultado<void>> refrescarMias(Rol rol);
  Future<Resultado<Cotizacion>> cotizar(String equipoId, String inicio, String fin);
  Future<Resultado<Reserva>> crear(String equipoId, String inicio, String fin);
  Future<Resultado<Reserva>> cancelar(String id);
  Future<Resultado<Reserva>> cambiarEstado(String id, EstadoReserva estado);
  Future<Resultado<void>> calificar(String id, int estrellas, String comentario);
}

abstract class EmpresaRepository {
  /// Devuelve Exito(null) si la empresa aún no completó su registro (HTTP 404 de la API).
  Future<Resultado<Empresa?>> miEmpresa();
  Future<Resultado<Empresa>> guardar(String ruc, String razonSocial, String telefono);

  /// Borra la empresa y sus equipos en el servidor (derecho de cancelación). Falla si hay reservas activas.
  Future<Resultado<void>> eliminarMiCuenta();

  /// Números del panel: equipos, reservas e ingresos estimados.
  Future<Resultado<MetricasEmpresa>> metricas();
}

abstract class AuthRepository {
  Sesion? get sesionActual;

  /// true cuando ya se sabe si hay una sesión guardada (evita mostrar el login por un instante).
  bool get sesionCargada;

  /// Avisa cada vez que cambia la sesión o termina de cargarse.
  Stream<Sesion?> get cambios;

  bool get esModoDemo;
  Future<Resultado<Sesion>> iniciarSesion(String email, String password);
  Future<Resultado<Sesion>> registrar(String email, String password);
  Future<void> cerrarSesion();

  /// Token para la cabecera Authorization de la API.
  Future<String?> tokenParaApi();

  /// Envía (o vuelve a enviar) el correo con el enlace para verificar la cuenta.
  Future<Resultado<void>> enviarVerificacion();

  /// Pregunta otra vez si el correo ya se verificó; si es así, actualiza la sesión. Devuelve si está verificado.
  Future<Resultado<bool>> revisarVerificacion();

  /// Envía el correo para crear una contraseña nueva.
  Future<Resultado<void>> recuperarContrasena(String email);

  /// Confirma la identidad con la contraseña actual (se pide antes de borrar la cuenta).
  Future<Resultado<void>> confirmarContrasena(String password);

  /// Cambia la contraseña después de confirmar la actual.
  Future<Resultado<void>> cambiarContrasena(String actual, String nueva);

  /// Borra el usuario del proveedor de inicio de sesión y cierra la sesión. Es lo último al eliminar la cuenta.
  Future<Resultado<void>> eliminarUsuario();
}

abstract class FavoritosRepository {
  Stream<Set<String>> observar();
  Future<Resultado<void>> establecer(Equipo equipo, bool favorito);

  /// Registra el consentimiento de privacidad del usuario (Ley N.° 29733).
  Future<Resultado<void>> registrarConsentimiento(String? email);

  /// Borra los favoritos y el consentimiento guardados del usuario (al eliminar la cuenta).
  Future<Resultado<void>> borrarMisDatos();
}

abstract class AjustesRepository {
  String get urlServidor;
  Categoria? get categoriaFiltro;
  Future<void> guardarUrlServidor(String url);
  Future<void> guardarCategoriaFiltro(Categoria? categoria);

  /// Prueba la dirección y devuelve el modo de autenticación del servidor.
  Future<Resultado<String>> probarServidor(String url);

  /// true después de ver las pantallas de bienvenida una vez.
  bool get bienvenidaVista;
  Future<void> marcarBienvenidaVista();

  /// Capa del mapa elegida la última vez.
  TipoMapa get tipoMapa;
  Future<void> guardarTipoMapa(TipoMapa tipo);
}

abstract class MonitorRed {
  bool get enLineaActual;
  Stream<bool> get enLinea;
}

abstract class ProveedorUbicacion {
  Future<bool> tienePermiso();

  /// Pide el permiso si hace falta y devuelve la posición, o null si no se pudo.
  Future<Coordenadas?> ubicacionActual();
}

/// IA en el teléfono: mira la foto (sin internet) y dice qué ve.
/// Devuelve null si no se pudo revisar; nunca lanza excepciones a la interfaz.
abstract class AnalizadorFoto {
  Future<List<EtiquetaFoto>?> etiquetar(String rutaFoto);
}

/// IA en el teléfono que lee el texto de una foto (por ejemplo, la ficha RUC), sin internet.
/// Devuelve null si no se pudo leer; nunca lanza excepciones a la interfaz.
abstract class LectorTextoFoto {
  Future<String?> leerTexto(String rutaFoto);
}

/// Convierte una dirección escrita en coordenadas (para ubicar el equipo al publicar).
abstract class BuscadorDirecciones {
  /// Devuelve null si no encontró la dirección o no hay servicio de búsqueda.
  Future<Coordenadas?> buscar(String direccion);
}

/// IA vacía para pruebas o donde ML Kit no existe (la web): nunca sugiere nada.
class AnalizadorFotoNinguno implements AnalizadorFoto {
  const AnalizadorFotoNinguno();

  @override
  Future<List<EtiquetaFoto>?> etiquetar(String rutaFoto) async => null;
}

/// Lector vacío para pruebas o donde ML Kit no existe (la web): nunca lee texto.
class LectorTextoFotoNinguno implements LectorTextoFoto {
  const LectorTextoFotoNinguno();

  @override
  Future<String?> leerTexto(String rutaFoto) async => null;
}

/// Buscador vacío para pruebas o teléfonos sin servicio de direcciones (BuscadorDirecciones.NINGUNO en Kotlin).
class BuscadorDireccionesNinguno implements BuscadorDirecciones {
  const BuscadorDireccionesNinguno();

  @override
  Future<Coordenadas?> buscar(String direccion) async => null;
}
