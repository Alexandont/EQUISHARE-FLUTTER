import 'package:equishare_flutter/domain/modelos.dart';
import 'package:equishare_flutter/domain/resultado.dart';
import 'package:equishare_flutter/domain/validadores.dart';
import 'package:equishare_flutter/ui/auth/login_vm.dart';
import 'package:equishare_flutter/ui/auth/verificar_correo_page.dart';
import 'package:equishare_flutter/ui/perfil/perfil_page.dart';
import 'package:equishare_flutter/ui/raiz/raiz_page.dart';
import 'package:flutter_test/flutter_test.dart';

import 'falsos_cuenta.dart';

/// Mismas pruebas de la versión Kotlin (SeguridadViewModelsTest), traducidas a Dart:
/// verificación de correo, registro, contraseña y eliminar la cuenta.
void main() {
  const sinVerificar = Sesion(uid: 'uid-1', email: 'ventas@empresa.pe', esDemo: false, correoVerificado: false);
  const verificada = Sesion(uid: 'uid-1', email: 'ventas@empresa.pe', esDemo: false, correoVerificado: true);
  const empresa = Empresa(
    id: 'uid-1',
    razonSocial: 'Constructora Norte S.A.C.',
    ruc: '20131312955',
    telefono: '949123456',
    email: 'ventas@empresa.pe',
    verificada: true,
    calificacionComoArrendatario: 0,
    totalResenasComoArrendatario: 0,
  );

  // ---------- Verificación del correo ----------

  test('raíz: una cuenta sin verificar va a la pantalla "Revisa tu correo"', () async {
    final auth = AuthCuentaFalsa(sesionInicial: sinVerificar);
    final vm = RaizViewModel(auth, EmpresasCuentaFalsas()..miEmpresaActual = empresa, FavoritosCuentaFalsos());
    await esperarTareas();
    expect(vm.estado, isA<RaizCorreoSinVerificar>());
    expect((vm.estado as RaizCorreoSinVerificar).sesion, sinVerificar);

    // Al verificar, la sesión cambia y la app sigue sola a la pantalla principal.
    auth.correoYaVerificado = true;
    await auth.revisarVerificacion();
    await esperarTareas();
    final listo = vm.estado as RaizListo;
    expect(listo.sesion, verificada);
    expect(listo.empresa, empresa);
    vm.dispose();
  });

  test('verificar: si todavía no abrió el enlace, lo dice', () async {
    final auth = AuthCuentaFalsa(sesionInicial: sinVerificar);
    final vm = VerificarCorreoViewModel(auth);
    await esperarTareas();
    expect(vm.mensaje, isNull); // la revisión automática al abrir no muestra errores
    expect(vm.email, 'ventas@empresa.pe');

    await vm.revisar();
    expect(vm.mensaje, VerificarCorreoViewModel.todaviaNo);
    expect(vm.esError, isTrue);

    auth.correoYaVerificado = true;
    await vm.revisar();
    expect(vm.mensaje, VerificarCorreoViewModel.verificado);
    expect(vm.esError, isFalse);
    vm.dispose();
  });

  test('verificar: reenviar espera un minuto entre correos', () async {
    final auth = AuthCuentaFalsa(sesionInicial: sinVerificar);
    var ahora = 1000000;
    final vm = VerificarCorreoViewModel(auth, reloj: () => ahora);
    await esperarTareas();
    int enviados() => auth.acciones.where((a) => a == 'enviarVerificacion').length;

    await vm.reenviar();
    expect(vm.mensaje, VerificarCorreoViewModel.reenviado);
    expect(vm.segundosParaReenviar(), 60);

    ahora += 15000;
    await vm.reenviar();
    expect(vm.mensaje, 'Espera 45 s para pedir otro correo.');
    expect(enviados(), 1);

    ahora += 45000;
    expect(vm.segundosParaReenviar(), 0);
    await vm.reenviar();
    expect(enviados(), 2);
    vm.dispose();
  });

  // ---------- Registro e inicio de sesión ----------

  test('registro: con un correo mal escrito no crea la cuenta y ofrece corregirlo', () async {
    final auth = AuthCuentaFalsa();
    final vm = LoginViewModel(auth);
    vm.alternarModo();
    vm.alCambiarEmail('alexan.terronesmiranda9@gmai.com');
    vm.alCambiarPassword('Clave2026!');
    vm.alCambiarConfirmacion('Clave2026!');
    vm.alCambiarPrivacidad(true);
    expect(vm.sugerenciaCorreo, 'alexan.terronesmiranda9@gmail.com');
    expect(vm.fuerzaPassword, FuerzaPassword.fuerte);

    await vm.enviar((_) {});
    expect(auth.llamadas, 0);
    expect(vm.errorEmail, 'Revisa el correo. ¿Quisiste decir alexan.terronesmiranda9@gmail.com?');

    vm.usarSugerenciaCorreo();
    expect(vm.email, 'alexan.terronesmiranda9@gmail.com');
    await vm.enviar((_) {});
    expect(auth.llamadas, 1);
  });

  test('olvidé mi contraseña: valida el correo y siempre responde igual', () async {
    final auth = AuthCuentaFalsa();
    final vm = LoginViewModel(auth);
    vm.alCambiarEmail('ventas@empresa.pe');
    vm.abrirRecuperar();
    expect(vm.mostrarRecuperar, isTrue);
    expect(vm.emailRecuperar, 'ventas@empresa.pe');

    vm.alCambiarEmailRecuperar('correo-malo');
    await vm.enviarRecuperar();
    expect(vm.errorRecuperar, 'El correo no tiene un formato válido.');
    expect(auth.ultimoCorreoRecuperar, isNull);

    vm.alCambiarEmailRecuperar(' ventas@empresa.pe ');
    await vm.enviarRecuperar();
    expect(auth.ultimoCorreoRecuperar, 'ventas@empresa.pe');
    expect(vm.mensajeRecuperarEnviado, LoginViewModel.mensajeRecuperar);

    vm.cerrarRecuperar();
    expect(vm.mostrarRecuperar, isFalse);
  });

  // ---------- Perfil: mi cuenta ----------

  Future<PerfilViewModel> perfil({
    AuthCuentaFalsa? auth,
    EmpresasCuentaFalsas? empresas,
    FavoritosCuentaFalsos? favoritos,
    void Function()? alLimpiar,
  }) async {
    final vm = PerfilViewModel(
      empresas ?? (EmpresasCuentaFalsas()..miEmpresaActual = empresa),
      auth ?? AuthCuentaFalsa(sesionInicial: verificada, esModoDemo: false),
      favoritos ?? FavoritosCuentaFalsos(),
      () async => alLimpiar?.call(),
    );
    await esperarTareas();
    return vm;
  }

  test('editar datos: valida y guarda sin cambiar el RUC', () async {
    final empresas = EmpresasCuentaFalsas()..miEmpresaActual = empresa;
    final vm = await perfil(empresas: empresas);
    vm.abrirDialogo(DialogoCuenta.editarDatos);

    await vm.guardarDatos('Constructora Norte S.A.C.', '12345');
    expect(vm.errorDialogo, 'Ingresa un celular de 9 dígitos que empiece con 9.');
    expect(empresas.guardadas, isEmpty);

    await vm.guardarDatos('  Constructora del Norte S.A.C. ', '987654321');
    expect(empresas.guardadas, [('20131312955', 'Constructora del Norte S.A.C.', '987654321')]);
    expect(vm.dialogo, isNull);
    expect(vm.mensaje, PerfilViewModel.datosActualizados);
    expect(vm.empresa?.razonSocial, 'Constructora del Norte S.A.C.');
  });

  test('cambiar contraseña: valida antes de llamar y muestra el error del proveedor', () async {
    final auth = AuthCuentaFalsa(sesionInicial: verificada, esModoDemo: false);
    final vm = await perfil(auth: auth);
    vm.abrirDialogo(DialogoCuenta.cambiarContrasena);

    await vm.cambiarContrasena('Clave2026', 'Clave2026', 'Clave2026');
    expect(vm.errorDialogo, 'La contraseña nueva debe ser distinta de la actual.');
    await vm.cambiarContrasena('Clave2026', 'Nueva2027!', 'Otra2027!');
    expect(vm.errorDialogo, 'Las contraseñas no coinciden.');
    expect(auth.acciones, isEmpty);

    auth.errores['cambiarContrasena'] = ErrorApp(TipoError.noAutenticado, mensaje: 'La contraseña no es correcta.');
    await vm.cambiarContrasena('Mala2026', 'Nueva2027!', 'Nueva2027!');
    expect(vm.errorDialogo, 'La contraseña no es correcta.');
    expect(vm.dialogo, DialogoCuenta.cambiarContrasena);

    auth.errores.clear();
    await vm.cambiarContrasena('Clave2026', 'Nueva2027!', 'Nueva2027!');
    expect(vm.dialogo, isNull);
    expect(vm.mensaje, PerfilViewModel.contrasenaCambiada);
  });

  test('eliminar cuenta: con reservas activas se detiene sin borrar nada', () async {
    final auth = AuthCuentaFalsa(sesionInicial: verificada, esModoDemo: false);
    final empresas = EmpresasCuentaFalsas()
      ..miEmpresaActual = empresa
      ..errorEliminar = ErrorApp(
        TipoError.conflicto,
        mensaje: 'Tienes 1 reserva(s) activa(s). Termínalas o cancélalas antes de eliminar tu cuenta.',
      );
    final favoritos = FavoritosCuentaFalsos();
    var limpiado = false;
    final vm = await perfil(auth: auth, empresas: empresas, favoritos: favoritos, alLimpiar: () => limpiado = true);
    vm.abrirDialogo(DialogoCuenta.eliminarCuenta);

    await vm.eliminarCuenta('');
    expect(vm.errorDialogo, 'Escribe tu contraseña para confirmar.');

    await vm.eliminarCuenta('Clave2026');
    expect(vm.errorDialogo, 'Tienes 1 reserva(s) activa(s). Termínalas o cancélalas antes de eliminar tu cuenta.');
    expect(auth.acciones, ['confirmarContrasena']);
    expect(favoritos.borrado, isFalse);
    expect(limpiado, isFalse);
    expect(auth.sesionActual, verificada);
  });

  test('eliminar cuenta: con la contraseña incorrecta no toca el servidor', () async {
    final auth = AuthCuentaFalsa(sesionInicial: verificada, esModoDemo: false)
      ..errores['confirmarContrasena'] = ErrorApp(TipoError.noAutenticado, mensaje: 'La contraseña no es correcta.');
    final empresas = EmpresasCuentaFalsas()..miEmpresaActual = empresa;
    final vm = await perfil(auth: auth, empresas: empresas);

    await vm.eliminarCuenta('Mala2026');
    expect(vm.errorDialogo, 'La contraseña no es correcta.');
    expect(empresas.eliminada, isFalse);
  });

  test('eliminar cuenta: borra todo en orden y cierra la sesión', () async {
    final auth = AuthCuentaFalsa(sesionInicial: verificada, esModoDemo: false);
    final empresas = EmpresasCuentaFalsas()..miEmpresaActual = empresa;
    final favoritos = FavoritosCuentaFalsos();
    var limpiado = false;
    final vm = await perfil(auth: auth, empresas: empresas, favoritos: favoritos, alLimpiar: () => limpiado = true);
    vm.abrirDialogo(DialogoCuenta.eliminarCuenta);

    await vm.eliminarCuenta('Clave2026');

    expect(auth.acciones, ['confirmarContrasena', 'eliminarUsuario']);
    expect(empresas.eliminada, isTrue);
    expect(favoritos.borrado, isTrue);
    expect(limpiado, isTrue);
    expect(auth.sesionActual, isNull);
    expect(vm.dialogo, isNull);
  });
}
