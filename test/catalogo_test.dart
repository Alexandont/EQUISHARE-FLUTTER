import 'package:equishare_flutter/contenedor.dart';
import 'package:equishare_flutter/domain/modelos.dart';
import 'package:equishare_flutter/domain/resultado.dart';
import 'package:equishare_flutter/ui/catalogo/catalogo_page.dart';
import 'package:equishare_flutter/ui/catalogo/catalogo_vm.dart';
import 'package:equishare_flutter/ui/componentes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'falsos.dart';

/// Pruebas funcionales del catálogo: búsqueda, filtros, "Cerca de mí" (geolocalización),
/// favoritos y el comportamiento sin conexión (datos guardados y recuperación automática).
void main() {
  late List<String> abiertos;

  Future<void> esperar(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 500)); // espera de la búsqueda (400 ms)
    await tester.pump();
    await tester.pump();
  }

  Future<void> abrirCatalogo(WidgetTester tester, Contenedor contenedor) async {
    abiertos = [];
    await tester.pumpWidget(
      Provider<Contenedor>.value(
        value: contenedor,
        child: MaterialApp(home: CatalogoPage(alAbrirEquipo: abiertos.add)),
      ),
    );
    await esperar(tester);
  }

  Future<void> tocar(WidgetTester tester, Finder objetivo) async {
    await tester.ensureVisible(objetivo);
    await tester.pump();
    await tester.tap(objetivo);
    await tester.pump();
  }

  testWidgets('al abrir muestra los equipos del servidor', (tester) async {
    await abrirCatalogo(tester, contenedorDePrueba());

    expect(find.text('Mezcladora de concreto'), findsOneWidget);
    expect(find.text('Equipo de sonido profesional'), findsOneWidget);
    expect(find.text('Taladro percutor'), findsOneWidget);
  });

  testWidgets('el filtro de categoría muestra solo esa categoría', (tester) async {
    final equipos = EquiposFalsos();
    await abrirCatalogo(tester, contenedorDePrueba(equipos: equipos));

    await tocar(tester, find.widgetWithText(FilterChip, 'Eventos'));
    await esperar(tester);

    expect(find.text('Mezcladora de concreto'), findsNothing);
    expect(find.text('Equipo de sonido profesional'), findsOneWidget);
    expect(equipos.filtrosRecibidos.last.categoria, Categoria.eventos);
  });

  testWidgets('la búsqueda por texto filtra y se puede borrar', (tester) async {
    final equipos = EquiposFalsos();
    await abrirCatalogo(tester, contenedorDePrueba(equipos: equipos));

    await tester.enterText(find.byType(TextField), 'taladro');
    await esperar(tester);
    expect(find.text('Mezcladora de concreto'), findsNothing);
    expect(find.text('Taladro percutor'), findsOneWidget);
    expect(equipos.filtrosRecibidos.last.texto, 'taladro');

    await tocar(tester, find.byTooltip('Borrar búsqueda'));
    await esperar(tester);
    expect(find.text('Mezcladora de concreto'), findsOneWidget);
  });

  testWidgets('tocar un equipo abre su detalle', (tester) async {
    await abrirCatalogo(tester, contenedorDePrueba());

    await tocar(tester, find.text('Mezcladora de concreto'));

    expect(abiertos, ['eq-1']);
  });

  testWidgets('el corazón agrega el equipo a favoritos', (tester) async {
    final favoritos = FavoritosFalsos();
    await abrirCatalogo(tester, contenedorDePrueba(favoritos: favoritos));

    await tocar(tester, find.byTooltip('Agregar a favoritos').first);
    await esperar(tester);

    expect(favoritos.ids.valor, {'eq-1'});
    expect(find.byTooltip('Quitar de favoritos'), findsOneWidget);
  });

  testWidgets('"Cerca de mí" envía la ubicación y el radio al servidor', (tester) async {
    final equipos = EquiposFalsos();
    final ubicacion = UbicacionFalsa();
    await abrirCatalogo(tester, contenedorDePrueba(equipos: equipos, ubicacion: ubicacion));

    await tocar(tester, find.widgetWithText(FilterChip, 'Cerca de mí'));
    await esperar(tester);

    final filtro = equipos.filtrosRecibidos.lastWhere((f) => f.ubicacion != null);
    expect(filtro.ubicacion, ubicacion.coordenadas);
    expect(filtro.radioKm, CatalogoViewModel.radioCercaniaKm);
  });

  testWidgets('"Cerca de mí" sin GPS muestra un aviso y no filtra', (tester) async {
    final equipos = EquiposFalsos();
    await abrirCatalogo(tester, contenedorDePrueba(equipos: equipos, ubicacion: UbicacionFalsa(coordenadas: null)));

    await tocar(tester, find.widgetWithText(FilterChip, 'Cerca de mí'));
    await esperar(tester);

    expect(find.text('No se pudo obtener tu ubicación. Revisa el permiso y el GPS.'), findsOneWidget);
    expect(equipos.filtrosRecibidos.where((f) => f.ubicacion != null), isEmpty);
  });

  testWidgets('sin conexión muestra los datos guardados y se recupera solo', (tester) async {
    final equipos = EquiposFalsos()
      ..catalogo.valor = [mezcladora] // lo que ya estaba guardado en el dispositivo
      ..fallarCon = ErrorApp(TipoError.sinConexion);
    final red = RedFalsa(enLinea: false);
    await abrirCatalogo(tester, contenedorDePrueba(equipos: equipos, red: red));

    expect(find.text(textoSinConexion), findsOneWidget);
    expect(find.text('Mezcladora de concreto'), findsOneWidget);
    expect(find.text('Taladro percutor'), findsNothing);

    // Vuelve la conexión: el aviso se va y el catálogo se recarga sin tocar nada.
    equipos.fallarCon = null;
    red.estado.valor = true;
    await esperar(tester);

    expect(find.text(textoSinConexion), findsNothing);
    expect(find.text('Taladro percutor'), findsOneWidget);
  });

  testWidgets('error del servidor sin datos permite reintentar', (tester) async {
    final equipos = EquiposFalsos()..fallarCon = ErrorApp(TipoError.servidor);
    await abrirCatalogo(tester, contenedorDePrueba(equipos: equipos));

    expect(find.text(TipoError.servidor.mensajePorDefecto), findsOneWidget);

    equipos.fallarCon = null;
    await tocar(tester, find.widgetWithText(FilledButton, 'Reintentar'));
    await esperar(tester);

    expect(find.text('Mezcladora de concreto'), findsOneWidget);
  });

  testWidgets('sin resultados muestra el estado vacío', (tester) async {
    await abrirCatalogo(tester, contenedorDePrueba(equipos: EquiposFalsos(respuesta: [])));

    expect(find.text('No hay equipos con esos filtros'), findsOneWidget);
  });
}
