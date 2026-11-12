import 'package:equishare_flutter/contenedor.dart';
import 'package:equishare_flutter/domain/mapa/agrupador.dart';
import 'package:equishare_flutter/ui/bienvenida/bienvenida_page.dart';
import 'package:equishare_flutter/ui/mapa/mapa_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'falsos.dart';
import 'falsos_cuenta.dart';

/// Pruebas de la versión 0.16.0 (DisenoYMapaViewModelsTest y DisenoFuncionalTest de Kotlin):
/// bienvenida y mapa.
void main() {
  test('bienvenida: se muestra una sola vez', () async {
    final ajustes = AjustesFalsos()..bienvenidaVista = false;
    final vm = BienvenidaViewModel(ajustes);
    expect(vm.mostrar, isTrue);
    await vm.terminar();
    expect(vm.mostrar, isFalse);
    expect(BienvenidaViewModel(ajustes).mostrar, isFalse);
  });

  test('mapa: recuerda la capa y selecciona equipos', () async {
    final ajustes = AjustesFalsos();
    final repo = EquiposFalsos();
    repo.catalogo.valor = [mezcladora, sonido];
    final vm = MapaViewModel(repo, UbicacionFalsa(), ajustes);
    await esperarTareas();
    expect(vm.tipoMapa, TipoMapa.normal);

    await vm.alElegirTipoMapa(TipoMapa.satelite);
    expect(ajustes.tipoMapa, TipoMapa.satelite);
    expect(vm.tipoMapa, TipoMapa.satelite);

    vm.alSeleccionar(sonido.id);
    expect(vm.seleccionado, sonido.id);
    // Si el equipo sale del catálogo (por un filtro), se quita la selección.
    repo.catalogo.valor = [mezcladora];
    await esperarTareas();
    expect(vm.seleccionado, isNull);
    vm.dispose();
  });

  test('mapa: si se niega el permiso, avisa y sigue funcionando', () async {
    final ubicacion = UbicacionSinPermiso();
    final vm = MapaViewModel(EquiposFalsos(), ubicacion, AjustesFalsos());
    await esperarTareas();
    expect(vm.permisoConcedido, isFalse);

    await vm.pedirUbicacion();
    expect(vm.mensaje, MapaViewModel.sinPermiso);
    expect(vm.miUbicacion, isNull);
    vm.dispose();
  });

  testWidgets('bienvenida: se recorre con "Siguiente" y termina con "Empezar"', (tester) async {
    var terminadas = 0;
    await tester.pumpWidget(MaterialApp(home: BienvenidaPage(alTerminar: () => terminadas++)));

    expect(find.text('Bienvenido a EQUISHARE'), findsOneWidget);
    for (final titulo in ['Encuentra equipos cerca', 'Publica en un minuto', 'Empresas verificadas']) {
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(find.text(titulo), findsOneWidget);
    }
    await tester.tap(find.text('Empezar'));
    await tester.pump();
    expect(terminadas, 1);
  });

  testWidgets('bienvenida: "Saltar" termina de inmediato', (tester) async {
    var terminadas = 0;
    await tester.pumpWidget(MaterialApp(home: BienvenidaPage(alTerminar: () => terminadas++)));
    await tester.tap(find.text('Saltar'));
    await tester.pump();
    expect(terminadas, 1);
  });

  testWidgets('mapa sin Google Maps: muestra la lista de ubicaciones y abre el detalle', (tester) async {
    final equipos = EquiposFalsos();
    equipos.catalogo.valor = [mezcladora, sonido];
    final abiertos = <String>[];
    await tester.pumpWidget(
      Provider<Contenedor>.value(
        value: contenedorDePrueba(equipos: equipos),
        child: MaterialApp(home: MapaPage(alAbrirEquipo: abiertos.add)),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Equipos en el mapa'), findsOneWidget);
    expect(find.text('${mezcladora.nombre} · ${mezcladora.direccion}'), findsOneWidget);
    await tester.tap(find.text('${sonido.nombre} · ${sonido.direccion}'));
    expect(abiertos, [sonido.id]);
  });
}
