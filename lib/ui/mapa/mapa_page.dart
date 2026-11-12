import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../contenedor.dart';
import '../../domain/formato.dart';
import '../../domain/mapa/agrupador.dart';
import '../../domain/modelos.dart';
import '../../domain/repositorios.dart';
import '../componentes.dart';
import '../modelo_vista.dart';

/// El mapa muestra los mismos equipos del catálogo guardado (con los filtros activos).
class MapaViewModel extends ModeloVista {
  MapaViewModel(EquipoRepository equipos, this._ubicacion, this._ajustes) : tipoMapa = _ajustes.tipoMapa {
    _suscripcion = equipos.observarCatalogo().listen((lista) {
      this.equipos = lista;
      // Si el equipo elegido sale del catálogo (por un filtro), se quita la selección.
      if (seleccionado != null && !lista.any((e) => e.id == seleccionado)) seleccionado = null;
      avisar();
    });
    _ubicacion.tienePermiso().then((concedido) {
      if (cerrado) return;
      permisoConcedido = concedido;
      if (concedido) actualizarUbicacion();
    });
  }

  final ProveedorUbicacion _ubicacion;
  final AjustesRepository _ajustes;
  late final StreamSubscription<List<Equipo>> _suscripcion;

  static const String sinPermiso = 'Sin permiso de ubicación: el mapa funciona, pero no muestra tu posición.';

  List<Equipo> equipos = [];
  Coordenadas? miUbicacion;
  bool permisoConcedido = false;
  String? mensaje;

  /// Capa elegida (Normal, Satélite, Híbrido o Relieve). Se recuerda al volver a abrir la app.
  TipoMapa tipoMapa;

  /// Equipo resaltado: el mapa se centra en él y su tarjeta queda al frente.
  String? seleccionado;

  Future<void> actualizarUbicacion() async {
    final c = await _ubicacion.ubicacionActual();
    final concedido = await _ubicacion.tienePermiso();
    if (cerrado) return;
    miUbicacion = c;
    permisoConcedido = concedido;
    avisar();
  }

  /// Botón "Mi ubicación": si falta el permiso, se pide; si se niega, el mapa sigue funcionando.
  Future<void> pedirUbicacion() async {
    if (await _ubicacion.tienePermiso()) {
      await actualizarUbicacion();
      return;
    }
    final c = await _ubicacion.ubicacionActual(); // aquí se pide el permiso
    final concedido = await _ubicacion.tienePermiso();
    if (cerrado) return;
    permisoConcedido = concedido;
    mensaje = concedido ? null : sinPermiso;
    if (concedido) miUbicacion = c;
    avisar();
  }

  Future<void> alElegirTipoMapa(TipoMapa tipo) async {
    await _ajustes.guardarTipoMapa(tipo);
    if (cerrado) return;
    tipoMapa = _ajustes.tipoMapa;
    avisar();
  }

  /// Toque en un marcador o tarjeta, o tarjeta que quedó al frente al deslizar.
  void alSeleccionar(String? id) {
    seleccionado = id;
    avisar();
  }

  @override
  void dispose() {
    _suscripcion.cancel();
    super.dispose();
  }
}

class MapaPage extends StatefulWidget {
  const MapaPage({super.key, required this.alAbrirEquipo});

  final void Function(String equipoId) alAbrirEquipo;

  @override
  State<MapaPage> createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> {
  late final MapaViewModel vm;
  late final bool _mapasActivos;

  @override
  void initState() {
    super.initState();
    final c = context.read<Contenedor>();
    _mapasActivos = c.mapasActivos;
    vm = MapaViewModel(c.equipos, c.ubicacion, c.ajustes);
  }

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Equipos en el mapa')),
      body: _mapasActivos
          ? _MapaConEquipos(vm: vm, alAbrirEquipo: widget.alAbrirEquipo)
          : ListenableBuilder(
              listenable: vm,
              builder: (context, _) => _SinClaveMaps(equipos: vm.equipos, alAbrirEquipo: widget.alAbrirEquipo),
            ),
    );
  }
}

const double _zoomEquipo = 15;
const double _anchoTarjeta = 290;
const double _separacionTarjetas = 12;

class _MapaConEquipos extends StatefulWidget {
  const _MapaConEquipos({required this.vm, required this.alAbrirEquipo});

  final MapaViewModel vm;
  final void Function(String equipoId) alAbrirEquipo;

  @override
  State<_MapaConEquipos> createState() => _MapaConEquiposState();
}

class _MapaConEquiposState extends State<_MapaConEquipos> {
  GoogleMapController? _controlador;
  PageController? _tarjetas;
  double _anchoVisible = 0;
  double _zoom = 12;
  Coordenadas? _ultimaUbicacion;
  String? _ultimoSeleccionado;

  /// true mientras la persona arrastra las tarjetas con el dedo (no cuando la app las mueve sola).
  bool _arrastreConElDedo = false;

  /// Íconos de los grupos ya dibujados, por cantidad de equipos.
  final Map<int, BitmapDescriptor> _iconosGrupo = {};
  final Set<int> _dibujando = {};

  MapaViewModel get vm => widget.vm;

  @override
  void initState() {
    super.initState();
    vm.addListener(_alCambiar);
  }

  @override
  void dispose() {
    vm.removeListener(_alCambiar);
    _tarjetas?.dispose();
    super.dispose();
  }

  void _alCambiar() {
    final controlador = _controlador;
    // Al encontrar la ubicación, el mapa se centra en ella.
    final mia = vm.miUbicacion;
    if (mia != null && mia != _ultimaUbicacion && controlador != null) {
      _ultimaUbicacion = mia;
      controlador.moveCamera(CameraUpdate.newLatLngZoom(LatLng(mia.lat, mia.lng), 13));
    }
    // Al elegir un equipo (marcador o tarjeta): su tarjeta pasa al frente y el mapa se centra en él.
    final elegido = vm.seleccionado;
    if (elegido != _ultimoSeleccionado) {
      _ultimoSeleccionado = elegido;
      final indice = vm.equipos.indexWhere((e) => e.id == elegido);
      if (indice >= 0) {
        final equipo = vm.equipos[indice];
        final tarjetas = _tarjetas;
        if (tarjetas != null && tarjetas.hasClients && (tarjetas.page ?? 0).round() != indice) {
          tarjetas.animateToPage(indice, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
        }
        controlador?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(equipo.lat, equipo.lng), _zoom > _zoomEquipo ? _zoom : _zoomEquipo),
        );
      }
    }
  }

  /// Al soltar las tarjetas después de deslizarlas con el dedo, la que queda al centro se selecciona.
  bool _alMoverTarjetas(ScrollNotification aviso) {
    if (aviso is ScrollStartNotification && aviso.dragDetails != null) {
      _arrastreConElDedo = true;
    } else if (aviso is ScrollEndNotification && _arrastreConElDedo) {
      _arrastreConElDedo = false;
      final pagina = _tarjetas?.page;
      if (pagina != null && vm.equipos.isNotEmpty) {
        final indice = pagina.round().clamp(0, vm.equipos.length - 1);
        vm.alSeleccionar(vm.equipos[indice].id);
      }
    }
    return false;
  }

  /// Círculo azul con el número de equipos del grupo (el mismo dibujo de Kotlin: 112 píxeles).
  Future<void> _dibujarIconoGrupo(int cantidad, double densidad) async {
    if (_iconosGrupo.containsKey(cantidad) || !_dibujando.add(cantidad)) return;
    const lado = 112.0;
    const centro = lado / 2;
    final grabadora = ui.PictureRecorder();
    final lienzo = Canvas(grabadora);
    lienzo.drawCircle(const Offset(centro, centro), centro - 2, Paint()..color = Colors.white);
    lienzo.drawCircle(const Offset(centro, centro), centro - 10, Paint()..color = const Color(0xFF1E3A5F));
    final texto = TextPainter(
      text: TextSpan(
        text: '$cantidad',
        style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    texto.paint(lienzo, Offset(centro - texto.width / 2, centro - texto.height / 2));
    final imagen = await grabadora.endRecording().toImage(lado.toInt(), lado.toInt());
    final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
    _dibujando.remove(cantidad);
    if (datos == null || !mounted) return;
    setState(() {
      _iconosGrupo[cantidad] = BitmapDescriptor.bytes(
        datos.buffer.asUint8List(),
        width: lado / densidad,
        height: lado / densidad,
      );
    });
  }

  Set<Marker> _marcadores(double densidad) {
    // Los marcadores se agrupan según el nivel de zoom (número entero), como en Kotlin.
    final grupos = Agrupador.agrupar(vm.equipos, _zoom.floorToDouble());
    final marcadores = <Marker>{};
    for (final grupo in grupos) {
      final posicion = LatLng(grupo.lat, grupo.lng);
      if (grupo.esUnSolo) {
        final equipo = grupo.equipos.first;
        final elegido = equipo.id == vm.seleccionado;
        marcadores.add(Marker(
          markerId: MarkerId(equipo.id),
          position: posicion,
          infoWindow: InfoWindow(
            title: equipo.nombre,
            snippet: '${Formato.soles(equipo.precioDia)} / día · toca para ver',
            onTap: () => widget.alAbrirEquipo(equipo.id),
          ),
          icon: elegido ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure) : BitmapDescriptor.defaultMarker,
          zIndexInt: elegido ? 1 : 0,
          onTap: () => vm.alSeleccionar(equipo.id),
        ));
      } else {
        final icono = _iconosGrupo[grupo.cantidad];
        if (icono == null) _dibujarIconoGrupo(grupo.cantidad, densidad);
        marcadores.add(Marker(
          markerId: MarkerId('grupo:${grupo.equipos.map((e) => e.id).join(',')}'),
          position: posicion,
          infoWindow: InfoWindow(title: '${grupo.cantidad} equipos'),
          icon: icono ?? BitmapDescriptor.defaultMarker,
          anchor: const Offset(0.5, 0.5),
          consumeTapEvents: true,
          // Tocar un grupo acerca el mapa para separar sus equipos.
          onTap: () => _controlador?.animateCamera(CameraUpdate.newLatLngZoom(posicion, _zoom + 2)),
        ));
      }
    }
    final mia = vm.miUbicacion;
    // En el navegador no existe el punto azul de "mi ubicación", así que se dibuja un marcador.
    if (mia != null && kIsWeb) {
      marcadores.add(Marker(
        markerId: MarkerId('mi_ubicacion'),
        position: LatLng(mia.lat, mia.lng),
        infoWindow: InfoWindow(title: 'Tu ubicación'),
      ));
    }
    return marcadores;
  }

  static MapType _tipo(TipoMapa tipo) => switch (tipo) {
        TipoMapa.normal => MapType.normal,
        TipoMapa.satelite => MapType.satellite,
        TipoMapa.hibrido => MapType.hybrid,
        TipoMapa.relieve => MapType.terrain,
      };

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final densidad = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, limites) {
        // Cada tarjeta ocupa su ancho más la separación; la del centro es la elegida.
        if (_anchoVisible != limites.maxWidth) {
          _anchoVisible = limites.maxWidth;
          final anterior = _tarjetas;
          final fraccion = ((_anchoTarjeta + _separacionTarjetas) / limites.maxWidth).clamp(0.1, 1.0).toDouble();
          final pagina = (anterior != null && anterior.hasClients) ? (anterior.page ?? 0).round() : 0;
          _tarjetas = PageController(viewportFraction: fraccion, initialPage: pagina);
          if (anterior != null) WidgetsBinding.instance.addPostFrameCallback((_) => anterior.dispose());
        }
        return ListenableBuilder(
          listenable: vm,
          builder: (context, _) => Stack(
            children: [
              Positioned.fill(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(Config.trujilloLat, Config.trujilloLng),
                    zoom: 12,
                  ),
                  mapType: _tipo(vm.tipoMapa),
                  markers: _marcadores(densidad),
                  myLocationEnabled: vm.permisoConcedido && !kIsWeb,
                  myLocationButtonEnabled: false,
                  mapToolbarEnabled: false,
                  zoomControlsEnabled: false,
                  onMapCreated: (controlador) {
                    _controlador = controlador;
                    _alCambiar();
                  },
                  onCameraMove: (posicion) {
                    final antes = _zoom.floor();
                    _zoom = posicion.zoom;
                    // Solo se redibuja al cambiar de nivel de zoom, no en cada movimiento.
                    if (_zoom.floor() != antes) setState(() {});
                  },
                ),
              ),
              // Botones flotantes arriba a la derecha: capas y mi ubicación.
              Positioned(
                top: 12,
                right: 12,
                child: Column(
                  children: [
                    _BotonCapas(actual: vm.tipoMapa, alElegir: vm.alElegirTipoMapa),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'mi_ubicacion',
                      tooltip: 'Mostrar mi ubicación',
                      onPressed: vm.pedirUbicacion,
                      child: const Icon(Icons.my_location),
                    ),
                  ],
                ),
              ),
              if (vm.mensaje != null)
                Positioned(
                  top: 12,
                  left: 12,
                  right: 72,
                  child: Card(
                    color: tema.colorScheme.tertiaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(vm.mensaje!, style: tema.textTheme.bodySmall),
                    ),
                  ),
                ),
              // Tarjetas deslizables abajo del mapa.
              if (vm.equipos.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  height: 96,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _alMoverTarjetas,
                    child: PageView.builder(
                      controller: _tarjetas,
                      itemCount: vm.equipos.length,
                      itemBuilder: (context, i) {
                        final equipo = vm.equipos[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: _separacionTarjetas / 2),
                          child: _TarjetaMapa(
                            equipo: equipo,
                            elegido: equipo.id == vm.seleccionado,
                            alPulsar: () => vm.alSeleccionar(equipo.id),
                            alVer: () => widget.alAbrirEquipo(equipo.id),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Botón de capas: Normal, Satélite, Híbrido y Relieve.
class _BotonCapas extends StatelessWidget {
  const _BotonCapas({required this.actual, required this.alElegir});

  final TipoMapa actual;
  final void Function(TipoMapa tipo) alElegir;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return PopupMenuButton<TipoMapa>(
      tooltip: 'Cambiar capa del mapa',
      onSelected: alElegir,
      itemBuilder: (context) => [
        for (final tipo in TipoMapa.values)
          PopupMenuItem<TipoMapa>(
            value: tipo,
            child: Text(tipo == actual ? '✓ ${tipo.etiqueta}' : '    ${tipo.etiqueta}'),
          ),
      ],
      child: Material(
        color: esquema.primaryContainer,
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.map, color: esquema.onPrimaryContainer, semanticLabel: 'Cambiar capa del mapa'),
        ),
      ),
    );
  }
}

class _TarjetaMapa extends StatelessWidget {
  const _TarjetaMapa({required this.equipo, required this.elegido, required this.alPulsar, required this.alVer});

  final Equipo equipo;
  final bool elegido;
  final VoidCallback alPulsar;
  final VoidCallback alVer;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      elevation: elegido ? 8 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: elegido ? BorderSide(color: tema.colorScheme.primary, width: 2) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alPulsar,
        child: Padding(
          padding: const EdgeInsets.all(10),
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
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      equipo.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text('${Formato.soles(equipo.precioDia)} / día', style: tema.textTheme.bodyMedium),
                    Text(equipo.empresaNombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: tema.textTheme.bodySmall),
                  ],
                ),
              ),
              TextButton(onPressed: alVer, child: const Text('Ver')),
            ],
          ),
        ),
      ),
    );
  }
}

/// Alternativa cuando el mapa no está disponible: lista de equipos con su dirección.
class _SinClaveMaps extends StatelessWidget {
  const _SinClaveMaps({required this.equipos, required this.alAbrirEquipo});

  final List<Equipo> equipos;
  final void Function(String equipoId) alAbrirEquipo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: tema.colorScheme.tertiaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'El mapa no está disponible en este momento. Estas son las ubicaciones de los equipos:',
              style: tema.textTheme.bodySmall,
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final e in equipos.take(20))
          TextButton(onPressed: () => alAbrirEquipo(e.id), child: Text('${e.nombre} · ${e.direccion}')),
      ],
    );
  }
}
