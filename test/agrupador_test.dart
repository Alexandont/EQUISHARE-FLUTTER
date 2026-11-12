import 'package:equishare_flutter/domain/formato.dart';
import 'package:equishare_flutter/domain/mapa/agrupador.dart';
import 'package:equishare_flutter/domain/modelos.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mismas pruebas de la versión Kotlin (AgrupadorTest), traducidas a Dart:
/// agrupado de marcadores del mapa, capas y las iniciales del perfil.
void main() {
  Equipo equipo(String id, double lat, double lng) => Equipo(
        id: id,
        empresaId: 'demo-constructora',
        empresaNombre: 'Constructora Demo',
        nombre: 'Equipo $id',
        categoria: Categoria.construccion,
        descripcion: 'Descripción de prueba',
        precioDia: 80,
        fotoUrl: null,
        fotoId: null,
        lat: lat,
        lng: lng,
        direccion: 'Trujillo',
        estado: EstadoEquipo.publicado,
        calificacionPromedio: 0,
        totalResenas: 0,
        distanciaKm: null,
      );

  // Dos equipos a ~60 m en el centro de Trujillo y uno en Laredo (~8 km).
  final centro1 = equipo('a', -8.11160, -79.02870);
  final centro2 = equipo('b', -8.11180, -79.02910);
  final laredo = equipo('c', -8.08890, -78.96010);

  test('alejado: junta los equipos cercanos', () {
    final grupos = Agrupador.agrupar([centro1, centro2, laredo], 12);
    expect(grupos.length, 2);
    expect(grupos.first.equipos.map((e) => e.id).toList(), ['a', 'b']);
    expect(grupos.first.lat, closeTo((centro1.lat + centro2.lat) / 2, 1e-9));
    expect(grupos.last.esUnSolo, isTrue);
  });

  test('cerca de la calle: cada equipo va solo', () {
    final grupos = Agrupador.agrupar([centro1, centro2, laredo], 16);
    expect(grupos.length, 3);
    expect(grupos.every((g) => g.esUnSolo), isTrue);
  });

  test('muy lejos: todo en un grupo, y sin equipos no hay grupos', () {
    final grupos = Agrupador.agrupar([centro1, centro2, laredo], 5);
    expect(grupos.length, 1);
    expect(grupos.first.cantidad, 3);
    expect(Agrupador.agrupar([], 12), isEmpty);
  });

  test('nunca se pierde ni se repite un equipo', () {
    final muchos = [for (var i = 0; i < 40; i++) equipo('e$i', -8.05 - i * 0.003, -79.05 + (i % 7) * 0.004)];
    final esperados = muchos.map((e) => e.id).toList()..sort();
    for (final zoom in [8.0, 10.0, 12.0, 14.0, 15.0, 16.0, 18.0]) {
      final ids = Agrupador.agrupar(muchos, zoom).expand((g) => g.equipos.map((e) => e.id)).toList()..sort();
      expect(ids, esperados, reason: 'zoom $zoom');
    }
  });

  test('una capa guardada desconocida vuelve a Normal', () {
    expect(TipoMapa.desde('SATELITE'), TipoMapa.satelite);
    expect(TipoMapa.desde('OTRA'), TipoMapa.normal);
    expect(TipoMapa.desde(null), TipoMapa.normal);
  });

  test('las iniciales del perfil ignoran el tipo de sociedad', () {
    expect(Formato.iniciales('Constructora Norte S.A.C.'), 'CN');
    expect(Formato.iniciales('Eventos Demo Libertad E.I.R.L.'), 'ED');
    expect(Formato.iniciales('Servicios Técnicos Demo S.R.L.'), 'ST');
    expect(Formato.iniciales('taller'), 'T');
    expect(Formato.iniciales('S.A.C.'), 'EQ');
    expect(Formato.iniciales(null), 'EQ');
  });
}
