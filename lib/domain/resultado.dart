/// Tipos de error que la app sabe explicar al usuario con un mensaje claro.
enum TipoError {
  sinConexion,
  tiempoAgotado,
  noAutenticado,
  prohibido,
  noEncontrado,
  conflicto,
  validacion,
  reglaNegocio,
  servidor,
  desconocido;

  /// Traduce un código HTTP de la API a un tipo de error de la app.
  static TipoError desdeCodigoHttp(int codigo) {
    if (codigo == 400 || codigo == 413 || codigo == 415) return TipoError.validacion;
    if (codigo == 401) return TipoError.noAutenticado;
    if (codigo == 403) return TipoError.prohibido;
    if (codigo == 404) return TipoError.noEncontrado;
    if (codigo == 409) return TipoError.conflicto;
    if (codigo == 422) return TipoError.reglaNegocio;
    if (codigo >= 500 && codigo <= 599) return TipoError.servidor;
    return TipoError.desconocido;
  }

  String get mensajePorDefecto => switch (this) {
        TipoError.sinConexion => 'Sin conexión con el servidor. Revisa tu internet o la dirección del servidor.',
        TipoError.tiempoAgotado => 'El servidor tardó demasiado en responder. Inténtalo de nuevo.',
        TipoError.noAutenticado => 'Tu sesión expiró. Vuelve a iniciar sesión.',
        TipoError.prohibido => 'No tienes permiso para realizar esta acción.',
        TipoError.noEncontrado => 'El recurso solicitado no existe.',
        TipoError.conflicto => 'La operación entra en conflicto con datos existentes.',
        TipoError.validacion => 'Revisa los datos ingresados.',
        TipoError.reglaNegocio => 'La operación no cumple una regla del negocio.',
        TipoError.servidor => 'Ocurrió un error en el servidor. Inténtalo más tarde.',
        TipoError.desconocido => 'Ocurrió un error inesperado.',
      };
}

/// Error controlado: nunca se muestra una excepción técnica al usuario.
class ErrorApp {
  ErrorApp(this.tipo, {String? mensaje, this.codigo, this.detalles = const []})
      : mensaje = mensaje ?? tipo.mensajePorDefecto;

  final TipoError tipo;
  final String mensaje;
  final String? codigo;
  final List<String> detalles;

  @override
  String toString() => 'ErrorApp($tipo, $mensaje)';
}

/// Resultado de una operación: éxito con datos o fallo con un error controlado.
sealed class Resultado<T> {
  const Resultado();
}

final class Exito<T> extends Resultado<T> {
  const Exito(this.datos);
  final T datos;
}

final class Fallo<T> extends Resultado<T> {
  const Fallo(this.error);
  final ErrorApp error;
}

extension ResultadoX<T> on Resultado<T> {
  T? get datosONull {
    final r = this;
    return r is Exito<T> ? r.datos : null;
  }

  ErrorApp? get errorONull {
    final r = this;
    return r is Fallo<T> ? r.error : null;
  }

  bool get esExito => this is Exito<T>;

  /// Transforma los datos si es éxito; si es fallo, conserva el mismo error.
  Resultado<R> mapear<R>(R Function(T datos) transformar) {
    final r = this;
    return r is Exito<T> ? Exito<R>(transformar(r.datos)) : Fallo<R>((r as Fallo<T>).error);
  }

  /// Ejecuta [accion] con los datos solo si es éxito y devuelve el mismo resultado.
  Resultado<T> alExito(void Function(T datos) accion) {
    final r = this;
    if (r is Exito<T>) accion(r.datos);
    return this;
  }
}
