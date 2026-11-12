import 'dart:async';

import '../../domain/modelos.dart';
import '../../domain/repositorios.dart';
import '../../domain/resultado.dart';
import '../modelo_vista.dart';

/// MVVM: combina el catálogo guardado en el teléfono, los favoritos de Firestore y el estado de la red
/// en un estado que la pantalla solo dibuja.
class CatalogoViewModel extends ModeloVista {
  CatalogoViewModel({
    required EquipoRepository equipos,
    required FavoritosRepository favoritos,
    required MonitorRed red,
    required ProveedorUbicacion ubicacion,
    required AjustesRepository ajustes,
  })  : _equipos = equipos,
        _favoritos = favoritos,
        _ubicacion = ubicacion,
        _ajustes = ajustes {
    categoria = ajustes.categoriaFiltro;
    enLinea = red.enLineaActual;
    _suscripciones.add(equipos.observarCatalogo().listen((lista) {
      this.equipos = lista;
      avisar();
    }));
    _suscripciones.add(favoritos.observar().listen((ids) {
      this.favoritos = ids;
      avisar();
    }));
    _suscripciones.add(red.enLinea.listen((valor) {
      final antes = enLinea;
      enLinea = valor;
      avisar();
      // Al recuperar la conexión se actualiza automáticamente.
      if (!antes && valor) recargar();
    }));
    _programarRefresco();
  }

  static const double radioCercaniaKm = 15.0;
  static const Duration esperaBusqueda = Duration(milliseconds: 400);

  final EquipoRepository _equipos;
  final FavoritosRepository _favoritos;
  final ProveedorUbicacion _ubicacion;
  final AjustesRepository _ajustes;
  final List<StreamSubscription<Object?>> _suscripciones = [];
  Timer? _espera;
  int _peticion = 0;

  List<Equipo> equipos = [];
  Set<String> favoritos = {};
  bool enLinea = true;
  bool cargando = true;
  ErrorApp? error;
  String? mensaje;

  String texto = '';
  Categoria? categoria;
  bool cercaDeMi = false;
  Coordenadas? ubicacion;
  bool obteniendoUbicacion = false;

  /// Primera carga sin datos guardados.
  bool get mostrarCargaInicial => cargando && equipos.isEmpty;
  bool get mostrarErrorPantalla => error != null && equipos.isEmpty && !cargando;
  bool get mostrarVacio => !cargando && error == null && equipos.isEmpty;

  /// Cada cambio de filtros vuelve a consultar la API (la búsqueda espera 400 ms sin escribir).
  void _programarRefresco() {
    _espera?.cancel();
    _espera = Timer(esperaBusqueda, recargar);
  }

  void alCambiarTexto(String valor) {
    texto = valor;
    avisar();
    _programarRefresco();
  }

  void alElegirCategoria(Categoria? valor) {
    categoria = valor;
    avisar();
    _ajustes.guardarCategoriaFiltro(valor);
    _programarRefresco();
  }

  Future<void> alCambiarCercaDeMi(bool activar) async {
    if (!activar) {
      cercaDeMi = false;
      ubicacion = null;
      avisar();
      _programarRefresco();
      return;
    }
    obteniendoUbicacion = true;
    avisar();
    final c = await _ubicacion.ubicacionActual();
    if (cerrado) return;
    obteniendoUbicacion = false;
    if (c == null) {
      mensaje = 'No se pudo obtener tu ubicación. Revisa el permiso y el GPS.';
    } else {
      cercaDeMi = true;
      ubicacion = c;
      _programarRefresco();
    }
    avisar();
  }

  Future<void> recargar() async {
    _espera?.cancel();
    final numero = ++_peticion;
    cargando = true;
    avisar();
    final r = await _equipos.refrescarCatalogo(
      FiltroCatalogo(
        texto: texto,
        categoria: categoria,
        ubicacion: cercaDeMi ? ubicacion : null,
        radioKm: cercaDeMi ? radioCercaniaKm : null,
      ),
    );
    // Si mientras tanto se hizo otra búsqueda, este resultado ya no sirve.
    if (cerrado || numero != _peticion) return;
    cargando = false;
    final e = r.errorONull;
    error = e;
    if (e != null && equipos.isNotEmpty) mensaje = '${e.mensaje} Se muestran los datos guardados.';
    avisar();
  }

  void alternarFavorito(Equipo equipo) {
    _favoritos.establecer(equipo, !favoritos.contains(equipo.id));
  }

  void mensajeMostrado() {
    mensaje = null;
  }

  @override
  void dispose() {
    _espera?.cancel();
    for (final s in _suscripciones) {
      s.cancel();
    }
    super.dispose();
  }
}
