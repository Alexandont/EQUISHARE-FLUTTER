import 'package:equishare_flutter/domain/ia/clasificador_equipo.dart';
import 'package:equishare_flutter/domain/modelos.dart';
import 'package:equishare_flutter/domain/resultado.dart';
import 'package:equishare_flutter/ui/panel/panel.dart';
import 'package:equishare_flutter/ui/publicar/publicar_page.dart';
import 'package:equishare_flutter/ui/publicar/publicar_vm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'falsos.dart';
import 'falsos_cuenta.dart';

/// Pruebas del panel de la empresa y de la foto con IA (DisenoYMapaViewModelsTest,
/// DisenoFuncionalTest e IaFotoFuncionalTest de la versión Kotlin, traducidas a Dart).
void main() {
  const empresa = Empresa(
    id: 'uid-1',
    razonSocial: 'Constructora Norte S.A.C.',
    ruc: '20131312955',
    telefono: '949123456',
    email: null,
    verificada: true,
    calificacionComoArrendatario: 0,
    totalResenasComoArrendatario: 0,
  );

  test('panel: muestra la empresa, sus números y sus favoritos, y conserva los datos si falla la red', () async {
    final empresas = EmpresasCuentaFalsas()..miEmpresaActual = empresa;
    final favoritos = FavoritosCuentaFalsos();
    final vm = PanelViewModel(empresas, favoritos);
    await esperarTareas();
    expect(vm.empresa, 'Constructora Norte S.A.C.');
    expect(vm.metricas?.reservasPendientes, 2);

    await favoritos.establecer(mezcladora, true);
    await esperarTareas();
    expect(vm.favoritos, 1);

    empresas.metricasActuales = Fallo<MetricasEmpresa>(ErrorApp(TipoError.sinConexion, mensaje: 'Sin conexión.'));
    await vm.cargar();
    expect(vm.error, 'Sin conexión.');
    expect(vm.metricas, isNotNull);
    vm.dispose();
  });

  testWidgets('el saludo y el panel muestran los números de la empresa', (tester) async {
    final vm = PanelViewModel(EmpresasCuentaFalsas()..miEmpresaActual = empresa, FavoritosCuentaFalsos());
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: Column(children: [SaludoInicio(vm: vm), PanelMetricas(vm: vm)])),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Hola, Constructora Norte S.A.C.'), findsOneWidget);
    expect(find.text('Tu panel'), findsOneWidget);
    expect(find.text('3 de 4'), findsOneWidget);
    expect(find.text('Más alquilado: Mezcladora (3 veces)'), findsOneWidget);
    vm.dispose();
  });

  // ---- Foto con IA en Publicar (el selector de fotos se reemplaza por una foto fija de prueba) ----

  const foto = '/fotos/equipo.jpg';

  Future<PublicarViewModel> abrirFoto(WidgetTester tester, AnalizadorFotoFalso ia) async {
    final vm = PublicarViewModel(equipos: EquiposFalsos(), ubicacion: UbicacionFalsa(), analizador: ia);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ListenableBuilder(
            listenable: vm,
            builder: (context, _) => SeccionFotoConIa(vm: vm, alPedirFoto: () => vm.alElegirFoto(foto)),
          ),
        ),
      ),
    ));
    return vm;
  }

  Future<void> tocar(WidgetTester tester, String texto) async {
    await tester.ensureVisible(find.text(texto));
    await tester.tap(find.text(texto));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('foto de una laptop: la IA sugiere Tecnología y la elige', (tester) async {
    final ia = AnalizadorFotoFalso([EtiquetaFoto('Computer', 0.92)]);
    final vm = await abrirFoto(tester, ia);

    await tocar(tester, 'Elegir foto');

    expect(find.text('Categoría sugerida: Tecnología'), findsOneWidget);
    expect(find.text('La IA ve: computadora (92 %)'), findsOneWidget);
    expect(find.text('La elegimos por ti. Puedes cambiarla en Categoría.'), findsOneWidget);
    expect(ia.pedidas, [foto]);
    expect(vm.categoria, Categoria.tecnologia);
    vm.dispose();
  });

  testWidgets('si ya había otra categoría, el botón "Usar" aplica la sugerencia', (tester) async {
    final vm = await abrirFoto(tester, AnalizadorFotoFalso([EtiquetaFoto('Chair', 0.9), EtiquetaFoto('Tablecloth', 0.8)]));
    vm.alElegirCategoria(Categoria.construccion);
    await tester.pump();

    await tocar(tester, 'Elegir foto');
    expect(find.text('Usar Eventos'), findsOneWidget);
    expect(vm.categoria, Categoria.construccion);

    await tocar(tester, 'Usar Eventos');
    expect(find.text('La elegimos por ti. Puedes cambiarla en Categoría.'), findsOneWidget);
    expect(vm.categoria, Categoria.eventos);
    vm.dispose();
  });

  testWidgets('selfie: avisa que no es un equipo y no elige categoría', (tester) async {
    final vm = await abrirFoto(tester, AnalizadorFotoFalso([EtiquetaFoto('Selfie', 0.9), EtiquetaFoto('Smile', 0.8)]));

    await tocar(tester, 'Elegir foto');

    expect(find.text('La foto parece mostrar una selfie, no un equipo. Toma la foto al equipo completo.'), findsOneWidget);
    expect(find.text('Puedes publicar igual.'), findsOneWidget);
    expect(vm.categoria, isNull);
    vm.dispose();
  });

  testWidgets('si la IA no puede revisar, avisa y no bloquea', (tester) async {
    final vm = await abrirFoto(tester, AnalizadorFotoFalso(null));

    await tocar(tester, 'Elegir foto');

    expect(find.text('No se pudo revisar la foto con IA. Puedes publicar igual.'), findsOneWidget);
    expect(find.text('Cambiar foto'), findsOneWidget);
    expect(vm.fotoRutaLocal, foto);
    vm.dispose();
  });
}
