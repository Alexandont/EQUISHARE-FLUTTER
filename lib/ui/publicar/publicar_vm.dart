import 'dart:typed_data';

import '../../domain/compat_kotlin.dart';
import '../../domain/ia/clasificador_equipo.dart';
import '../../domain/modelos.dart';
import '../../domain/repositorios.dart';
import '../../domain/resultado.dart';
import '../../domain/validadores.dart';
import '../modelo_vista.dart';

/// Estado de la revisión de la foto con la IA del teléfono.
sealed class RevisionIa {
  const RevisionIa();
}

/// Todavía no se eligió una foto nueva (o se está editando la foto ya guardada).
class IaSinRevisar extends RevisionIa {
  const IaSinRevisar();
}

class IaRevisando extends RevisionIa {
  const IaRevisando();
}

class IaLista extends RevisionIa {
  const IaLista(this.sugerencia);
  final SugerenciaFoto sugerencia;
}

/// La IA no pudo revisar la foto. No bloquea: se puede publicar igual.
class IaNoDisponible extends RevisionIa {
  const IaNoDisponible();
}

class PublicarViewModel extends ModeloVista {
  PublicarViewModel({
    this.equipoId,
    required EquipoRepository equipos,
    required ProveedorUbicacion ubicacion,
    AnalizadorFoto analizador = const AnalizadorFotoNinguno(),
    BuscadorDirecciones buscador = const BuscadorDireccionesNinguno(),
  })  : _equipos = equipos,
        _ubicacion = ubicacion,
        _analizador = analizador,
        _buscador = buscador,
        cargandoEquipo = equipoId != null {
    final id = equipoId;
    if (id != null) _cargarEquipo(id);
  }

  static const String direccionEncontrada =
      'Ubicamos la dirección en el mapa. Si hace falta, ajusta el punto tocando el mapa.';
  static const String direccionNoEncontrada =
      'No encontramos esa dirección. Agrega el distrito y la ciudad (por ejemplo, «Av. España 1234, Trujillo») o toca el mapa.';
  static const String sinCamara = 'No se encontró una app de cámara. Elige la foto de la galería.';

  final String? equipoId;
  final EquipoRepository _equipos;
  final ProveedorUbicacion _ubicacion;
  final AnalizadorFoto _analizador;
  final BuscadorDirecciones _buscador;

  bool get esEdicion => equipoId != null;
  bool cargandoEquipo;
  String nombre = '';
  Categoria? categoria;
  String descripcion = '';
  String precio = '';
  String direccion = '';
  double? lat;
  double? lng;
  bool visible = true;

  /// Foto nueva elegida en el teléfono: su ruta (para la IA) y su contenido (para subirla).
  String? fotoRutaLocal;
  Uint8List? fotoBytes;
  String? fotoNombre;
  String? fotoUrlRemota;
  String? fotoIdActual;

  /// La foto nueva ya se subió: si el guardado del equipo falla, no se vuelve a subir.
  bool _fotoYaSubida = false;
  EstadoEquipo? estadoActual;

  String? errorNombre;
  String? errorCategoria;
  String? errorDescripcion;
  String? errorPrecio;
  String? errorDireccion;
  String? errorUbicacion;
  List<String> motivosFoto = [];
  RevisionIa revisionIa = const IaSinRevisar();

  /// true cuando la categoría la eligió la IA y el usuario todavía no la cambió.
  bool categoriaPorIa = false;
  bool buscandoDireccion = false;
  bool obteniendoUbicacion = false;
  bool guardando = false;
  String? pasoGuardado;
  String? mensaje;
  bool guardadoOk = false;

  Future<void> _cargarEquipo(String id) async {
    final r = await _equipos.obtener(id);
    if (cerrado) return;
    cargandoEquipo = false;
    if (r is Exito<Equipo>) {
      final e = r.datos;
      nombre = e.nombre;
      categoria = e.categoria;
      descripcion = e.descripcion;
      precio = e.precioDia.toString();
      direccion = e.direccion;
      lat = e.lat;
      lng = e.lng;
      visible = e.estado != EstadoEquipo.oculto;
      fotoUrlRemota = e.fotoUrl;
      fotoIdActual = e.fotoId;
      estadoActual = e.estado;
    } else {
      mensaje = r.errorONull?.mensaje;
    }
    avisar();
  }

  void alCambiarNombre(String v) {
    nombre = v;
    errorNombre = null;
    avisar();
  }

  void alElegirCategoria(Categoria c) {
    categoria = c;
    errorCategoria = null;
    categoriaPorIa = false;
    avisar();
  }

  void alCambiarDescripcion(String v) {
    descripcion = v;
    errorDescripcion = null;
    avisar();
  }

  void alCambiarPrecio(String v) {
    final limpio = filtrarCaracteres(v, (c) => esDigito(c) || c == 0x2E || c == 0x2C);
    precio = limpio.length > 9 ? limpio.substring(0, 9) : limpio;
    errorPrecio = null;
    avisar();
  }

  void alCambiarDireccion(String v) {
    direccion = v;
    errorDireccion = null;
    avisar();
  }

  void alCambiarVisible(bool v) {
    visible = v;
    avisar();
  }

  /// Se eligió una foto (galería o cámara). La IA del teléfono la revisa enseguida.
  Future<void> alElegirFoto(String? ruta, {Uint8List? bytes, String? nombreArchivo}) async {
    if (ruta == null) return;
    fotoRutaLocal = ruta;
    fotoBytes = bytes;
    fotoNombre = nombreArchivo;
    _fotoYaSubida = false;
    motivosFoto = [];
    revisionIa = const IaRevisando();
    avisar();
    await _revisarConIa(ruta);
  }

  /// La IA del teléfono revisa la foto y sugiere la categoría. Si el usuario aún no eligió una,
  /// se elige sola; si ya eligió otra, solo se sugiere. Nunca bloquea la publicación.
  Future<void> _revisarConIa(String ruta) async {
    List<EtiquetaFoto>? etiquetas;
    try {
      etiquetas = await _analizador.etiquetar(ruta);
    } catch (_) {
      etiquetas = null;
    }
    // Si mientras tanto se eligió otra foto, este resultado ya no sirve.
    if (cerrado || fotoRutaLocal != ruta) return;
    final revision = etiquetas == null ? const IaNoDisponible() : IaLista(ClasificadorEquipo.clasificar(etiquetas));
    revisionIa = revision;
    final sugerida = revision is IaLista ? revision.sugerencia.categoria : null;
    if (sugerida != null && (categoria == null || categoriaPorIa)) {
      categoria = sugerida;
      categoriaPorIa = true;
      errorCategoria = null;
    }
    avisar();
  }

  /// Botón "Buscar en el mapa": convierte la dirección escrita en un punto del mapa.
  Future<void> buscarDireccion() async {
    final texto = direccion.trim();
    if (buscandoDireccion) return;
    if (Validadores.direccion(texto) != null) {
      errorDireccion = 'Escribe la dirección para buscarla en el mapa.';
      avisar();
      return;
    }
    buscandoDireccion = true;
    avisar();
    Coordenadas? coordenadas;
    try {
      coordenadas = await _buscador.buscar(texto);
    } catch (_) {
      coordenadas = null;
    }
    if (cerrado) return;
    buscandoDireccion = false;
    if (coordenadas == null) {
      mensaje = direccionNoEncontrada;
    } else {
      lat = coordenadas.lat;
      lng = coordenadas.lng;
      errorUbicacion = null;
      mensaje = direccionEncontrada;
    }
    avisar();
  }

  /// Botón "Usar ..." de la tarjeta de la IA: pone la categoría sugerida.
  void usarSugerenciaIa() {
    final revision = revisionIa;
    final sugerida = revision is IaLista ? revision.sugerencia.categoria : null;
    if (sugerida == null) return;
    categoria = sugerida;
    errorCategoria = null;
    categoriaPorIa = true;
    avisar();
  }

  void alElegirPunto(double latitud, double longitud) {
    lat = latitud;
    lng = longitud;
    errorUbicacion = null;
    avisar();
  }

  /// Como en Kotlin: si falta el permiso se pide; si la persona lo niega, no pasa nada.
  Future<void> usarMiUbicacion() async {
    final teniaPermiso = await _ubicacion.tienePermiso();
    obteniendoUbicacion = true;
    avisar();
    final c = await _ubicacion.ubicacionActual();
    final concedido = teniaPermiso || await _ubicacion.tienePermiso();
    if (cerrado) return;
    obteniendoUbicacion = false;
    if (!concedido) {
      avisar();
      return;
    }
    if (c == null) {
      mensaje = 'No se pudo obtener la ubicación. Activa el GPS o elige el punto en el mapa.';
    } else {
      lat = c.lat;
      lng = c.lng;
      errorUbicacion = null;
    }
    avisar();
  }

  bool _validar() {
    errorNombre = Validadores.nombreEquipo(nombre);
    errorCategoria = categoria == null ? 'Elige una categoría.' : null;
    errorDescripcion = Validadores.descripcion(descripcion);
    errorPrecio = Validadores.precio(precio);
    errorDireccion = Validadores.direccion(direccion);
    errorUbicacion = (lat == null || lng == null) ? 'Indica la ubicación del equipo.' : null;
    avisar();
    return [errorNombre, errorCategoria, errorDescripcion, errorPrecio, errorDireccion, errorUbicacion]
        .every((e) => e == null);
  }

  Future<void> guardar() async {
    if (guardando || !_validar()) return;
    guardando = true;
    motivosFoto = [];
    avisar();

    var fotoId = fotoIdActual;
    if (fotoRutaLocal != null && !_fotoYaSubida) {
      pasoGuardado = 'Validando la foto…';
      avisar();
      final subida = await _equipos.subirFoto(fotoBytes ?? Uint8List(0), fotoNombre ?? 'foto.jpg');
      if (cerrado) return;
      if (subida is Fallo<FotoSubida>) {
        // La foto rechazada explica el motivo y no se publica.
        guardando = false;
        pasoGuardado = null;
        motivosFoto = subida.error.detalles.isEmpty ? [subida.error.mensaje] : subida.error.detalles;
        avisar();
        return;
      }
      fotoId = (subida as Exito<FotoSubida>).datos.id;
      fotoIdActual = fotoId;
      _fotoYaSubida = true;
    }

    pasoGuardado = 'Guardando el equipo…';
    avisar();
    final entrada = EquipoEntrada(
      nombre: nombre,
      categoria: categoria ?? Categoria.herramientas,
      descripcion: descripcion,
      precioDia: Validadores.precioComoNumero(precio) ?? 0,
      lat: lat ?? 0,
      lng: lng ?? 0,
      direccion: direccion,
      fotoId: fotoId,
      visible: visible,
    );
    final id = equipoId;
    final r = id == null ? await _equipos.crear(entrada) : await _equipos.actualizar(id, entrada);
    if (cerrado) return;
    guardando = false;
    pasoGuardado = null;
    if (r is Exito<Equipo>) {
      mensaje = switch (r.datos.estado) {
        EstadoEquipo.pendienteFoto => 'Guardado. Agrega una foto aprobada para que aparezca en el catálogo.',
        EstadoEquipo.enRevision => 'Guardado. El equipo sigue en revisión por calificaciones bajas.',
        EstadoEquipo.oculto => 'Guardado como oculto.',
        EstadoEquipo.publicado => '¡Equipo publicado en el catálogo!',
      };
      guardadoOk = true;
    } else {
      final error = r.errorONull;
      mensaje = error == null ? 'No se pudo guardar.' : [error.mensaje, ...error.detalles].join(' ');
    }
    avisar();
  }

  void mensajeMostrado() {
    mensaje = null;
  }

  /// La cámara no está disponible: se avisa como en Kotlin.
  void avisarSinCamara() {
    mensaje = sinCamara;
    avisar();
  }
}
