import 'package:equishare_flutter/domain/ia/clasificador_equipo.dart';
import 'package:equishare_flutter/domain/modelos.dart';
import 'package:equishare_flutter/domain/repositorios.dart';
import 'package:equishare_flutter/ui/publicar/publicar_vm.dart';
import 'package:flutter_test/flutter_test.dart';

import 'falsos.dart';
import 'falsos_cuenta.dart';

/// Mismas pruebas de la versión Kotlin (PublicarIaViewModelTest y la búsqueda de dirección de
/// DisenoYMapaViewModelsTest), traducidas a Dart: la IA revisa la foto con un analizador falso.
void main() {
  final laptop = [EtiquetaFoto('Computer', 0.92)];
  final sillas = [EtiquetaFoto('Chair', 0.9), EtiquetaFoto('Tablecloth', 0.7)];

  PublicarViewModel crear(AnalizadorFotoFalso ia, {BuscadorDirecciones? buscador}) => PublicarViewModel(
        equipos: EquiposFalsos(),
        ubicacion: UbicacionFalsa(),
        analizador: ia,
        buscador: buscador ?? const BuscadorDireccionesNinguno(),
      );

  Categoria? categoriaSugerida(PublicarViewModel vm) {
    final r = vm.revisionIa;
    return r is IaLista ? r.sugerencia.categoria : null;
  }

  test('sin categoría elegida, la IA la elige sola', () async {
    final ia = AnalizadorFotoFalso(laptop);
    final vm = crear(ia);

    await vm.alElegirFoto('/fotos/laptop.jpg');

    expect(ia.pedidas, ['/fotos/laptop.jpg']);
    expect(categoriaSugerida(vm), Categoria.tecnologia);
    expect(vm.categoria, Categoria.tecnologia);
    expect(vm.categoriaPorIa, isTrue);
  });

  test('con una categoría elegida solo sugiere, y el botón la aplica', () async {
    final vm = crear(AnalizadorFotoFalso(laptop));
    vm.alElegirCategoria(Categoria.eventos);

    await vm.alElegirFoto('/fotos/laptop.jpg');
    expect(vm.categoria, Categoria.eventos);
    expect(vm.categoriaPorIa, isFalse);
    expect(categoriaSugerida(vm), Categoria.tecnologia);

    vm.usarSugerenciaIa();
    expect(vm.categoria, Categoria.tecnologia);
    expect(vm.categoriaPorIa, isTrue);
  });

  test('si la IA eligió y llega otra foto se actualiza, pero no si el usuario la cambió', () async {
    final ia = AnalizadorFotoFalso(laptop);
    final vm = crear(ia);
    await vm.alElegirFoto('/fotos/1.jpg');
    expect(vm.categoria, Categoria.tecnologia);

    ia.respuesta = sillas;
    await vm.alElegirFoto('/fotos/2.jpg');
    expect(vm.categoria, Categoria.eventos);

    vm.alElegirCategoria(Categoria.construccion);
    ia.respuesta = laptop;
    await vm.alElegirFoto('/fotos/3.jpg');
    expect(vm.categoria, Categoria.construccion);
    expect(vm.categoriaPorIa, isFalse);
  });

  test('mientras piensa muestra "Revisando", y un resultado viejo se ignora', () async {
    final ia = AnalizadorFotoFalso(sillas)..esperarEn = {'/fotos/lenta.jpg'};
    final vm = crear(ia);

    final lenta = vm.alElegirFoto('/fotos/lenta.jpg');
    expect(vm.revisionIa, isA<IaRevisando>());
    expect(vm.categoria, isNull);

    // Se elige otra foto antes de que la primera termine.
    await vm.alElegirFoto('/fotos/rapida.jpg');
    expect(vm.categoria, Categoria.eventos);

    // La respuesta de la foto vieja llega tarde y no debe cambiar nada.
    ia.responder('/fotos/lenta.jpg', laptop);
    await lenta;
    expect(vm.categoria, Categoria.eventos);
    expect(vm.fotoRutaLocal, '/fotos/rapida.jpg');
  });

  test('si la IA falla o lanza un error, no bloquea ni rompe la pantalla', () async {
    final falla = crear(AnalizadorFotoFalso(null));
    await falla.alElegirFoto('/fotos/x.jpg');
    expect(falla.revisionIa, isA<IaNoDisponible>());
    expect(falla.categoria, isNull);

    final ia = AnalizadorFotoFalso(laptop)..lanzar = StateError('modelo dañado');
    final explota = crear(ia);
    await explota.alElegirFoto('/fotos/y.jpg');
    expect(explota.revisionIa, isA<IaNoDisponible>());
    expect(explota.fotoRutaLocal, '/fotos/y.jpg');
  });

  test('una foto que no es un equipo no elige categoría', () async {
    final vm = crear(AnalizadorFotoFalso([EtiquetaFoto('Selfie', 0.9)]));
    await vm.alElegirFoto('/fotos/selfie.jpg');

    final revision = vm.revisionIa as IaLista;
    expect(revision.sugerencia.categoria, isNull);
    expect(revision.sugerencia.pareceOtraCosa, 'una selfie');
    expect(vm.categoria, isNull);
    expect(vm.categoriaPorIa, isFalse);
  });

  test('cancelar la selección de foto no llama a la IA', () async {
    final ia = AnalizadorFotoFalso(laptop);
    final vm = crear(ia);
    await vm.alElegirFoto(null);
    expect(ia.pedidas, isEmpty);
    expect(vm.revisionIa, isA<IaSinRevisar>());
  });

  test('publicar: busca la dirección y ubica el punto', () async {
    final pedidas = <String>[];
    final buscador = _BuscadorPrueba((direccion) {
      pedidas.add(direccion);
      return direccion.contains('España') ? const Coordenadas(-8.1093, -79.0289) : null;
    });
    final vm = crear(AnalizadorFotoFalso(), buscador: buscador);

    await vm.buscarDireccion();
    expect(vm.errorDireccion, 'Escribe la dirección para buscarla en el mapa.');
    expect(pedidas, isEmpty);

    vm.alCambiarDireccion('Av. España 1234, Trujillo');
    await vm.buscarDireccion();
    expect(vm.lat, closeTo(-8.1093, 1e-9));
    expect(vm.mensaje, PublicarViewModel.direccionEncontrada);

    vm.mensajeMostrado();
    vm.alCambiarDireccion('Calle que no existe 999');
    await vm.buscarDireccion();
    expect(vm.mensaje, PublicarViewModel.direccionNoEncontrada);
    expect(vm.lat, closeTo(-8.1093, 1e-9));
  });

  test('el precio solo acepta números, punto o coma (máximo 9 caracteres)', () {
    final vm = crear(AnalizadorFotoFalso());
    vm.alCambiarPrecio('S/ 80,50 por día');
    expect(vm.precio, '80,50');
    vm.alCambiarPrecio('12345678901');
    expect(vm.precio, '123456789');
  });
}

class _BuscadorPrueba implements BuscadorDirecciones {
  _BuscadorPrueba(this._responder);

  final Coordenadas? Function(String direccion) _responder;

  @override
  Future<Coordenadas?> buscar(String direccion) async => _responder(direccion);
}
