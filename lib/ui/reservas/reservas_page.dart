import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../contenedor.dart';
import '../../domain/formato.dart';
import '../../domain/modelos.dart';
import '../../domain/reglas_negocio.dart';
import '../../domain/repositorios.dart';
import '../../domain/resultado.dart';
import '../../domain/validadores.dart';
import '../componentes.dart';
import '../modelo_vista.dart';

class ReservasViewModel extends ModeloVista {
  ReservasViewModel(this._reservas, MonitorRed red, this._reloj) {
    enLinea = red.enLineaActual;
    _suscripcionRed = red.enLinea.listen((v) {
      enLinea = v;
      avisar();
    });
    _observar();
    recargar();
  }

  final ReservaRepository _reservas;
  final DateTime Function() _reloj;
  late final StreamSubscription<bool> _suscripcionRed;
  StreamSubscription<List<Reserva>>? _suscripcionLista;

  Rol rol = Rol.arrendatario;
  List<Reserva> reservas = [];
  bool cargando = true;
  ErrorApp? error;
  bool enLinea = true;
  String? mensaje;
  String? procesandoId;

  void _observar() {
    _suscripcionLista?.cancel();
    _suscripcionLista = _reservas.observarMias(rol).listen((lista) {
      reservas = lista;
      avisar();
    });
  }

  void cambiarRol(Rol nuevo) {
    if (nuevo == rol) return;
    rol = nuevo;
    reservas = [];
    avisar();
    _observar();
    recargar();
  }

  Future<void> recargar() async {
    final rolPedido = rol;
    cargando = true;
    error = null;
    avisar();
    final r = await _reservas.refrescarMias(rolPedido);
    if (cerrado || rolPedido != rol) return;
    cargando = false;
    error = r.errorONull;
    avisar();
  }

  /// Penalidad que se cobraría si se cancela ahora, para avisar antes de confirmar.
  double penalidadSiCancela(Reserva reserva) {
    final inicio = Fechas.desdeIsoONull(reserva.fechaInicio);
    if (inicio == null) return 0;
    return ReglasNegocio.penalidadSiCancela(inicio, reserva.total, _reloj());
  }

  bool puedeCalificar(Reserva reserva) {
    final texto = reserva.devueltaEn;
    final devuelta = texto == null ? null : DateTime.tryParse(texto);
    return reserva.estado == EstadoReserva.devuelta &&
        !reserva.resenaEnviada &&
        ReglasNegocio.dentroDeVentanaResena(devuelta, _reloj());
  }

  void cancelar(Reserva reserva) =>
      _ejecutar(reserva.id, 'Reserva cancelada.', () => _reservas.cancelar(reserva.id));

  void avanzarEstado(Reserva reserva) {
    final siguiente = reserva.estado.siguienteParaArrendador;
    if (siguiente == null) return;
    _ejecutar(
      reserva.id,
      'Reserva actualizada a "${siguiente.etiqueta}".',
      () => _reservas.cambiarEstado(reserva.id, siguiente),
    );
  }

  void calificar(Reserva reserva, int estrellas, String comentario) => _ejecutar(
        reserva.id,
        '¡Gracias! Tu calificación fue registrada.',
        () => _reservas.calificar(reserva.id, estrellas, comentario),
      );

  Future<void> _ejecutar<T>(String id, String textoExito, Future<Resultado<T>> Function() accion) async {
    if (procesandoId != null) return;
    procesandoId = id;
    avisar();
    final r = await accion();
    if (cerrado) return;
    procesandoId = null;
    mensaje = r.errorONull?.mensaje ?? textoExito;
    avisar();
  }

  void mensajeMostrado() {
    mensaje = null;
  }

  @override
  void dispose() {
    _suscripcionRed.cancel();
    _suscripcionLista?.cancel();
    super.dispose();
  }
}

class ReservasPage extends StatefulWidget {
  const ReservasPage({super.key});

  @override
  State<ReservasPage> createState() => _ReservasPageState();
}

class _ReservasPageState extends State<ReservasPage> {
  late final ReservasViewModel vm;

  @override
  void initState() {
    super.initState();
    final c = context.read<Contenedor>();
    vm = ReservasViewModel(c.reservas, c.red, c.reloj);
    vm.addListener(_alCambiar);
  }

  void _alCambiar() {
    final texto = vm.mensaje;
    if (texto != null && mounted) {
      vm.mensajeMostrado();
      mostrarMensaje(context, texto);
    }
  }

  @override
  void dispose() {
    vm.removeListener(_alCambiar);
    vm.dispose();
    super.dispose();
  }

  Future<void> _confirmarCancelacion(Reserva reserva) async {
    final penalidad = vm.penalidadSiCancela(reserva);
    final si = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Cancelar la reserva?'),
        content: Text(
          penalidad > 0
              ? 'Faltan menos de 12 horas para la entrega: se aplicará una penalidad de ${Formato.soles(penalidad)} (20 %).'
              : 'Aún estás a tiempo: la cancelación no tiene costo.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(contexto).pop(false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.of(contexto).pop(true), child: const Text('Sí, cancelar')),
        ],
      ),
    );
    if (si == true) vm.cancelar(reserva);
  }

  Future<void> _calificar(Reserva reserva) async {
    final titulo = reserva.rolSolicitante == Rol.arrendatario
        ? 'Califica el equipo y a ${reserva.arrendadorNombre}'
        : 'Califica a ${reserva.arrendatarioNombre}';
    final resultado = await showDialog<_Calificacion>(
      context: context,
      builder: (_) => _DialogoCalificar(titulo: titulo),
    );
    if (resultado != null) vm.calificar(reserva, resultado.estrellas, resultado.comentario);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservas'),
        actions: [IconButton(tooltip: 'Actualizar', icon: const Icon(Icons.refresh), onPressed: vm.recargar)],
      ),
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: SegmentedButton<Rol>(
                segments: const [
                  ButtonSegment(value: Rol.arrendatario, label: Text('Lo que alquilo')),
                  ButtonSegment(value: Rol.arrendador, label: Text('Mis equipos alquilados')),
                ],
                selected: {vm.rol},
                onSelectionChanged: (seleccion) => vm.cambiarRol(seleccion.first),
              ),
            ),
            BannerSinConexion(visible: !vm.enLinea),
            if (vm.cargando && vm.reservas.isNotEmpty) const LinearProgressIndicator(),
            Expanded(child: _contenido()),
          ],
        ),
      ),
    );
  }

  Widget _contenido() {
    if (vm.cargando && vm.reservas.isEmpty) return const EstadoCargando();
    if (vm.error != null && vm.reservas.isEmpty) {
      return EstadoError(mensaje: vm.error!.mensaje, alReintentar: vm.recargar);
    }
    if (vm.reservas.isEmpty) {
      return EstadoVacio(
        titulo: 'Sin reservas',
        detalle: vm.rol == Rol.arrendatario
            ? 'Cuando reserves un equipo aparecerá aquí.'
            : 'Cuando otra empresa reserve tus equipos aparecerá aquí.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: vm.reservas.length,
      separatorBuilder: (context, indice) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final reserva = vm.reservas[i];
        return _TarjetaReserva(
          key: ValueKey(reserva.id),
          reserva: reserva,
          procesando: vm.procesandoId == reserva.id,
          puedeCalificar: vm.puedeCalificar(reserva),
          alCancelar: () => _confirmarCancelacion(reserva),
          alAvanzar: () => vm.avanzarEstado(reserva),
          alCalificar: () => _calificar(reserva),
        );
      },
    );
  }
}

class _TarjetaReserva extends StatelessWidget {
  const _TarjetaReserva({
    super.key,
    required this.reserva,
    required this.procesando,
    required this.puedeCalificar,
    required this.alCancelar,
    required this.alAvanzar,
    required this.alCalificar,
  });

  final Reserva reserva;
  final bool procesando;
  final bool puedeCalificar;
  final VoidCallback alCancelar;
  final VoidCallback alAvanzar;
  final VoidCallback alCalificar;

  static String _textoBoton(EstadoReserva siguiente) => switch (siguiente) {
        EstadoReserva.confirmada => 'Confirmar',
        EstadoReserva.enCurso => 'Marcar entregado',
        EstadoReserva.devuelta => 'Marcar devuelto',
        _ => siguiente.etiqueta,
      };

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final siguiente = reserva.estado.siguienteParaArrendador;
    final esArrendador = reserva.rolSolicitante == Rol.arrendador;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    reserva.equipoNombre,
                    style: tema.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                EtiquetaEstadoReserva(estado: reserva.estado),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              esArrendador ? 'Cliente: ${reserva.arrendatarioNombre}' : 'Arrendador: ${reserva.arrendadorNombre}',
              style: tema.textTheme.bodySmall,
            ),
            Text('${Formato.rango(reserva.fechaInicio, reserva.fechaFin)} · ${reserva.dias} día(s)'),
            if (esArrendador)
              Text(
                'Total ${Formato.soles(reserva.total)} · Comisión 12 %: ${Formato.soles(reserva.comision)} · '
                'Recibes ${Formato.soles(reserva.montoArrendador)}',
                style: tema.textTheme.bodySmall,
              )
            else
              Text('Total: ${Formato.soles(reserva.total)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (reserva.penalidad > 0)
              Text(
                'Penalidad por cancelación tardía: ${Formato.soles(reserva.penalidad)}',
                style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.error),
              ),
            if (procesando) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (esArrendador && siguiente != null)
                  FilledButton(onPressed: procesando ? null : alAvanzar, child: Text(_textoBoton(siguiente))),
                if (reserva.estado.esCancelable)
                  OutlinedButton(onPressed: procesando ? null : alCancelar, child: const Text('Cancelar')),
                if (puedeCalificar)
                  FilledButton(onPressed: procesando ? null : alCalificar, child: const Text('Calificar')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Calificacion {
  const _Calificacion(this.estrellas, this.comentario);
  final int estrellas;
  final String comentario;
}

class _DialogoCalificar extends StatefulWidget {
  const _DialogoCalificar({required this.titulo});

  final String titulo;

  @override
  State<_DialogoCalificar> createState() => _DialogoCalificarState();
}

class _DialogoCalificarState extends State<_DialogoCalificar> {
  int _estrellas = 0;
  String _comentario = '';
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tienes 48 horas después de la devolución para calificar.', style: Theme.of(context).textTheme.bodySmall),
            SelectorEstrellas(
              valor: _estrellas,
              alCambiar: (v) => setState(() {
                _estrellas = v;
                _error = null;
              }),
            ),
            TextField(
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(labelText: 'Comentario', errorText: _error),
              onChanged: (v) => setState(() {
                _comentario = v;
                _error = null;
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        TextButton(
          onPressed: () {
            final problema = Validadores.estrellas(_estrellas) ?? Validadores.comentario(_comentario);
            if (problema != null) {
              setState(() => _error = problema);
            } else {
              Navigator.of(context).pop(_Calificacion(_estrellas, _comentario));
            }
          },
          child: const Text('Enviar'),
        ),
      ],
    );
  }
}
