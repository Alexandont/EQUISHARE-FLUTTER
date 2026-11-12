// Modelos del dominio de EQUISHARE (mismos valores y nombres de campos que la API REST).

double _num(Object? v) => v is num ? v.toDouble() : (double.tryParse('${v ?? ''}') ?? 0.0);
double? _numONull(Object? v) => v == null ? null : _num(v);
int _entero(Object? v) => v is num ? v.toInt() : (int.tryParse('${v ?? ''}') ?? 0);
String _texto(Object? v) => v == null ? '' : '$v';
String? _textoONull(Object? v) => v == null ? null : '$v';
bool _logico(Object? v) => v == true;

/// Categorías de equipos que maneja la plataforma.
enum Categoria {
  construccion('CONSTRUCCION', 'Construcción'),
  eventos('EVENTOS', 'Eventos'),
  herramientas('HERRAMIENTAS', 'Herramientas'),
  tecnologia('TECNOLOGIA', 'Tecnología');

  const Categoria(this.codigo, this.etiqueta);
  final String codigo;
  final String etiqueta;

  static Categoria? desde(String? valor) {
    for (final c in Categoria.values) {
      if (c.codigo == valor) return c;
    }
    return null;
  }
}

enum EstadoEquipo {
  publicado('PUBLICADO', 'Publicado'),
  oculto('OCULTO', 'Oculto'),
  pendienteFoto('PENDIENTE_FOTO', 'Falta foto aprobada'),
  enRevision('EN_REVISION', 'En revisión');

  const EstadoEquipo(this.codigo, this.etiqueta);
  final String codigo;
  final String etiqueta;

  static EstadoEquipo desde(String? valor) {
    for (final e in EstadoEquipo.values) {
      if (e.codigo == valor) return e;
    }
    return EstadoEquipo.oculto;
  }
}

enum EstadoReserva {
  pendiente('PENDIENTE', 'Pendiente'),
  confirmada('CONFIRMADA', 'Confirmada'),
  enCurso('EN_CURSO', 'En curso'),
  devuelta('DEVUELTA', 'Devuelta'),
  cancelada('CANCELADA', 'Cancelada');

  const EstadoReserva(this.codigo, this.etiqueta);
  final String codigo;
  final String etiqueta;

  /// Siguiente estado que puede asignar el arrendador, o null si no hay.
  EstadoReserva? get siguienteParaArrendador => switch (this) {
        EstadoReserva.pendiente => EstadoReserva.confirmada,
        EstadoReserva.confirmada => EstadoReserva.enCurso,
        EstadoReserva.enCurso => EstadoReserva.devuelta,
        EstadoReserva.devuelta => null,
        EstadoReserva.cancelada => null,
      };

  bool get esCancelable => this == EstadoReserva.pendiente || this == EstadoReserva.confirmada;

  static EstadoReserva desde(String? valor) {
    for (final e in EstadoReserva.values) {
      if (e.codigo == valor) return e;
    }
    return EstadoReserva.pendiente;
  }
}

enum Rol {
  arrendatario('ARRENDATARIO', 'arrendatario'),
  arrendador('ARRENDADOR', 'arrendador');

  const Rol(this.codigo, this.parametroApi);
  final String codigo;

  /// Valor que espera la API en ?rol=
  final String parametroApi;
}

class Equipo {
  const Equipo({
    required this.id,
    required this.empresaId,
    required this.empresaNombre,
    required this.nombre,
    required this.categoria,
    required this.descripcion,
    required this.precioDia,
    required this.fotoUrl,
    required this.fotoId,
    required this.lat,
    required this.lng,
    required this.direccion,
    required this.estado,
    required this.calificacionPromedio,
    required this.totalResenas,
    required this.distanciaKm,
  });

  final String id;
  final String empresaId;
  final String empresaNombre;
  final String nombre;
  final Categoria categoria;
  final String descripcion;
  final double precioDia;
  final String? fotoUrl;
  final String? fotoId;
  final double lat;
  final double lng;
  final String direccion;
  final EstadoEquipo estado;
  final double calificacionPromedio;
  final int totalResenas;
  final double? distanciaKm;

  /// Copia el equipo cambiando solo los campos indicados (equivale a copy() de Kotlin).
  Equipo copyWith({
    String? id,
    String? empresaId,
    String? empresaNombre,
    String? nombre,
    Categoria? categoria,
    String? descripcion,
    double? precioDia,
    String? fotoUrl,
    String? fotoId,
    double? lat,
    double? lng,
    String? direccion,
    EstadoEquipo? estado,
    double? calificacionPromedio,
    int? totalResenas,
    double? distanciaKm,
  }) =>
      Equipo(
        id: id ?? this.id,
        empresaId: empresaId ?? this.empresaId,
        empresaNombre: empresaNombre ?? this.empresaNombre,
        nombre: nombre ?? this.nombre,
        categoria: categoria ?? this.categoria,
        descripcion: descripcion ?? this.descripcion,
        precioDia: precioDia ?? this.precioDia,
        fotoUrl: fotoUrl ?? this.fotoUrl,
        fotoId: fotoId ?? this.fotoId,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        direccion: direccion ?? this.direccion,
        estado: estado ?? this.estado,
        calificacionPromedio: calificacionPromedio ?? this.calificacionPromedio,
        totalResenas: totalResenas ?? this.totalResenas,
        distanciaKm: distanciaKm ?? this.distanciaKm,
      );

  factory Equipo.fromJson(Map<String, dynamic> j) => Equipo(
        id: _texto(j['id']),
        empresaId: _texto(j['empresaId']),
        empresaNombre: _textoONull(j['empresaNombre']) ?? 'Empresa',
        nombre: _texto(j['nombre']),
        categoria: Categoria.desde(_textoONull(j['categoria'])) ?? Categoria.herramientas,
        descripcion: _texto(j['descripcion']),
        precioDia: _num(j['precioDia']),
        fotoUrl: _textoONull(j['fotoUrl']),
        fotoId: _textoONull(j['fotoId']),
        lat: _num(j['lat']),
        lng: _num(j['lng']),
        direccion: _texto(j['direccion']),
        estado: EstadoEquipo.desde(_textoONull(j['estado'])),
        calificacionPromedio: _num(j['calificacionPromedio']),
        totalResenas: _entero(j['totalResenas']),
        distanciaKm: _numONull(j['distanciaKm']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'empresaId': empresaId,
        'empresaNombre': empresaNombre,
        'nombre': nombre,
        'categoria': categoria.codigo,
        'descripcion': descripcion,
        'precioDia': precioDia,
        'fotoUrl': fotoUrl,
        'fotoId': fotoId,
        'lat': lat,
        'lng': lng,
        'direccion': direccion,
        'estado': estado.codigo,
        'calificacionPromedio': calificacionPromedio,
        'totalResenas': totalResenas,
        'distanciaKm': distanciaKm,
      };
}

class Reserva {
  const Reserva({
    required this.id,
    required this.equipoId,
    required this.equipoNombre,
    required this.equipoFotoUrl,
    required this.arrendatarioNombre,
    required this.arrendadorNombre,
    required this.fechaInicio,
    required this.fechaFin,
    required this.dias,
    required this.precioDia,
    required this.subtotal,
    required this.comision,
    required this.montoArrendador,
    required this.total,
    required this.penalidad,
    required this.estado,
    required this.rolSolicitante,
    required this.resenaEnviada,
    required this.devueltaEn,
  });

  final String id;
  final String equipoId;
  final String equipoNombre;
  final String? equipoFotoUrl;
  final String arrendatarioNombre;
  final String arrendadorNombre;
  final String fechaInicio;
  final String fechaFin;
  final int dias;
  final double precioDia;
  final double subtotal;
  final double comision;
  final double montoArrendador;
  final double total;
  final double penalidad;
  final EstadoReserva estado;
  final Rol rolSolicitante;
  final bool resenaEnviada;
  final String? devueltaEn;

  factory Reserva.fromJson(Map<String, dynamic> j) => Reserva(
        id: _texto(j['id']),
        equipoId: _texto(j['equipoId']),
        equipoNombre: _texto(j['equipoNombre']),
        equipoFotoUrl: _textoONull(j['equipoFotoUrl']),
        arrendatarioNombre: _texto(j['arrendatarioNombre']),
        arrendadorNombre: _texto(j['arrendadorNombre']),
        fechaInicio: _texto(j['fechaInicio']),
        fechaFin: _texto(j['fechaFin']),
        dias: _entero(j['dias']),
        precioDia: _num(j['precioDia']),
        subtotal: _num(j['subtotal']),
        comision: _num(j['comision']),
        montoArrendador: _num(j['montoArrendador']),
        total: _num(j['total']),
        penalidad: _num(j['penalidad']),
        estado: EstadoReserva.desde(_textoONull(j['estado'])),
        rolSolicitante: j['rolSolicitante'] == Rol.arrendador.codigo ? Rol.arrendador : Rol.arrendatario,
        resenaEnviada: _logico(j['resenaEnviada']),
        devueltaEn: _textoONull(j['devueltaEn']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'equipoId': equipoId,
        'equipoNombre': equipoNombre,
        'equipoFotoUrl': equipoFotoUrl,
        'arrendatarioNombre': arrendatarioNombre,
        'arrendadorNombre': arrendadorNombre,
        'fechaInicio': fechaInicio,
        'fechaFin': fechaFin,
        'dias': dias,
        'precioDia': precioDia,
        'subtotal': subtotal,
        'comision': comision,
        'montoArrendador': montoArrendador,
        'total': total,
        'penalidad': penalidad,
        'estado': estado.codigo,
        'rolSolicitante': rolSolicitante.codigo,
        'resenaEnviada': resenaEnviada,
        'devueltaEn': devueltaEn,
      };
}

class Empresa {
  const Empresa({
    required this.id,
    required this.razonSocial,
    required this.ruc,
    required this.telefono,
    required this.email,
    required this.verificada,
    required this.calificacionComoArrendatario,
    required this.totalResenasComoArrendatario,
  });

  final String id;
  final String razonSocial;
  final String ruc;
  final String telefono;
  final String? email;
  final bool verificada;
  final double calificacionComoArrendatario;
  final int totalResenasComoArrendatario;

  factory Empresa.fromJson(Map<String, dynamic> j) => Empresa(
        id: _texto(j['id']),
        razonSocial: _texto(j['razonSocial']),
        ruc: _texto(j['ruc']),
        telefono: _texto(j['telefono']),
        email: _textoONull(j['email']),
        verificada: _logico(j['verificada']),
        calificacionComoArrendatario: _num(j['calificacionComoArrendatario']),
        totalResenasComoArrendatario: _entero(j['totalResenasComoArrendatario']),
      );
}

class Resena {
  const Resena({
    required this.id,
    required this.autorNombre,
    required this.estrellas,
    required this.comentario,
    required this.creadoEn,
  });

  final String id;
  final String autorNombre;
  final int estrellas;
  final String comentario;
  final String creadoEn;

  factory Resena.fromJson(Map<String, dynamic> j) => Resena(
        id: _texto(j['id']),
        autorNombre: _texto(j['autorNombre']),
        estrellas: _entero(j['estrellas']),
        comentario: _texto(j['comentario']),
        creadoEn: _texto(j['creadoEn']),
      );
}

class Cotizacion {
  const Cotizacion({
    required this.dias,
    required this.precioDia,
    required this.subtotal,
    required this.comision,
    required this.montoArrendador,
    required this.total,
    required this.disponible,
  });

  final int dias;
  final double precioDia;
  final double subtotal;
  final double comision;
  final double montoArrendador;
  final double total;
  final bool disponible;

  factory Cotizacion.fromJson(Map<String, dynamic> j) => Cotizacion(
        dias: _entero(j['dias']),
        precioDia: _num(j['precioDia']),
        subtotal: _num(j['subtotal']),
        comision: _num(j['comision']),
        montoArrendador: _num(j['montoArrendador']),
        total: _num(j['total']),
        disponible: _logico(j['disponible']),
      );
}

class RangoOcupado {
  const RangoOcupado(this.fechaInicio, this.fechaFin);
  final String fechaInicio;
  final String fechaFin;

  factory RangoOcupado.fromJson(Map<String, dynamic> j) =>
      RangoOcupado(_texto(j['fechaInicio']), _texto(j['fechaFin']));
}

/// [correoVerificado] es false mientras la empresa no abra el enlace de verificación de su correo.
class Sesion {
  const Sesion({required this.uid, required this.email, required this.esDemo, this.correoVerificado = true});
  final String uid;
  final String? email;
  final bool esDemo;
  final bool correoVerificado;

  @override
  bool operator ==(Object other) =>
      other is Sesion &&
      other.uid == uid &&
      other.email == email &&
      other.esDemo == esDemo &&
      other.correoVerificado == correoVerificado;

  @override
  int get hashCode => Object.hash(uid, email, esDemo, correoVerificado);
}

/// Datos del formulario de publicación o edición de un equipo.
class EquipoEntrada {
  const EquipoEntrada({
    required this.nombre,
    required this.categoria,
    required this.descripcion,
    required this.precioDia,
    required this.lat,
    required this.lng,
    required this.direccion,
    required this.fotoId,
    required this.visible,
  });

  final String nombre;
  final Categoria categoria;
  final String descripcion;
  final double precioDia;
  final double lat;
  final double lng;
  final String direccion;
  final String? fotoId;
  final bool visible;

  Map<String, dynamic> toJson() => {
        'nombre': nombre.trim(),
        'categoria': categoria.codigo,
        'descripcion': descripcion.trim(),
        'precioDia': precioDia,
        'lat': lat,
        'lng': lng,
        'direccion': direccion.trim(),
        'fotoId': fotoId,
        'visible': visible,
      };
}

class FotoSubida {
  const FotoSubida(this.id, this.url);
  final String id;
  final String url;
}

class Coordenadas {
  const Coordenadas(this.lat, this.lng);
  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) => other is Coordenadas && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);
}

/// Filtros con los que se consulta el catálogo en la API.
class FiltroCatalogo {
  const FiltroCatalogo({this.texto = '', this.categoria, this.ubicacion, this.radioKm});
  final String texto;
  final Categoria? categoria;
  final Coordenadas? ubicacion;
  final double? radioKm;
}

/// Números del panel de la empresa (HU-10), calculados por el servidor.
class MetricasEmpresa {
  const MetricasEmpresa({
    required this.equiposPublicados,
    required this.equiposTotales,
    required this.reservasPendientes,
    required this.reservasActivas,
    required this.reservasComoCliente,
    required this.alquileresCompletados,
    required this.ingresosEstimados,
    required this.equipoMasAlquilado,
    required this.vecesMasAlquilado,
  });

  final int equiposPublicados;
  final int equiposTotales;
  final int reservasPendientes;
  final int reservasActivas;
  final int reservasComoCliente;
  final int alquileresCompletados;
  final double ingresosEstimados;
  final String? equipoMasAlquilado;
  final int vecesMasAlquilado;

  /// Igual que MetricasDto.aDominio() de Kotlin: un nombre vacío se toma como "sin equipo".
  factory MetricasEmpresa.fromJson(Map<String, dynamic> j) {
    final mas = j['equipoMasAlquilado'];
    final masMapa = mas is Map ? Map<String, dynamic>.from(mas) : null;
    final nombre = _textoONull(masMapa?['nombre']);
    return MetricasEmpresa(
      equiposPublicados: _entero(j['equiposPublicados']),
      equiposTotales: _entero(j['equiposTotales']),
      reservasPendientes: _entero(j['reservasPendientes']),
      reservasActivas: _entero(j['reservasActivas']),
      reservasComoCliente: _entero(j['reservasComoCliente']),
      alquileresCompletados: _entero(j['alquileresCompletados']),
      ingresosEstimados: _num(j['ingresosEstimados']),
      equipoMasAlquilado: (nombre == null || nombre.trim().isEmpty) ? null : nombre,
      vecesMasAlquilado: masMapa == null ? 0 : _entero(masMapa['veces']),
    );
  }
}
