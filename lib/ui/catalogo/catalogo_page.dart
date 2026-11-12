import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../contenedor.dart';
import '../../domain/modelos.dart';
import '../componentes.dart';
import 'catalogo_vm.dart';

class CatalogoPage extends StatefulWidget {
  const CatalogoPage({super.key, required this.alAbrirEquipo, this.encabezado});

  final void Function(String equipoId) alAbrirEquipo;

  /// Contenido opcional arriba de la búsqueda (el saludo con el resumen de la empresa).
  final Widget? encabezado;

  @override
  State<CatalogoPage> createState() => _CatalogoPageState();
}

class _CatalogoPageState extends State<CatalogoPage> {
  late final CatalogoViewModel vm;
  final TextEditingController _busqueda = TextEditingController();

  @override
  void initState() {
    super.initState();
    final c = context.read<Contenedor>();
    vm = CatalogoViewModel(
      equipos: c.equipos,
      favoritos: c.favoritos,
      red: c.red,
      ubicacion: c.ubicacion,
      ajustes: c.ajustes,
    );
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
    _busqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EQUISHARE'),
        actions: [
          IconButton(tooltip: 'Actualizar catálogo', icon: const Icon(Icons.refresh), onPressed: vm.recargar),
        ],
      ),
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) => Column(
          children: [
            BannerSinConexion(visible: !vm.enLinea),
            if (vm.cargando && vm.equipos.isNotEmpty) const LinearProgressIndicator(),
            if (widget.encabezado != null) widget.encabezado!,
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _busqueda,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Buscar equipo…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: vm.texto.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Borrar búsqueda',
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _busqueda.clear();
                            vm.alCambiarTexto('');
                          },
                        ),
                ),
                onChanged: vm.alCambiarTexto,
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  FilterChip(
                    selected: vm.cercaDeMi,
                    avatar: vm.obteniendoUbicacion
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location, size: 18),
                    label: const Text('Cerca de mí'),
                    onSelected: vm.obteniendoUbicacion ? null : (valor) => vm.alCambiarCercaDeMi(valor),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    selected: vm.categoria == null,
                    label: const Text('Todas'),
                    onSelected: (_) => vm.alElegirCategoria(null),
                  ),
                  for (final c in Categoria.values) ...[
                    const SizedBox(width: 8),
                    FilterChip(
                      selected: vm.categoria == c,
                      label: Text(c.etiqueta),
                      onSelected: (_) => vm.alElegirCategoria(c),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(child: _contenido()),
          ],
        ),
      ),
    );
  }

  Widget _contenido() {
    if (vm.mostrarCargaInicial) return const ListaEsqueleto();
    if (vm.mostrarErrorPantalla) {
      return EstadoError(
        mensaje: vm.error?.mensaje ?? 'No se pudo cargar el catálogo.',
        alReintentar: vm.recargar,
      );
    }
    if (vm.mostrarVacio) {
      return const EstadoVacio(
        titulo: 'No hay equipos con esos filtros',
        detalle: 'Prueba con otra categoría, otra búsqueda o desactiva "Cerca de mí".',
      );
    }
    // Deslizar hacia abajo actualiza el catálogo.
    return RefreshIndicator(
      onRefresh: vm.recargar,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: vm.equipos.length,
        separatorBuilder: (context, indice) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final equipo = vm.equipos[i];
          return TarjetaEquipo(
            key: ValueKey(equipo.id),
            equipo: equipo,
            esFavorito: vm.favoritos.contains(equipo.id),
            alPulsar: () => widget.alAbrirEquipo(equipo.id),
            alCambiarFavorito: () => vm.alternarFavorito(equipo),
          );
        },
      ),
    );
  }
}
