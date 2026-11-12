import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../contenedor.dart';
import '../../domain/compat_kotlin.dart';
import '../../domain/modelos.dart';
import '../componentes.dart';
import 'publicar_vm.dart';

class PublicarPage extends StatefulWidget {
  const PublicarPage({super.key, this.equipoId});

  /// null = publicar un equipo nuevo; con id = editar ese equipo.
  final String? equipoId;

  @override
  State<PublicarPage> createState() => _PublicarPageState();
}

class _PublicarPageState extends State<PublicarPage> {
  late final PublicarViewModel vm;
  late final bool _mapasActivos;
  final TextEditingController _nombre = TextEditingController();
  final TextEditingController _descripcion = TextEditingController();
  final TextEditingController _precio = TextEditingController();
  final TextEditingController _direccion = TextEditingController();
  GoogleMapController? _mapa;
  bool _camposRellenados = false;
  LatLng? _ultimoPunto;

  @override
  void initState() {
    super.initState();
    final c = context.read<Contenedor>();
    _mapasActivos = c.mapasActivos;
    vm = PublicarViewModel(
      equipoId: widget.equipoId,
      equipos: c.equipos,
      ubicacion: c.ubicacion,
      analizador: c.analizadorFoto,
      buscador: c.buscadorDirecciones,
    );
    if (!vm.cargandoEquipo) _camposRellenados = true;
    vm.addListener(_alCambiar);
  }

  void _alCambiar() {
    if (!mounted) return;
    // Al terminar de cargar el equipo (modo edición) se rellenan los campos una sola vez.
    if (!_camposRellenados && !vm.cargandoEquipo) {
      _camposRellenados = true;
      _nombre.text = vm.nombre;
      _descripcion.text = vm.descripcion;
      _precio.text = vm.precio;
      _direccion.text = vm.direccion;
    }
    // El precio se limpia en el ViewModel (solo números, punto o coma): el campo muestra lo mismo.
    if (_precio.text != vm.precio) {
      _precio.value = TextEditingValue(text: vm.precio, selection: TextSelection.collapsed(offset: vm.precio.length));
    }
    _moverMapa();
    final texto = vm.mensaje;
    if (texto == null) return;
    vm.mensajeMostrado();
    // El ScaffoldMessenger es compartido: el aviso sigue visible aunque la pantalla se cierre.
    mostrarMensaje(context, texto);
    if (vm.guardadoOk) Navigator.of(context).pop();
  }

  void _moverMapa() {
    final lat = vm.lat;
    final lng = vm.lng;
    final mapa = _mapa;
    if (lat == null || lng == null || mapa == null) return;
    final punto = LatLng(lat, lng);
    if (punto == _ultimoPunto) return;
    _ultimoPunto = punto;
    mapa.moveCamera(CameraUpdate.newLatLng(punto));
  }

  @override
  void dispose() {
    vm.removeListener(_alCambiar);
    vm.dispose();
    _nombre.dispose();
    _descripcion.dispose();
    _precio.dispose();
    _direccion.dispose();
    super.dispose();
  }

  /// La imagen se reduce a 1600 px por lado y se comprime: ahorra datos y respeta el límite de 5 MB.
  Future<void> _elegirFoto(ImageSource fuente) async {
    try {
      final archivo = await ImagePicker().pickImage(source: fuente, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
      if (archivo == null) return;
      final bytes = await archivo.readAsBytes();
      vm.alElegirFoto(archivo.path, bytes: bytes, nombreArchivo: archivo.name.isEmpty ? 'foto.jpg' : archivo.name);
    } on PlatformException catch (e) {
      if (fuente == ImageSource.camera && e.code.contains('camera')) {
        vm.avisarSinCamara();
      } else if (mounted) {
        mostrarMensaje(context, 'No se pudo leer la imagen seleccionada.');
      }
    } catch (_) {
      if (mounted) mostrarMensaje(context, 'No se pudo leer la imagen seleccionada.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(vm.esEdicion ? 'Editar equipo' : 'Publicar equipo')),
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) => vm.cargandoEquipo ? const EstadoCargando() : _formulario(),
      ),
    );
  }

  Widget _formulario() {
    final tema = Theme.of(context);
    final lat = vm.lat;
    final lng = vm.lng;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (vm.estadoActual != null) ...[
                Align(alignment: Alignment.centerLeft, child: EtiquetaEstadoEquipo(estado: vm.estadoActual!)),
                const SizedBox(height: 12),
              ],
              // ---- Foto + revisión con IA del teléfono ----
              SeccionFotoConIa(
                vm: vm,
                alPedirFoto: () => _elegirFoto(ImageSource.gallery),
                alTomarFoto: () => _elegirFoto(ImageSource.camera),
              ),
              const SizedBox(height: 16),
              // ---- Datos ----
              TextField(
                controller: _nombre,
                decoration: InputDecoration(labelText: 'Nombre del equipo', errorText: vm.errorNombre),
                onChanged: vm.alCambiarNombre,
              ),
              const SizedBox(height: 12),
              Text(vm.categoriaPorIa ? 'Categoría (sugerida por la IA)' : 'Categoría', style: tema.textTheme.labelLarge),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final c in Categoria.values) ...[
                      FilterChip(
                        label: Text(c.etiqueta),
                        selected: vm.categoria == c,
                        onSelected: (_) => vm.alElegirCategoria(c),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              if (vm.errorCategoria != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(vm.errorCategoria!, style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.error)),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _descripcion,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: 'Descripción (estado, accesorios, condiciones)',
                  errorText: vm.errorDescripcion,
                  helperText: '${vm.descripcion.trim().length}/500',
                ),
                onChanged: vm.alCambiarDescripcion,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _precio,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Precio por día (S/)', errorText: vm.errorPrecio),
                onChanged: vm.alCambiarPrecio,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _direccion,
                decoration: InputDecoration(labelText: 'Dirección de recojo (referencial)', errorText: vm.errorDireccion),
                onChanged: vm.alCambiarDireccion,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: vm.buscandoDireccion ? null : vm.buscarDireccion,
                icon: vm.buscandoDireccion
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search),
                label: Text(vm.buscandoDireccion ? 'Buscando la dirección…' : 'Buscar la dirección en el mapa'),
              ),
              const SizedBox(height: 16),
              // ---- Ubicación (Google Maps / GPS) ----
              Text('Ubicación del equipo', style: tema.textTheme.labelLarge),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: vm.obteniendoUbicacion ? null : vm.usarMiUbicacion,
                icon: const Icon(Icons.my_location),
                label: Text(vm.obteniendoUbicacion ? 'Obteniendo ubicación…' : 'Usar mi ubicación actual'),
              ),
              if (_mapasActivos) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 220,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(lat ?? Config.trujilloLat, lng ?? Config.trujilloLng),
                        zoom: 13,
                      ),
                      markers: {
                        if (lat != null && lng != null)
                          Marker(
                            markerId: MarkerId('equipo'),
                            position: LatLng(lat, lng),
                            infoWindow: InfoWindow(title: 'Ubicación del equipo'),
                          ),
                      },
                      onTap: (punto) => vm.alElegirPunto(punto.latitude, punto.longitude),
                      onMapCreated: (controlador) {
                        _mapa = controlador;
                        if (lat != null && lng != null) _ultimoPunto = LatLng(lat, lng);
                      },
                      zoomControlsEnabled: true,
                      mapToolbarEnabled: false,
                      myLocationButtonEnabled: false,
                      // Permite mover el mapa aunque esté dentro de una pantalla con desplazamiento.
                      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text('También puedes tocar el mapa para ubicar el equipo.', style: tema.textTheme.bodySmall),
              ],
              const SizedBox(height: 4),
              Text(
                (lat != null && lng != null)
                    ? 'Coordenadas: ${fijoComoJava(lat, 5)}, ${fijoComoJava(lng, 5)}'
                    : 'Aún no se indicó la ubicación.',
                style: tema.textTheme.bodySmall?.copyWith(
                  color: vm.errorUbicacion != null ? tema.colorScheme.error : tema.colorScheme.onSurfaceVariant,
                ),
              ),
              if (vm.errorUbicacion != null)
                Text(vm.errorUbicacion!, style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.error)),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Visible en el catálogo'),
                subtitle: const Text('Puedes ocultarlo temporalmente sin borrarlo.'),
                value: vm.visible,
                onChanged: vm.alCambiarVisible,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: vm.guardando ? null : vm.guardar,
                  child: vm.guardando
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: 12),
                            Text(vm.pasoGuardado ?? 'Guardando…'),
                          ],
                        )
                      : Text(vm.esEdicion ? 'Guardar cambios' : 'Publicar'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// Parte de la pantalla Publicar con la foto del equipo y la tarjeta de la IA.
/// Está separada para poder probarla sola en las pruebas funcionales.
class SeccionFotoConIa extends StatelessWidget {
  const SeccionFotoConIa({super.key, required this.vm, required this.alPedirFoto, this.alTomarFoto});

  final PublicarViewModel vm;
  final VoidCallback alPedirFoto;

  /// Si no es null, aparece también el botón "Tomar foto" (cámara del teléfono).
  final VoidCallback? alTomarFoto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final bytes = vm.fotoBytes;
    final remota = vm.fotoUrlRemota;
    final hayFoto = vm.fotoRutaLocal != null || remota != null;

    Widget foto;
    if (bytes != null) {
      foto = Image.memory(bytes, fit: BoxFit.cover, semanticLabel: 'Foto del equipo');
    } else if (remota != null && vm.fotoRutaLocal == null) {
      foto = Image.network(
        remota,
        fit: BoxFit.cover,
        semanticLabel: 'Foto del equipo',
        errorBuilder: (context, error, stack) => const SizedBox.shrink(),
      );
    } else {
      foto = const Card(
        margin: EdgeInsets.zero,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_a_photo, size: 40),
              SizedBox(height: 8),
              Text('Agrega una foto clara del equipo'),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(16), child: SizedBox(height: 190, child: foto)),
        const SizedBox(height: 12),
        Row(
          children: [
            if (alTomarFoto != null) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: vm.guardando ? null : alTomarFoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Tomar foto'),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: OutlinedButton.icon(
                onPressed: vm.guardando ? null : alPedirFoto,
                icon: const Icon(Icons.add_a_photo),
                label: Text(hayFoto ? 'Cambiar foto' : 'Elegir foto'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'La foto se valida automáticamente al guardar: JPG, PNG o WebP, mínimo 640×480 px y máximo 5 MB.',
          style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
        ),
        _TarjetaIa(
          revision: vm.revisionIa,
          categoriaActual: vm.categoria,
          categoriaPorIa: vm.categoriaPorIa,
          alUsarSugerencia: vm.usarSugerenciaIa,
        ),
        if (vm.motivosFoto.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            color: tema.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'La foto fue rechazada:',
                    style: tema.textTheme.titleSmall?.copyWith(color: tema.colorScheme.onErrorContainer),
                  ),
                  for (final m in vm.motivosFoto)
                    Text('• $m', style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onErrorContainer)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TarjetaIa extends StatelessWidget {
  const _TarjetaIa({
    required this.revision,
    required this.categoriaActual,
    required this.categoriaPorIa,
    required this.alUsarSugerencia,
  });

  final RevisionIa revision;
  final Categoria? categoriaActual;
  final bool categoriaPorIa;
  final VoidCallback alUsarSugerencia;

  @override
  Widget build(BuildContext context) {
    final revision = this.revision;
    if (revision is IaSinRevisar) return const SizedBox.shrink();
    final tema = Theme.of(context);
    final color = tema.colorScheme.onSecondaryContainer;
    TextStyle? estilo(TextStyle? base) => base?.copyWith(color: color);

    final contenido = <Widget>[];
    if (revision is IaRevisando) {
      contenido.add(Row(
        children: [
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: color)),
          const SizedBox(width: 10),
          Text('Revisando la foto con IA…', style: estilo(tema.textTheme.bodyMedium)),
        ],
      ));
    } else if (revision is IaNoDisponible) {
      contenido.add(
        Text('No se pudo revisar la foto con IA. Puedes publicar igual.', style: estilo(tema.textTheme.bodyMedium)),
      );
    } else if (revision is IaLista) {
      final sugerencia = revision.sugerencia;
      final sugerida = sugerencia.categoria;
      contenido.add(Text('Revisión con IA', style: estilo(tema.textTheme.titleSmall)));
      if (sugerida != null) {
        contenido.add(Text(
          'Categoría sugerida: ${sugerida.etiqueta}',
          style: estilo(tema.textTheme.bodyLarge)?.copyWith(fontWeight: FontWeight.w600),
        ));
        if (sugerencia.pistas.isNotEmpty) {
          contenido.add(Text('La IA ve: ${sugerencia.textoPistas()}', style: estilo(tema.textTheme.bodySmall)));
        }
        if (categoriaActual == sugerida && categoriaPorIa) {
          contenido.add(
            Text('La elegimos por ti. Puedes cambiarla en Categoría.', style: estilo(tema.textTheme.bodySmall)),
          );
        } else if (categoriaActual == sugerida) {
          contenido.add(Text('Coincide con la categoría que elegiste.', style: estilo(tema.textTheme.bodySmall)));
        } else {
          contenido.add(TextButton(onPressed: alUsarSugerencia, child: Text('Usar ${sugerida.etiqueta}')));
        }
      } else {
        final otraCosa = sugerencia.pareceOtraCosa;
        contenido.add(Text(
          otraCosa != null
              ? 'La foto parece mostrar $otraCosa, no un equipo. Toma la foto al equipo completo.'
              : 'La IA no pudo identificar la categoría. Elígela tú.',
          style: estilo(tema.textTheme.bodyMedium),
        ));
        contenido.add(Text('Puedes publicar igual.', style: estilo(tema.textTheme.bodySmall)));
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        margin: EdgeInsets.zero,
        color: tema.colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: contenido),
        ),
      ),
    );
  }
}
