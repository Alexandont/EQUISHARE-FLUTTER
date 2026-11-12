import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../contenedor.dart';
import '../../domain/formato.dart';
import '../../domain/modelos.dart';
import '../../domain/repositorios.dart';
import '../../domain/resultado.dart';
import '../componentes.dart';
import '../modelo_vista.dart';
import '../publicar/publicar_page.dart';

class MisEquiposViewModel extends ModeloVista {
  MisEquiposViewModel(this._equipos, MonitorRed red) {
    enLinea = red.enLineaActual;
    _suscripciones.add(_equipos.observarPropios().listen((lista) {
      equipos = lista;
      avisar();
    }));
    _suscripciones.add(red.enLinea.listen((v) {
      enLinea = v;
      avisar();
    }));
    recargar();
  }

  final EquipoRepository _equipos;
  final List<StreamSubscription<Object?>> _suscripciones = [];

  List<Equipo> equipos = [];
  bool cargando = true;
  ErrorApp? error;
  bool enLinea = true;
  String? mensaje;

  Future<void> recargar() async {
    cargando = true;
    error = null;
    avisar();
    final r = await _equipos.refrescarPropios();
    if (cerrado) return;
    cargando = false;
    error = r.errorONull;
    avisar();
  }

  /// Eliminar toma los mismos 2 pasos que publicar (botón + confirmación): cancelación simétrica.
  Future<void> eliminar(Equipo equipo) async {
    final r = await _equipos.eliminar(equipo.id);
    if (cerrado) return;
    mensaje = r.errorONull?.mensaje ?? 'Se eliminó "${equipo.nombre}".';
    avisar();
  }

  void mensajeMostrado() {
    mensaje = null;
  }

  @override
  void dispose() {
    for (final s in _suscripciones) {
      s.cancel();
    }
    super.dispose();
  }
}

class MisEquiposPage extends StatefulWidget {
  const MisEquiposPage({super.key, required this.alAbrirEquipo, this.encabezado});

  final void Function(String equipoId) alAbrirEquipo;

  /// Contenido opcional arriba de la lista (el panel con los números de la empresa).
  final Widget? encabezado;

  @override
  State<MisEquiposPage> createState() => _MisEquiposPageState();
}

class _MisEquiposPageState extends State<MisEquiposPage> {
  late final MisEquiposViewModel vm;

  @override
  void initState() {
    super.initState();
    final c = context.read<Contenedor>();
    vm = MisEquiposViewModel(c.equipos, c.red);
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

  void _abrirFormulario([String? equipoId]) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PublicarPage(equipoId: equipoId)));
  }

  Future<void> _confirmarEliminar(Equipo equipo) async {
    final si = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Eliminar equipo?'),
        content: Text(
          '"${equipo.nombre}" dejará de aparecer en el catálogo. No se puede eliminar si tiene reservas activas.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(contexto).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            child: Text('Eliminar', style: TextStyle(color: Theme.of(contexto).colorScheme.error)),
          ),
        ],
      ),
    );
    if (si == true) vm.eliminar(equipo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis equipos'),
        actions: [IconButton(tooltip: 'Actualizar', icon: const Icon(Icons.refresh), onPressed: vm.recargar)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Publicar equipo'),
      ),
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) => Column(
          children: [
            BannerSinConexion(visible: !vm.enLinea),
            if (vm.cargando && vm.equipos.isNotEmpty) const LinearProgressIndicator(),
            if (widget.encabezado != null) widget.encabezado!,
            Expanded(child: _contenido()),
          ],
        ),
      ),
    );
  }

  Widget _contenido() {
    if (vm.cargando && vm.equipos.isEmpty) return const EstadoCargando();
    if (vm.error != null && vm.equipos.isEmpty) {
      return EstadoError(mensaje: vm.error!.mensaje, alReintentar: vm.recargar);
    }
    if (vm.equipos.isEmpty) {
      return const EstadoVacio(
        titulo: 'Aún no publicas equipos',
        detalle: 'Comparte la maquinaria o herramientas que tu empresa no usa todos los días y genera ingresos.',
      );
    }
    final tema = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: vm.equipos.length,
      separatorBuilder: (context, indice) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final equipo = vm.equipos[i];
        return Card(
          key: ValueKey(equipo.id),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => widget.alAbrirEquipo(equipo.id),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ImagenEquipo(
                    url: equipo.fotoUrl,
                    categoria: equipo.categoria,
                    descripcion: 'Foto de ${equipo.nombre}',
                    ancho: 64,
                    alto: 64,
                    radio: 10,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(equipo.nombre, style: tema.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                        Text('${Formato.soles(equipo.precioDia)} / día'),
                        const SizedBox(height: 4),
                        EtiquetaEstadoEquipo(estado: equipo.estado),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Editar ${equipo.nombre}',
                    icon: const Icon(Icons.edit),
                    onPressed: () => _abrirFormulario(equipo.id),
                  ),
                  IconButton(
                    tooltip: 'Eliminar ${equipo.nombre}',
                    icon: Icon(Icons.delete, color: tema.colorScheme.error),
                    onPressed: () => _confirmarEliminar(equipo),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
