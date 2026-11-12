import 'compat_kotlin.dart';

/// Validaciones de formularios. Cada función devuelve el mensaje de error o null si el valor es válido.
/// Son las mismas reglas que aplica la API, para avisar al instante sin gastar datos.
class Validadores {
  Validadores._();

  static final RegExp _email = RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');
  static final RegExp _soloDigitos = RegExp(r'^[0-9]+$');
  static final RegExp _celular = RegExp(r'^9[0-9]{8}$');
  static final RegExp _url = RegExp(r'^https?://[A-Za-z0-9.-]+(:[0-9]{1,5})?(/[A-Za-z0-9._~/-]*)?$');
  static const List<int> _pesosRuc = [5, 4, 3, 2, 7, 6, 5, 4, 3, 2];
  static const Set<String> _prefijosRuc = {'10', '15', '16', '17', '20'};

  static String? email(String valor) {
    if (valor.trim().isEmpty) return 'Ingresa tu correo.';
    if (!_email.hasMatch(valor.trim())) return 'El correo no tiene un formato válido.';
    return null;
  }

  static String? password(String valor) {
    if (valor.length < 8) return 'La contraseña debe tener al menos 8 caracteres.';
    if (!algunCaracter(valor, esLetra) || !algunCaracter(valor, esDigito)) {
      return 'Usa letras y números en la contraseña.';
    }
    return null;
  }

  /// Qué tan difícil de adivinar es la contraseña. DÉBIL si no cumple la regla mínima
  /// (8 caracteres con letras y números). Suma puntos por 12 caracteres o más,
  /// mayúsculas y minúsculas juntas, y símbolos.
  static FuerzaPassword fuerzaPassword(String valor) {
    if (valor.isEmpty) return FuerzaPassword.vacia;
    if (password(valor) != null) return FuerzaPassword.debil;
    final puntos = [
      valor.length >= 12,
      algunCaracter(valor, esMayuscula) && algunCaracter(valor, esMinuscula),
      algunCaracter(valor, (c) => !esLetraODigito(c)),
    ].where((cumple) => cumple).length;
    return puntos >= 2 ? FuerzaPassword.fuerte : FuerzaPassword.media;
  }

  /// Dominios de correo mal escritos que se ven a menudo, con su forma correcta.
  static const Map<String, String> _dominiosCorregidos = {
    'gmai.com': 'gmail.com', 'gmial.com': 'gmail.com', 'gmal.com': 'gmail.com',
    'gamil.com': 'gmail.com', 'gnail.com': 'gmail.com', 'gmail.co': 'gmail.com',
    'gmail.con': 'gmail.com', 'gmail.cm': 'gmail.com', 'gmail.om': 'gmail.com',
    'gmaill.com': 'gmail.com', 'gmail.es': 'gmail.com',
    'hotmial.com': 'hotmail.com', 'hotmal.com': 'hotmail.com', 'hotmai.com': 'hotmail.com',
    'homail.com': 'hotmail.com', 'hotmail.co': 'hotmail.com', 'hotmail.con': 'hotmail.com',
    'outlok.com': 'outlook.com', 'outllok.com': 'outlook.com', 'outlook.co': 'outlook.com',
    'outlook.con': 'outlook.com',
    'yaho.com': 'yahoo.com', 'yahoo.co': 'yahoo.com', 'yahoo.con': 'yahoo.com',
    'iclod.com': 'icloud.com', 'icloud.co': 'icloud.com',
  };

  /// Si el dominio del correo tiene un error común (por ejemplo "gmai.com"), devuelve el correo
  /// corregido ("...@gmail.com"). Si no hay nada que corregir, devuelve null.
  static String? sugerenciaCorreo(String valor) {
    final correo = valor.trim().toLowerCase();
    final arroba = correo.lastIndexOf('@');
    if (arroba <= 0 || arroba == correo.length - 1) return null;
    final correcto = _dominiosCorregidos[correo.substring(arroba + 1)];
    if (correcto == null) return null;
    return '${correo.substring(0, arroba + 1)}$correcto';
  }

  static String? confirmacion(String password, String confirmacion) =>
      password != confirmacion ? 'Las contraseñas no coinciden.' : null;

  /// Igual que Kotlin: usa (carácter - '0') de cada uno de los 10 primeros caracteres.
  static int digitoVerificadorRuc(String primeros10) {
    var suma = 0;
    for (var i = 0; i < primeros10.length; i++) {
      suma += (primeros10.codeUnitAt(i) - 48) * _pesosRuc[i];
    }
    final resultado = 11 - (suma % 11);
    if (resultado == 10) return 0;
    if (resultado == 11) return 1;
    return resultado;
  }

  static String? ruc(String valor) {
    final r = valor.trim();
    if (r.length != 11 || !_soloDigitos.hasMatch(r)) return 'El RUC debe tener 11 dígitos.';
    if (!_prefijosRuc.contains(r.substring(0, 2))) return 'El RUC debe empezar con 10, 15, 16, 17 o 20.';
    if (digitoVerificadorRuc(r.substring(0, 10)) != r.codeUnitAt(10) - 48) {
      return 'El dígito verificador del RUC no es correcto.';
    }
    return null;
  }

  static String? telefono(String valor) =>
      _celular.hasMatch(valor.trim()) ? null : 'Ingresa un celular de 9 dígitos que empiece con 9.';

  static String? _largo(String valor, int min, int max, String mensaje) {
    final n = valor.trim().length;
    return (n < min || n > max) ? mensaje : null;
  }

  static String? razonSocial(String v) => _largo(v, 3, 120, 'La razón social debe tener entre 3 y 120 caracteres.');

  static String? nombreEquipo(String v) => _largo(v, 3, 80, 'El nombre debe tener entre 3 y 80 caracteres.');

  static String? descripcion(String v) => _largo(v, 10, 500, 'La descripción debe tener entre 10 y 500 caracteres.');

  static String? direccion(String v) => _largo(v, 5, 150, 'La dirección debe tener entre 5 y 150 caracteres.');

  static String? comentario(String v) => _largo(v, 3, 300, 'El comentario debe tener entre 3 y 300 caracteres.');

  /// Acepta coma o punto decimal.
  static double? precioComoNumero(String valor) => double.tryParse(valor.trim().replaceAll(',', '.'));

  static String? precio(String valor) {
    final numero = precioComoNumero(valor);
    if (numero == null) return 'Ingresa un precio válido.';
    if (numero < 1.0 || numero > 50000.0) return 'El precio por día debe estar entre S/ 1 y S/ 50 000.';
    return null;
  }

  static String? estrellas(int valor) => (valor < 1 || valor > 5) ? 'Elige de 1 a 5 estrellas.' : null;

  /// Normaliza la URL del servidor: agrega http:// y la barra final.
  static String? normalizarUrlServidor(String valor) {
    var url = valor.trim();
    if (url.isEmpty) return null;
    if (!url.startsWith('http://') && !url.startsWith('https://')) url = 'http://$url';
    if (!url.endsWith('/')) url = '$url/';
    return _url.hasMatch(url) ? url : null;
  }
}

/// Fuerza de la contraseña para el indicador de colores del registro.
enum FuerzaPassword {
  vacia('', 0.0),
  debil('Débil', 0.33),
  media('Media', 0.66),
  fuerte('Fuerte', 1.0);

  const FuerzaPassword(this.etiqueta, this.progreso);
  final String etiqueta;
  final double progreso;
}
