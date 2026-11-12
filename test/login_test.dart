import 'package:equishare_flutter/contenedor.dart';
import 'package:equishare_flutter/ui/auth/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'falsos.dart';

/// Pruebas funcionales del inicio de sesión y registro: se escribe y se toca la pantalla real.
void main() {
  Future<void> abrirLogin(WidgetTester tester, AuthFalso auth, {void Function(String)? alRegistrarse}) async {
    await tester.pumpWidget(
      Provider<Contenedor>.value(
        value: contenedorDePrueba(auth: auth),
        child: MaterialApp(home: LoginPage(alRegistrarse: alRegistrarse)),
      ),
    );
    await tester.pump();
  }

  Finder campo(String etiqueta) => find.widgetWithText(TextField, etiqueta);

  Future<void> tocar(WidgetTester tester, Finder objetivo) async {
    await tester.ensureVisible(objetivo);
    await tester.pump();
    await tester.tap(objetivo);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('formulario vacío: muestra errores y no llama al servidor', (tester) async {
    final auth = AuthFalso();
    await abrirLogin(tester, auth);

    await tocar(tester, find.widgetWithText(FilledButton, 'Ingresar'));

    expect(find.text('Ingresa tu correo.'), findsOneWidget);
    expect(find.text('La contraseña debe tener al menos 8 caracteres.'), findsOneWidget);
    expect(auth.llamadas, 0);
  });

  testWidgets('datos con formato incorrecto: mensajes claros', (tester) async {
    final auth = AuthFalso();
    await abrirLogin(tester, auth);

    await tester.enterText(campo('Correo de la empresa'), 'correo-sin-arroba');
    await tester.enterText(campo('Contraseña'), 'solotexto');
    await tocar(tester, find.widgetWithText(FilledButton, 'Ingresar'));

    expect(find.text('El correo no tiene un formato válido.'), findsOneWidget);
    expect(find.text('Usa letras y números en la contraseña.'), findsOneWidget);
    expect(auth.llamadas, 0);
  });

  testWidgets('datos válidos: inicia sesión y limpia el formulario', (tester) async {
    final auth = AuthFalso();
    await abrirLogin(tester, auth);

    await tester.enterText(campo('Correo de la empresa'), 'eventos@demo.pe');
    await tester.enterText(campo('Contraseña'), 'clave2026');
    await tocar(tester, find.widgetWithText(FilledButton, 'Ingresar'));

    expect(auth.llamadas, 1);
    expect(auth.ultimoEmail, 'eventos@demo.pe');
    // Por privacidad, el formulario se vacía después de ingresar.
    expect(find.text('eventos@demo.pe'), findsNothing);
  });

  testWidgets('credenciales incorrectas: muestra el error del servidor', (tester) async {
    await abrirLogin(tester, AuthFalso(fallar: true));

    await tester.enterText(campo('Correo de la empresa'), 'eventos@demo.pe');
    await tester.enterText(campo('Contraseña'), 'clave9999');
    await tocar(tester, find.widgetWithText(FilledButton, 'Ingresar'));

    expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
  });

  testWidgets('el botón del ojo muestra y oculta la contraseña', (tester) async {
    await abrirLogin(tester, AuthFalso());

    await tocar(tester, find.byTooltip('Mostrar contraseña'));
    expect(find.byTooltip('Ocultar contraseña'), findsOneWidget);

    await tocar(tester, find.byTooltip('Ocultar contraseña'));
    expect(find.byTooltip('Mostrar contraseña'), findsOneWidget);
  });

  testWidgets('registro: exige contraseñas iguales y aceptar la privacidad', (tester) async {
    final auth = AuthFalso();
    final registrados = <String>[];
    await abrirLogin(tester, auth, alRegistrarse: registrados.add);

    await tocar(tester, find.widgetWithText(TextButton, '¿Tu empresa es nueva? Crea una cuenta'));
    await tester.enterText(campo('Correo de la empresa'), 'nueva@empresa.pe');
    await tester.enterText(campo('Contraseña'), 'clave2026');
    await tester.enterText(campo('Repite la contraseña'), 'clave2027');
    await tocar(tester, find.widgetWithText(FilledButton, 'Crear cuenta'));

    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
    expect(find.text('Debes leer y aceptar la política de privacidad para crear la cuenta.'), findsOneWidget);
    expect(auth.llamadas, 0);

    await tester.enterText(campo('Repite la contraseña'), 'clave2026');
    await tocar(tester, find.byType(Checkbox));
    await tocar(tester, find.widgetWithText(FilledButton, 'Crear cuenta'));

    expect(auth.llamadas, 1);
    expect(registrados, ['nueva@empresa.pe']);
  });

  testWidgets('el enlace de privacidad abre y cierra la política', (tester) async {
    await abrirLogin(tester, AuthFalso());

    await tocar(tester, find.widgetWithText(TextButton, '¿Tu empresa es nueva? Crea una cuenta'));
    await tocar(tester, find.widgetWithText(TextButton, 'política de privacidad'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Política de privacidad'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cerrar'));
    // En Flutter 3.47 la animación de cierre del diálogo dura más de 300 ms:
    // se espera a que termine y a que el diálogo se quite de la pantalla.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('Política de privacidad'), findsNothing);
  });
}
