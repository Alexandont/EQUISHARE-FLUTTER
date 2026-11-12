import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../contenedor.dart';
import '../../domain/formato.dart';
import '../../domain/modelos.dart';
import '../../domain/reglas_negocio.dart';
import '../componentes.dart';
import '../publicar/publicar_page.dart';
import 'detalle_vm.dart';

class DetallePage extends StatefulWidget {
  const DetallePage({super.key, required this.equipoId});

  final String equipoId;

  @override
  State<DetallePage> createState() => _DetallePageState();
}

class _DetallePageState extends State<DetallePage> {
  late final DetalleViewModel vm;
  late final bool _mapasActivos;
  bool _dialogoAbierto = false;

  @override
  void initState() {
    super.initState();
    final c = context.read<Contenedor>();
    _mapasActivos = c.mapasActivos;
    vm = DetalleViewModel(
      equipoId: widget.equipoId,
      equipos: c.equipos,
      reservas: c.reservas,
      favoritos: c.favoritos,
      auth: c.auth,
      reloj: c.reloj,
    );
    vm.addListener(_alCambiar);
  }

  void _alCambiar() {
    if (!mounted) return;
    final texto = vm.mensaje ?? (_dialogoAbierto ? null : vm.errorSeleccion);
    if (texto != null) {
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

  Future<void> _elegirFechas() async {
    final primer = vm.primerDiaSeleccionable();
    final primerDia = DateTime(primer.year, primer.month, primer.day);
    final rango = await showDateRangePicker(
      context: context,
      firstDate: primerDia,
      lastDate: primerDia.add(const Duration(days: 365)),
      helpText: 'Fechas del alquiler',
      saveText: 'Ver costo',
      cancelText: 'Cancelar',
      // Se bloquean los días ya reservados (RN-02). La anticipación de 24 h (RN-07) se comprueba
      // al pulsar «Ver costo» para poder explicar el motivo.
      selectableDayPredicate: (dia, inicio, fin) => !vm.estaOcupado(dia),
    );
    if (rango == null || !mounted) return;
    if (vm.seleccionarRango(rango.start, rango.end)) await _mostrarCotizacion();
  }

  Future<void> _mostrarCotizacion() async {
    _dialogoAbierto = true;
    await showDialog<void>(
      context: context,
      builder: (contexto) => ListenableBuilder(
        listenable: vm,
        builder: (contexto, _) => _DialogoCotizacion(vm: vm),
      ),
    );
    _dialogoAbierto = false;
    if (!mounted) return;
    // Si se cerró tocando afuera, se descarta la selección pendiente.
    if (vm.seleccionInicio != null && !vm.reservando) vm.descartarSeleccion();
    vm.mensajeMostrado();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final equipo = vm.equipo;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Detalle del equipo'),
            actions: [
              if (equipo != null)
                IconButton(
                  tooltip: vm.esFavorito ? 'Quitar de favoritos' : 'Agregar a favoritos',
                  icon: Icon(vm.esFavorito ? Icons.favorite : Icons.favorite_border),
                  onPressed: vm.alternarFavorito,
                ),
            ],
          ),
          bottomNavigationBar: equipo == null ? null : _barraPrecio(equipo),
          body: vm.cargando
              ? const EstadoCargando()
              : equipo == null
                  ? EstadoError(mensaje: vm.error?.mensaje ?? 'No se encontró el equipo.', alReintentar: vm.cargar)
                  : _contenido(equipo),
        );
      },
    );
  }

  Widget _barraPrecio(Equipo equipo) {
    final tema = Theme.of(context);
    return Material(
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Formato.soles(equipo.precioDia),
                      style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text('por día', style: tema.textTheme.bodySmall),
                  ],
                ),
              ),
              if (vm.esPropio)
                FilledButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar equipo'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => PublicarPage(equipoId: equipo.id)),
                  ),
                )
              else
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: tema.colorScheme.secondary),
                  icon: const Icon(Icons.date_range),
                  label: const Text('Elegir fechas'),
                  onPressed: (vm.reservando || vm.cotizando) ? null : _elegirFechas,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contenido(Equipo equipo) {
    final tema = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ImagenEquipo(
          url: equipo.fotoUrl,
          categoria: equipo.categoria,
          descripcion: 'Foto de ${equipo.nombre}',
          alto: 220,
          radio: 16,
        ),
        const SizedBox(height: 12),
        Text(equipo.nombre, style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
        Text('${equipo.categoria.etiqueta} · ${equipo.empresaNombre}', style: tema.textTheme.bodyMedium),
        const SizedBox(height: 4),
        Row(
          children: [
            Estrellas(valor: equipo.calificacionPromedio),
            const SizedBox(width: 8),
            Text(Formato.calificacion(equipo.calificacionPromedio, equipo.totalResenas), style: tema.textTheme.bodySmall),
          ],
        ),
        if (vm.esPropio) ...[
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerLeft, child: EtiquetaEstadoEquipo(estado: equipo.estado)),
        ],
        const SizedBox(height: 12),
        Text(equipo.descripcion, style: tema.textTheme.bodyLarge),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.place, color: tema.colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(child: Text(equipo.direccion)),
          ],
        ),
        if (_mapasActivos) ...[
          const SizedBox(height: 12),
          _MapaPequeno(equipo: equipo),
        ],
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Disponibilidad', style: tema.textTheme.titleSmall),
                const SizedBox(height: 4),
                if (vm.ocupados.isEmpty)
                  Text('No tiene reservas activas. Todas las fechas futuras están libres.', style: tema.textTheme.bodySmall)
                else ...[
                  Text('Fechas ocupadas:', style: tema.textTheme.bodySmall),
                  for (final r in vm.ocupados)
                    Text('• ${Formato.rango(r.fechaInicio, r.fechaFin)}', style: tema.textTheme.bodySmall),
                ],
                const SizedBox(height: 4),
                Text(
                  'Entrega a las 08:00 del primer día. Reserva con al menos '
                  '${ReglasNegocio.anticipacionMinimaHoras} horas de anticipación.',
                  style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Reseñas de otras empresas', style: tema.textTheme.titleMedium),
        const SizedBox(height: 6),
        if (vm.resenas.isEmpty)
          Text('Este equipo aún no tiene reseñas.', style: tema.textTheme.bodySmall)
        else
          for (final r in vm.resenas)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Estrellas(valor: r.estrellas.toDouble(), tamano: 14),
                      const SizedBox(width: 8),
                      Expanded(child: Text(r.autorNombre, style: tema.textTheme.labelLarge)),
                    ],
                  ),
                  Text(r.comentario),
                  const Divider(),
                ],
              ),
            ),
      ],
    );
  }
}

class _MapaPequeno extends StatelessWidget {
  const _MapaPequeno({required this.equipo});

  final Equipo equipo;

  @override
  Widget build(BuildContext context) {
    final posicion = LatLng(equipo.lat, equipo.lng);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 180,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: posicion, zoom: 14),
          markers: {
            Marker(markerId: MarkerId(equipo.id), position: posicion, infoWindow: InfoWindow(title: equipo.nombre)),
          },
          liteModeEnabled: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
          zoomControlsEnabled: false,
          scrollGesturesEnabled: false,
          zoomGesturesEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          myLocationButtonEnabled: false,
          mapToolbarEnabled: false,
        ),
      ),
    );
  }
}

class _DialogoCotizacion extends StatelessWidget {
  const _DialogoCotizacion({required this.vm});

  final DetalleViewModel vm;

  @override
  Widget build(BuildContext context) {
    final c = vm.cotizacion;
    final inicio = vm.seleccionInicio;
    final fin = vm.seleccionFin;
    final tema = Theme.of(context);

    if (c == null || inicio == null || fin == null) {
      return AlertDialog(
        title: const Text('Resumen de la reserva'),
        content: Text(vm.errorSeleccion ?? 'La selección ya no está disponible. Elige otras fechas.'),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar'))],
      );
    }

    final ocupado = vm.cotizando || vm.reservando;
    return AlertDialog(
      title: const Text('Resumen de la reserva'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Formato.rango(Fechas.aIso(inicio), Fechas.aIso(fin)), style: tema.textTheme.titleSmall),
            const SizedBox(height: 8),
            _FilaMonto(etiqueta: '${c.dias} día(s) × ${Formato.soles(c.precioDia)}', monto: Formato.soles(c.subtotal)),
            const Divider(),
            _FilaMonto(etiqueta: 'Total a pagar', monto: Formato.soles(c.total), destacado: true),
            const SizedBox(height: 8),
            Text(
              'Sin cargos adicionales ni servicios preseleccionados. La comisión de EQUISHARE (12 % = '
              '${Formato.soles(c.comision)}) la paga la empresa arrendadora.',
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Puedes cancelar sin costo hasta 12 horas antes de la entrega; después se cobra el 20 %.',
              style: tema.textTheme.bodySmall,
            ),
            if (ocupado) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: vm.reservando
              ? null
              : () {
                  vm.descartarSeleccion();
                  Navigator.of(context).pop();
                },
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: ocupado
              ? null
              : () async {
                  final navegador = Navigator.of(context);
                  final ok = await vm.confirmarReserva();
                  if (ok) navegador.pop();
                },
          child: const Text('Confirmar reserva'),
        ),
      ],
    );
  }
}

class _FilaMonto extends StatelessWidget {
  const _FilaMonto({required this.etiqueta, required this.monto, this.destacado = false});

  final String etiqueta;
  final String monto;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final estilo = destacado ? tema.titleSmall?.copyWith(fontWeight: FontWeight.bold) : tema.bodyMedium;
    return Row(
      children: [
        Expanded(child: Text(etiqueta, style: estilo)),
        Text(monto, style: estilo),
      ],
    );
  }
}
