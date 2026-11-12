import '../../domain/modelos.dart';
import '../../domain/repositorios.dart';
import '../../domain/resultado.dart';
import '../../domain/validadores.dart';
import '../modelo_vista.dart';

class LoginViewModel extends ModeloVista {
  LoginViewModel(this._auth) : esModoDemo = _auth.esModoDemo;

  final AuthRepository _auth;
  final bool esModoDemo;

  static const String mensajeRecuperar =
      'Si existe una cuenta con ese correo, te enviamos un enlace para crear una contraseña nueva. '
      'Revisa también la carpeta de spam.';

  String email = '';
  String password = '';
  String confirmacion = '';
  bool modoRegistro = false;

  /// Casilla de consentimiento SIN marcar por defecto (diseño ético).
  bool aceptaPrivacidad = false;
  bool cargando = false;
  String? errorEmail;
  String? errorPassword;
  String? errorConfirmacion;
  String? errorPrivacidad;
  String? errorGeneral;

  /// Correo corregido cuando el dominio tiene un error común (por ejemplo "@gmai.com").
  String? sugerenciaCorreo;
  FuerzaPassword fuerzaPassword = FuerzaPassword.vacia;

  // "¿Olvidaste tu contraseña?"
  bool mostrarRecuperar = false;
  String emailRecuperar = '';
  bool enviandoRecuperar = false;
  String? errorRecuperar;
  String? mensajeRecuperarEnviado;

  void alCambiarEmail(String v) {
    email = v;
    errorEmail = null;
    errorGeneral = null;
    sugerenciaCorreo = Validadores.sugerenciaCorreo(v);
    avisar();
  }

  void alCambiarPassword(String v) {
    password = v;
    errorPassword = null;
    errorGeneral = null;
    fuerzaPassword = Validadores.fuerzaPassword(v);
    avisar();
  }

  /// Toque en "¿Quisiste decir ...?": cambia el correo por el corregido.
  void usarSugerenciaCorreo() {
    final sugerencia = sugerenciaCorreo;
    if (sugerencia == null) return;
    email = sugerencia;
    sugerenciaCorreo = null;
    errorEmail = null;
    avisar();
  }

  void abrirRecuperar() {
    mostrarRecuperar = true;
    emailRecuperar = email.trim();
    errorRecuperar = null;
    mensajeRecuperarEnviado = null;
    avisar();
  }

  void alCambiarEmailRecuperar(String v) {
    emailRecuperar = v;
    errorRecuperar = null;
    avisar();
  }

  void cerrarRecuperar() {
    if (enviandoRecuperar) return;
    mostrarRecuperar = false;
    avisar();
  }

  /// Envía el enlace para crear una contraseña nueva. Responde igual exista o no la cuenta.
  Future<void> enviarRecuperar() async {
    if (enviandoRecuperar) return;
    final error = Validadores.email(emailRecuperar);
    if (error != null) {
      errorRecuperar = error;
      avisar();
      return;
    }
    enviandoRecuperar = true;
    errorRecuperar = null;
    mensajeRecuperarEnviado = null;
    avisar();
    final r = await _auth.recuperarContrasena(emailRecuperar.trim());
    if (cerrado) return;
    enviandoRecuperar = false;
    if (r.esExito) {
      mensajeRecuperarEnviado = mensajeRecuperar;
    } else {
      errorRecuperar = r.errorONull!.mensaje;
    }
    avisar();
  }

  void alCambiarConfirmacion(String v) {
    confirmacion = v;
    errorConfirmacion = null;
    avisar();
  }

  void alCambiarPrivacidad(bool v) {
    aceptaPrivacidad = v;
    errorPrivacidad = null;
    avisar();
  }

  void alternarModo() {
    modoRegistro = !modoRegistro;
    errorGeneral = null;
    errorConfirmacion = null;
    errorPrivacidad = null;
    avisar();
  }

  /// Valida el formulario; devuelve true si se puede enviar.
  bool validar() {
    // Al crear la cuenta no se acepta un dominio mal escrito: a ese correo nunca llegaría la verificación.
    final sugerencia = sugerenciaCorreo;
    errorEmail = Validadores.email(email) ??
        ((modoRegistro && sugerencia != null) ? 'Revisa el correo. ¿Quisiste decir $sugerencia?' : null);
    errorPassword = Validadores.password(password);
    errorConfirmacion = modoRegistro ? Validadores.confirmacion(password, confirmacion) : null;
    errorPrivacidad = (modoRegistro && !aceptaPrivacidad)
        ? 'Debes leer y aceptar la política de privacidad para crear la cuenta.'
        : null;
    avisar();
    return errorEmail == null && errorPassword == null && errorConfirmacion == null && errorPrivacidad == null;
  }

  Future<void> enviar(void Function(String email) alRegistrar) async {
    if (cargando || !validar()) return;
    final esRegistro = modoRegistro;
    final correo = email;
    final clave = password;
    cargando = true;
    errorGeneral = null;
    avisar();

    final r = esRegistro ? await _auth.registrar(correo, clave) : await _auth.iniciarSesion(correo, clave);
    if (cerrado) return;
    if (r is Fallo<Sesion>) {
      cargando = false;
      errorGeneral = r.error.mensaje;
      avisar();
      return;
    }
    // Se limpia el formulario: la contraseña no queda en memoria tras ingresar.
    _reiniciar();
    avisar();
    if (esRegistro) alRegistrar(correo.trim());
  }

  void _reiniciar() {
    email = '';
    password = '';
    confirmacion = '';
    modoRegistro = false;
    aceptaPrivacidad = false;
    cargando = false;
    errorEmail = null;
    errorPassword = null;
    errorConfirmacion = null;
    errorPrivacidad = null;
    errorGeneral = null;
    sugerenciaCorreo = null;
    fuerzaPassword = FuerzaPassword.vacia;
    mostrarRecuperar = false;
    emailRecuperar = '';
    enviandoRecuperar = false;
    errorRecuperar = null;
    mensajeRecuperarEnviado = null;
  }
}
