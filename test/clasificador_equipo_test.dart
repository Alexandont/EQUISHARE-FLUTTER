import 'package:equishare_flutter/domain/ia/clasificador_equipo.dart';
import 'package:equishare_flutter/domain/modelos.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mismas pruebas de la versión Kotlin (ClasificadorEquipoTest), traducidas a Dart.
void main() {
  EtiquetaFoto e(String texto, double confianza) => EtiquetaFoto(texto, confianza);

  test('una laptop sugiere Tecnología', () {
    final r = ClasificadorEquipo.clasificar([e('Computer', 0.92), e('Mobile phone', 0.6)]);
    expect(r.categoria, Categoria.tecnologia);
    expect(r.pistas, const [PistaIa('computadora', 92), PistaIa('celular', 60)]);
    expect(r.pareceOtraCosa, isNull);
  });

  test('sillas y mantel sugieren Eventos', () {
    final r = ClasificadorEquipo.clasificar([e('Chair', 0.88), e('Tablecloth', 0.75), e('Event', 0.62)]);
    expect(r.categoria, Categoria.eventos);
    expect(r.pistas.map((p) => p.nombre).toList(), ['sillas', 'mantel', 'evento']);
  });

  test('una excavadora sugiere Construcción con las pistas de mayor confianza', () {
    final r = ClasificadorEquipo.clasificar(
      [e('Construction', 0.7), e('Vehicle', 0.9), e('Tractor', 0.82), e('Soil', 0.6)],
    );
    expect(r.categoria, Categoria.construccion);
    expect(r.pistas, const [
      PistaIa('vehículo', 90),
      PistaIa('maquinaria pesada', 82),
      PistaIa('obra de construcción', 70),
    ]);
  });

  test('un auto común no adivina una categoría', () {
    // "Vehicle" solo vale medio punto: un auto no basta para decir "Construcción".
    final r = ClasificadorEquipo.clasificar([e('Car', 0.95), e('Vehicle', 0.93), e('Wheel', 0.9), e('Tire', 0.88)]);
    expect(r.categoria, isNull);
    expect(r.pistas, isEmpty);
    expect(r.pareceOtraCosa, isNull);
  });

  test('una selfie y la comida avisan que no es un equipo', () {
    final selfie = ClasificadorEquipo.clasificar([e('Selfie', 0.9), e('Smile', 0.85), e('Person', 0.8)]);
    expect(selfie.categoria, isNull);
    expect(selfie.pareceOtraCosa, 'una selfie');

    final comida = ClasificadorEquipo.clasificar([e('Food', 0.95), e('Cuisine', 0.9)]);
    expect(comida.pareceOtraCosa, 'comida');
  });

  test('las etiquetas con poca confianza o inválidas se ignoran', () {
    expect(ClasificadorEquipo.clasificar([e('Computer', 0.45)]).categoria, isNull);
    expect(ClasificadorEquipo.clasificar([e('Computer', double.nan)]).categoria, isNull);
    final vacia = ClasificadorEquipo.clasificar([]);
    expect(vacia.categoria, isNull);
    expect(vacia.pareceOtraCosa, isNull);
    expect(vacia.pistas, isEmpty);
  });

  test('no importan mayúsculas ni espacios, y una etiqueta repetida cuenta una vez', () {
    expect(ClasificadorEquipo.clasificar([e('  mobile PHONE ', 0.8)]).categoria, Categoria.tecnologia);
    // Dos veces "Vehicle" (0.9 × 0.5) siguen siendo 0.45 puntos: no llega al mínimo.
    expect(ClasificadorEquipo.clasificar([e('Vehicle', 0.9), e('vehicle', 0.9)]).categoria, isNull);
  });

  test('muestra como máximo tres pistas sin repetir nombres', () {
    final r = ClasificadorEquipo.clasificar(
      [e('Couch', 0.9), e('Loveseat', 0.85), e('Chair', 0.8), e('Bench', 0.7), e('Party', 0.65)],
    );
    expect(r.categoria, Categoria.eventos);
    expect(r.pistas.map((p) => p.nombre).toList(), ['sofá', 'sillas', 'bancas']);
    expect(r.textoPistas(), 'sofá (90 %), sillas (80 %), bancas (70 %)');
  });

  test('gana la categoría con más puntos y el empate se resuelve siempre igual', () {
    final r = ClasificadorEquipo.clasificar([e('Computer', 0.7), e('Chair', 0.9), e('Television', 0.6)]);
    // Tecnología: 0.7 + 0.6 = 1.3 puntos; Eventos: 0.9 puntos.
    expect(r.categoria, Categoria.tecnologia);

    final empate = ClasificadorEquipo.clasificar([e('Computer', 0.7), e('Chair', 0.7)]);
    expect(empate.categoria, Categoria.eventos);
  });

  test('una herramienta que el modelo no conoce no inventa nada', () {
    final r = ClasificadorEquipo.clasificar([e('Metal', 0.8), e('Product', 0.7)]);
    expect(r.categoria, isNull);
    expect(r.pareceOtraCosa, isNull);
  });
}
