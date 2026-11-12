import 'dart:async';

import '../../domain/modelos.dart';
import '../../domain/reglas_negocio.dart';
import '../../domain/repositorios.dart';
import '../../domain/resultado.dart';
import '../modelo_vista.dart';

class DetalleViewModel extends ModeloVista {
  DetalleViewModel({
    required this.equipoId,
    required EquipoRepository equipos,
    required ReservaRepository reservas,
    required FavoritosRepository favoritos,
    required AuthRepository auth,
    required DateTime Function() reloj,
  })  : _equipos = equipos,
        _reservas = reservas,
        _favoritos = favoritos,
        _auth = auth,
        _reloj = reloj {
    _suscripcion = favoritos.observar().listen((ids) {
      esFavorito = ids.contains(equipoId);
      avisar();
    });
    cargar();
  }

  final String equipoId;
  final EquipoRepository _equipos;
  final ReservaRepository _reservas;
  final FavoritosRepository _favoritos;
  final AuthRepository _auth;
  final DateTime Function() _reloj;
  late final StreamSubscription<Set<String>> _suscripcion;

  bool cargando = true;
  ErrorApp? error;
  Equipo? equipo;
  List<Resena> resenas = [];
  List<RangoOcupado> ocupados = [];
  bool esFavorito = false;
  bool esPropio = false;
  DateTime? seleccionInicio;
  DateTime? seleccionFin;
  Cotizacion? cotizacion;
  String? errorSeleccion;
  bool cotizando = false;
  bool reservando = false;
  String? mensaje;

  Future<void> cargar() async {
    cargando = true;
    error = null;
    avisar();
    final disponibilidad = _equipos.disponibilidad(equipoId);
    final listaResenas = _equipos.resenas(equipoId);
    final r = await _equipos.obtener(equipoId);
    final rDisponibilidad = await disponibilidad;
    final rResenas = await listaResenas;
    if (cerrado) return;
    cargando = false;
    if (r is Exito<Equipo>) {
      equipo = r.datos;
      esPropio = r.datos.empresaId == _auth.sesionActual?.uid;
      ocupados = rDisponibilidad.datosONull ?? [];
      resenas = rResenas.datosONull ?? [];
    } else {
      error = r.errorONull;
    }
    avisar();
  }

  /// Primer día que el calendario deja elegir: hoy en Lima. La anticipación de 24 h (RN-07) se valida
  /// al confirmar el rango, para poder explicar el motivo en lugar de mostrar días bloqueados sin razón.
  DateTime primerDiaSeleccionable() => ReglasNegocio.hoyEnLima(_reloj());

  bool estaOcupado(DateTime dia) => ReglasNegocio.haySolapamiento(ocupados, dia, dia);

  /// Recibe el rango del calendario. Devuelve true si hay una cotización para mostrar.
  bool seleccionarRango(DateTime desde, DateTime hasta) {
    final actual = equipo;
    if (actual == null) return false;
    final inicio = Fechas.soloDia(desde);
    final fin = Fechas.soloDia(hasta);
    final problema = ReglasNegocio.validarRango(inicio, fin, _reloj()) ??
        (ReglasNegocio.haySolapamiento(ocupados, inicio, fin)
            ? 'El rango elegido incluye días ya reservados. Elige otras fechas.'
            : null);
    if (problema != null) {
      seleccionInicio = null;
      seleccionFin = null;
      cotizacion = null;
      errorSeleccion = problema;
      avisar();
      return false;
    }
    // Vista previa inmediata calculada en el teléfono; luego se confirma con el servidor.
    seleccionInicio = inicio;
    seleccionFin = fin;
    cotizacion = ReglasNegocio.cotizar(actual.precioDia, inicio, fin);
    errorSeleccion = null;
    cotizando = true;
    avisar();
    _confirmarCotizacion(inicio, fin);
    return true;
  }

  Future<void> _confirmarCotizacion(DateTime inicio, DateTime fin) async {
    final r = await _reservas.cotizar(equipoId, Fechas.aIso(inicio), Fechas.aIso(fin));
    if (cerrado || seleccionInicio != inicio || seleccionFin != fin) return;
    cotizando = false;
    if (r is Exito<Cotizacion>) {
      if (r.datos.disponible) {
        cotizacion = r.datos;
      } else {
        _descartar('El equipo ya no está disponible en esas fechas.');
      }
    } else {
      _descartar(r.errorONull?.mensaje);
    }
    avisar();
  }

  void _descartar(String? motivo) {
    seleccionInicio = null;
    seleccionFin = null;
    cotizacion = null;
    errorSeleccion = motivo;
  }

  void descartarSeleccion() {
    _descartar(null);
    cotizando = false;
    avisar();
  }

  /// Devuelve true si la reserva se creó.
  Future<bool> confirmarReserva() async {
    final inicio = seleccionInicio;
    final fin = seleccionFin;
    if (inicio == null || fin == null || reservando) return false;
    reservando = true;
    avisar();
    final r = await _reservas.crear(equipoId, Fechas.aIso(inicio), Fechas.aIso(fin));
    if (cerrado) return false;
    reservando = false;
    if (r is Exito<Reserva>) {
      _descartar(null);
      mensaje = 'Reserva enviada. La empresa arrendadora debe confirmarla; puedes verla en Reservas.';
      avisar();
      final nuevos = (await _equipos.disponibilidad(equipoId)).datosONull;
      if (nuevos != null && !cerrado) {
        ocupados = nuevos;
        avisar();
      }
      return true;
    }
    _descartar(r.errorONull?.mensaje);
    avisar();
    return false;
  }

  void alternarFavorito() {
    final actual = equipo;
    if (actual != null) _favoritos.establecer(actual, !esFavorito);
  }

  void mensajeMostrado() {
    mensaje = null;
    errorSeleccion = null;
  }

  @override
  void dispose() {
    _suscripcion.cancel();
    super.dispose();
  }
}
