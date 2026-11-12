import 'package:equishare_flutter/contenedor.dart';
import 'package:equishare_flutter/domain/modelos.dart';
import 'package:equishare_flutter/ui/auth/completar_perfil_page.dart';
import 'package:equishare_flutter/ui/auth/login_page.dart';
import 'package:equishare_flutter/ui/auth/login_vm.dart';
import 'package:equishare_flutter/ui/auth/verificar_correo_page.dart';
import 'package:equishare_flutter/ui/perfil/perfil_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'falsos_cuenta.dart';

/// Pruebas funcionales de cuenta y seguridad (equivalen a SeguridadFuncionalTest y
/// CompletarPerfilIaFuncionalTest de Kotlin): se escribe y se toca la pantalla real.
void main() {
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

  Future<void> abrir(WidgetTester tester, Contenedor contenedor, Widget pantalla) async {
    await tester.pumpWidget(Provider<Contenedor>.value(value: contenedor, child: MaterialApp(home: pantalla)));
    await tester.pump();
    await tester.pump();
  }

  /// Espera a que terminen las animaciones de abrir o cerrar ventanas.
  Future<void> asentar(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
  }

  Future<void> tocar(WidgetTester tester, Finder objetivo) async {
    await tester.ensureVisible(objetivo);
    await tester.pump();
    await tester.tap(objetivo);
    await asentar(tester);
  }

  Finder campo(String etiqueta) => find.widgetWithText(TextField, etiqueta);

  testWidgets('registro: un correo mal escrito ofrece la corrección', (tester) async {
    await abrir(tester, contenedorDeCuenta(), const LoginPage());
    await tocar(tester, find.widgetWithText(TextButton, '¿Tu empresa es nueva? Crea una cuenta'));

    await tester.enterText(campo('Correo de la empresa'), 'ventas@gmai.com');
    await tester.pump();
    await tocar(tester, find.text('¿Quisiste decir ventas@gmail.com?'));

    expect(find.text('ventas@gmail.com'), findsOneWidget);
    expect(find.text('¿Quisiste decir ventas@gmail.com?'), findsNothing);
  });

  testWidgets('registro: muestra la fuerza de la contraseña', (tester) async {
    await abrir(tester, contenedorDeCuenta(), const LoginPage());
    await tocar(tester, find.widgetWithText(TextButton, '¿Tu empresa es nueva? Crea una cuenta'));

    await tester.enterText(campo('Contraseña'), 'clave2026');
    await tester.pump();
    expect(find.text('Seguridad de la contraseña: Media'), findsOneWidget);

    await tester.enterText(campo('Contraseña'), 'Clave2026!');
    await tester.pump();
    expect(find.text('Seguridad de la contraseña: Fuerte'), findsOneWidget);
  });

  testWidgets('"¿Olvidaste tu contraseña?" envía el enlace', (tester) async {
    final auth = AuthCuentaFalsa();
    await abrir(tester, contenedorDeCuenta(auth: auth), const LoginPage());
    await tester.enterText(campo('Correo de la empresa'), 'ventas@empresa.pe');
    await tester.pump();

    await tocar(tester, find.text('¿Olvidaste tu contraseña?'));
    expect(find.text('Recuperar contraseña'), findsOneWidget);
    await tocar(tester, find.text('Enviar enlace'));

    expect(auth.ultimoCorreoRecuperar, 'ventas@empresa.pe');
    expect(find.text(LoginViewModel.mensajeRecuperar), findsOneWidget);
    await tocar(tester, find.text('Entendido'));
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('"Revisa tu correo" no deja pasar hasta abrir el enlace', (tester) async {
    const sinVerificar = Sesion(uid: 'uid-1', email: 'ventas@empresa.pe', esDemo: false, correoVerificado: false);
    final auth = AuthCuentaFalsa(sesionInicial: sinVerificar, esModoDemo: false);
    await abrir(tester, contenedorDeCuenta(auth: auth), const VerificarCorreoPage());

    expect(find.text('Revisa tu correo'), findsOneWidget);
    await tocar(tester, find.text('Ya lo verifiqué'));
    expect(find.text(VerificarCorreoViewModel.todaviaNo), findsOneWidget);

    auth.correoYaVerificado = true;
    await tocar(tester, find.text('Ya lo verifiqué'));
    expect(find.text(VerificarCorreoViewModel.verificado), findsOneWidget);
    expect(auth.sesionActual?.correoVerificado, isTrue);
  });

  testWidgets('perfil: editar datos guarda la nueva razón social', (tester) async {
    final empresas = EmpresasCuentaFalsas()..miEmpresaActual = empresa;
    final auth = AuthCuentaFalsa(sesionInicial: verificada, esModoDemo: false);
    await abrir(tester, contenedorDeCuenta(auth: auth, empresas: empresas), const PerfilPage());
    expect(find.text('CN'), findsOneWidget); // iniciales de la empresa

    await tocar(tester, find.text('Editar datos de la empresa'));
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.enterText(campo('Razón social'), 'Constructora del Norte S.A.C.');
    await tocar(tester, find.text('Guardar'));

    expect(empresas.guardadas, [('20131312955', 'Constructora del Norte S.A.C.', '949123456')]);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(PerfilViewModel.datosActualizados), findsOneWidget);
  });

  testWidgets('perfil: eliminar la cuenta pide la contraseña y borra todo', (tester) async {
    final empresas = EmpresasCuentaFalsas()..miEmpresaActual = empresa;
    final auth = AuthCuentaFalsa(sesionInicial: verificada, esModoDemo: false);
    final favoritos = FavoritosCuentaFalsos();
    var limpiado = false;
    await abrir(
      tester,
      contenedorDeCuenta(auth: auth, empresas: empresas, favoritos: favoritos, limpiar: () async => limpiado = true),
      const PerfilPage(),
    );

    await tocar(tester, find.text('Eliminar mi cuenta'));
    await tocar(tester, find.text('Eliminar definitivamente'));
    expect(find.text('Escribe tu contraseña para confirmar.'), findsOneWidget);

    await tester.enterText(campo('Tu contraseña'), 'Clave2026');
    await tocar(tester, find.text('Eliminar definitivamente'));

    expect(auth.acciones, ['confirmarContrasena', 'eliminarUsuario']);
    expect(empresas.eliminada, isTrue);
    expect(favoritos.borrado, isTrue);
    expect(limpiado, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('registro de empresa: la foto de la ficha RUC llena los datos y permite continuar', (tester) async {
    final lector = LectorTextoFalso('Número de RUC: 20131312955 - CONSTRUCTORA EJEMPLO S.A.C.');
    final empresas = EmpresasCuentaFalsas();
    var termino = false;
    await abrir(
      tester,
      contenedorDeCuenta(lector: lector, empresas: empresas),
      CompletarPerfilPage(alTerminar: () => termino = true),
    );
    expect(find.text('Tomar foto'), findsOneWidget);
    expect(find.text('Elegir imagen'), findsOneWidget);

    // Equivale a elegir la foto en la galería (el selector del sistema no existe en las pruebas).
    tester.widget<LeerRucDesdeFoto>(find.byType(LeerRucDesdeFoto)).alElegirFoto('/fotos/ficha.jpg');
    await asentar(tester);

    expect(find.text('20131312955'), findsOneWidget);
    expect(find.text('CONSTRUCTORA EJEMPLO S.A.C.'), findsOneWidget);
    expect(find.text(CompletarPerfilViewModel.avisoCompleto), findsOneWidget);

    await tester.enterText(campo('Celular de contacto'), '949123456');
    await tocar(tester, find.text('Verificar y continuar'));
    expect(empresas.guardadas, [('20131312955', 'CONSTRUCTORA EJEMPLO S.A.C.', '949123456')]);
    expect(termino, isTrue);
  });
}
