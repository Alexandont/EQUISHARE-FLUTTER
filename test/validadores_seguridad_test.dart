import 'package:equishare_flutter/domain/validadores.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mismas pruebas de la versión Kotlin (ValidadoresSeguridadTest), traducidas a Dart.
void main() {
  test('la fuerza de la contraseña va de débil a fuerte', () {
    expect(Validadores.fuerzaPassword(''), FuerzaPassword.vacia);
    expect(Validadores.fuerzaPassword('abc12'), FuerzaPassword.debil);
    expect(Validadores.fuerzaPassword('solotexto'), FuerzaPassword.debil);
    expect(Validadores.fuerzaPassword('clave2026'), FuerzaPassword.media);
    expect(Validadores.fuerzaPassword('Clave2026'), FuerzaPassword.media);
    expect(Validadores.fuerzaPassword('Clave2026!'), FuerzaPassword.fuerte);
    expect(Validadores.fuerzaPassword('equishare2026trujillo!'), FuerzaPassword.fuerte);
  });

  test('un correo con el dominio mal escrito sugiere el correcto', () {
    expect(Validadores.sugerenciaCorreo('alexan.terronesmiranda9@gmai.com'), 'alexan.terronesmiranda9@gmail.com');
    expect(Validadores.sugerenciaCorreo(' Ventas@GMIAL.com '), 'ventas@gmail.com');
    expect(Validadores.sugerenciaCorreo('ventas@hotmial.com'), 'ventas@hotmail.com');
    expect(Validadores.sugerenciaCorreo('ventas@outlok.com'), 'ventas@outlook.com');
    expect(Validadores.sugerenciaCorreo('ventas@gmail.con'), 'ventas@gmail.com');
  });

  test('un correo correcto o de empresa no sugiere nada', () {
    expect(Validadores.sugerenciaCorreo('alexan.terronesmiranda9@gmail.com'), isNull);
    expect(Validadores.sugerenciaCorreo('ventas@constructora.com.pe'), isNull);
    expect(Validadores.sugerenciaCorreo('eventos@demo.pe'), isNull);
    expect(Validadores.sugerenciaCorreo('sin-arroba'), isNull);
    expect(Validadores.sugerenciaCorreo('@gmai.com'), isNull);
    expect(Validadores.sugerenciaCorreo('ventas@'), isNull);
  });
}
