import 'dart:math' as math;

import '../compat_kotlin.dart';
import '../modelos.dart';

/// Capas del mapa que la empresa puede elegir. Se guarda la elección en el teléfono.
enum TipoMapa {
  normal('NORMAL', 'Normal'),
  satelite('SATELITE', 'Satélite'),
  hibrido('HIBRIDO', 'Híbrido'),
  relieve('RELIEVE', 'Relieve');

  const TipoMapa(this.codigo, this.etiqueta);

  /// Nombre con el que se guarda (el mismo que usa Kotlin).
  final String codigo;
  final String etiqueta;

  static TipoMapa desde(String? valor) {
    for (final t in TipoMapa.values) {
      if (t.codigo == valor) return t;
    }
    return TipoMapa.normal;
  }
}

/// Un grupo de equipos cercanos que el mapa dibuja como un solo círculo con el número.
class GrupoEquipos {
  const GrupoEquipos(this.equipos, this.lat, this.lng);
  final List<Equipo> equipos;
  final double lat;
  final double lng;

  int get cantidad => equipos.length;
  bool get esUnSolo => equipos.length == 1;
}

/// Agrupa los marcadores del mapa para que no se amontonen. Divide el mapa en cuadros de
/// [tamanoCeldaPx] píxeles de pantalla (según el zoom) y junta los equipos de un mismo cuadro.
/// Al acercar el mapa, los cuadros cubren menos terreno y los grupos se separan solos.
/// Es Dart puro: se prueba con flutter test.
class Agrupador {
  Agrupador._();

  static const double _tamanoMundoPx = 256.0;
  static const double zoomSinGrupos = 16.0;

  static List<GrupoEquipos> agrupar(List<Equipo> equipos, double zoom, {double tamanoCeldaPx = 90.0}) {
    if (equipos.isEmpty) return const [];
    // En Kotlin el zoom es un Float; se redondea igual para que los cuadros coincidan.
    final z = aFloat(zoom);
    if (z >= zoomSinGrupos) return equipos.map((e) => GrupoEquipos([e], e.lat, e.lng)).toList();
    final escala = _tamanoMundoPx * math.pow(2.0, z).toDouble();

    // Agrupa por cuadro conservando el orden de aparición (como groupBy de Kotlin).
    final porCuadro = <(double, double), List<Equipo>>{};
    for (final e in equipos) {
      final (x, y) = _aPixeles(e.lat, e.lng, escala);
      final cuadro = ((x / tamanoCeldaPx).floorToDouble(), (y / tamanoCeldaPx).floorToDouble());
      porCuadro.putIfAbsent(cuadro, () => []).add(e);
    }

    final grupos = porCuadro.values.map((grupo) {
      var sumaLat = 0.0;
      var sumaLng = 0.0;
      for (final e in grupo) {
        sumaLat += e.lat;
        sumaLng += e.lng;
      }
      return GrupoEquipos(
        ordenEstable(grupo, (Equipo a, Equipo b) => a.id.compareTo(b.id)),
        sumaLat / grupo.length,
        sumaLng / grupo.length,
      );
    });

    return ordenEstable(grupos, (GrupoEquipos a, GrupoEquipos b) {
      final porCantidad = b.cantidad.compareTo(a.cantidad);
      return porCantidad != 0 ? porCantidad : a.equipos.first.id.compareTo(b.equipos.first.id);
    });
  }

  /// Proyección Web Mercator, la misma que usa Google Maps.
  static (double, double) _aPixeles(double lat, double lng, double escala) {
    final latLimitada = lat.clamp(-85.0, 85.0).toDouble();
    final x = (lng + 180.0) / 360.0 * escala;
    final rad = latLimitada * math.pi / 180.0;
    final y = (1.0 - math.log(math.tan(rad) + 1.0 / math.cos(rad)) / math.pi) / 2.0 * escala;
    return (x, y);
  }
}
