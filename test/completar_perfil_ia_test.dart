import 'package:equishare_flutter/ui/auth/completar_perfil_page.dart';
import 'package:flutter_test/flutter_test.dart';

import 'falsos_cuenta.dart';

/// Mismas pruebas de la versión Kotlin (CompletarPerfilIaViewModelTest), traducidas a Dart:
/// "Leer RUC desde una foto" en el registro de la empresa, con un lector de texto falso.
void main() {
  const textoConsultaRuc = 'Número de RUC: 20131312955 - CONSTRUCTORA EJEMPLO S.A.C.\nTipo Contribuyente: SOCIEDAD';

  CompletarPerfilViewModel crear(LectorTextoFalso lector, [EmpresasCuentaFalsas? empresas]) =>
      CompletarPerfilViewModel(empresas ?? EmpresasCuentaFalsas(), FavoritosCuentaFalsos(), AuthCuentaFalsa(), lector);

  test('foto con RUC y razón social: llena ambos y pide revisarlos', () async {
    final lector = LectorTextoFalso(textoConsultaRuc);
    final vm = crear(lector);

    await vm.alElegirFotoRuc('/fotos/ficha.jpg');

    expect(lector.pedidas, ['/fotos/ficha.jpg']);
    expect(vm.ruc, '20131312955');
    expect(vm.razonSocial, 'CONSTRUCTORA EJEMPLO S.A.C.');
    expect(vm.avisoFoto, CompletarPerfilViewModel.avisoCompleto);
    expect(vm.leyendoFoto, isFalse);
  });

  test('foto solo con RUC: llena el RUC y conserva la razón escrita', () async {
    final vm = crear(LectorTextoFalso('RUC 20600123450'));
    vm.alCambiarRazon('Mi Empresa SAC');

    await vm.alElegirFotoRuc('/fotos/ficha.jpg');

    expect(vm.ruc, '20600123450');
    expect(vm.razonSocial, 'Mi Empresa SAC');
    expect(vm.avisoFoto, CompletarPerfilViewModel.avisoSoloRuc);
  });

  test('foto sin un RUC válido: no cambia lo escrito y lo dice', () async {
    final vm = crear(LectorTextoFalso('RUC: 20131312956 - EMPRESA SAC'));
    vm.alCambiarRuc('2013');

    await vm.alElegirFotoRuc('/fotos/borrosa.jpg');

    expect(vm.ruc, '2013');
    expect(vm.razonSocial, '');
    expect(vm.avisoFoto, CompletarPerfilViewModel.avisoSinRuc);
  });

  test('si la IA no puede leer o lanza un error, avisa sin romper', () async {
    final sinLectura = crear(LectorTextoFalso(null));
    await sinLectura.alElegirFotoRuc('/fotos/x.jpg');
    expect(sinLectura.avisoFoto, CompletarPerfilViewModel.avisoSinLectura);
    expect(sinLectura.leyendoFoto, isFalse);

    final lector = LectorTextoFalso(textoConsultaRuc)..lanzar = StateError('modelo dañado');
    final conError = crear(lector);
    await conError.alElegirFotoRuc('/fotos/y.jpg');
    expect(conError.avisoFoto, CompletarPerfilViewModel.avisoSinLectura);
    expect(conError.ruc, '');
  });

  test('sin app de cámara sugiere usar la galería, y cancelar no llama a la IA', () async {
    final lector = LectorTextoFalso(textoConsultaRuc);
    final vm = crear(lector);

    vm.sinCamara();
    expect(vm.avisoFoto, CompletarPerfilViewModel.avisoSinCamara);

    await vm.alElegirFotoRuc(null);
    expect(lector.pedidas, isEmpty);
  });

  test('los datos leídos se guardan con el botón Verificar', () async {
    final empresas = EmpresasCuentaFalsas();
    final vm = crear(LectorTextoFalso(textoConsultaRuc), empresas);
    var termino = false;

    await vm.alElegirFotoRuc('/fotos/ficha.jpg');
    vm.alCambiarTelefono('949123456');
    await vm.guardar(() => termino = true);

    expect(termino, isTrue);
    expect(empresas.guardadas, [('20131312955', 'CONSTRUCTORA EJEMPLO S.A.C.', '949123456')]);
  });
}
