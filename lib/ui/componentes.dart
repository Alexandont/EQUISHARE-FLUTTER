import 'package:flutter/material.dart';

import '../domain/compat_kotlin.dart';
import '../domain/formato.dart';
import '../domain/modelos.dart';
import 'tema.dart';

const String textoSinConexion = 'Sin conexión. Mostrando datos guardados en el teléfono.';

IconData iconoCategoria(Categoria categoria) => switch (categoria) {
      Categoria.construccion => Icons.construction,
      Categoria.eventos => Icons.celebration,
      Categoria.herramientas => Icons.handyman,
      Categoria.tecnologia => Icons.devices,
    };

/// Muestra un mensaje breve en la parte inferior (equivale al Snackbar de la versión Kotlin).
void mostrarMensaje(BuildContext context, String texto) {
  final mensajero = ScaffoldMessenger.maybeOf(context);
  if (mensajero == null) return;
  mensajero
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}

class EstadoCargando extends StatelessWidget {
  const EstadoCargando({super.key, this.texto = 'Cargando…'});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(texto, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class EstadoError extends StatelessWidget {
  const EstadoError({super.key, required this.mensaje, this.textoBoton = 'Reintentar', this.alReintentar});

  final String mensaje;
  final String textoBoton;
  final VoidCallback? alReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
            if (alReintentar != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: alReintentar, child: Text(textoBoton)),
            ],
          ],
        ),
      ),
    );
  }
}

class EstadoVacio extends StatelessWidget {
  const EstadoVacio({super.key, required this.titulo, required this.detalle});

  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: tema.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(titulo, textAlign: TextAlign.center, style: tema.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aviso cuando no hay conexión: la app sigue mostrando los datos guardados en el teléfono.
class BannerSinConexion extends StatelessWidget {
  const BannerSinConexion({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final esquema = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: esquema.tertiaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.cloud_off, color: esquema.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(child: Text(textoSinConexion, style: TextStyle(color: esquema.onTertiaryContainer))),
        ],
      ),
    );
  }
}

class ImagenEquipo extends StatelessWidget {
  const ImagenEquipo({
    super.key,
    required this.url,
    required this.categoria,
    required this.descripcion,
    this.ancho,
    this.alto,
    this.radio = 12,
  });

  final String? url;
  final Categoria categoria;
  final String descripcion;
  final double? ancho;
  final double? alto;
  final double radio;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final icono = Center(child: Icon(iconoCategoria(categoria), size: 36, color: esquema.onSurfaceVariant));
    final direccion = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radio),
      child: Container(
        width: ancho,
        height: alto,
        color: esquema.surfaceContainerHighest,
        child: direccion == null
            ? icono
            : Image.network(
                direccion,
                fit: BoxFit.cover,
                semanticLabel: descripcion,
                errorBuilder: (context, error, stackTrace) => icono,
              ),
      ),
    );
  }
}

class Estrellas extends StatelessWidget {
  const Estrellas({super.key, required this.valor, this.tamano = 16});

  final double valor;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final apagada = Theme.of(context).colorScheme.outlineVariant;
    return Semantics(
      label: 'Calificación ${fijoComoJava(valor, 1)} de 5',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= 5; i++)
              Icon(Icons.star, size: tamano, color: valor >= i - 0.25 ? dorado : apagada),
          ],
        ),
      ),
    );
  }
}

/// Selector de estrellas (1 a 5). Cada estrella es un objetivo táctil de 48 px.
class SelectorEstrellas extends StatelessWidget {
  const SelectorEstrellas({super.key, required this.valor, required this.alCambiar});

  final int valor;
  final ValueChanged<int> alCambiar;

  @override
  Widget build(BuildContext context) {
    final apagada = Theme.of(context).colorScheme.outlineVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            tooltip: '$i estrellas',
            onPressed: () => alCambiar(i),
            icon: Icon(Icons.star, size: 32, color: i <= valor ? dorado : apagada),
          ),
      ],
    );
  }
}

class Etiqueta extends StatelessWidget {
  const Etiqueta({super.key, required this.texto, required this.fondo, required this.colorTexto});

  final String texto;
  final Color fondo;
  final Color colorTexto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(50)),
      child: Text(texto, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colorTexto)),
    );
  }
}

class EtiquetaEstadoEquipo extends StatelessWidget {
  const EtiquetaEstadoEquipo({super.key, required this.estado});

  final EstadoEquipo estado;

  @override
  Widget build(BuildContext context) {
    final e = Theme.of(context).colorScheme;
    return switch (estado) {
      EstadoEquipo.publicado =>
        Etiqueta(texto: estado.etiqueta, fondo: e.secondaryContainer, colorTexto: e.onSecondaryContainer),
      EstadoEquipo.oculto =>
        Etiqueta(texto: estado.etiqueta, fondo: e.surfaceContainerHighest, colorTexto: e.onSurfaceVariant),
      EstadoEquipo.pendienteFoto =>
        Etiqueta(texto: estado.etiqueta, fondo: e.tertiaryContainer, colorTexto: e.onTertiaryContainer),
      EstadoEquipo.enRevision => Etiqueta(texto: estado.etiqueta, fondo: e.errorContainer, colorTexto: e.onErrorContainer),
    };
  }
}

class EtiquetaEstadoReserva extends StatelessWidget {
  const EtiquetaEstadoReserva({super.key, required this.estado});

  final EstadoReserva estado;

  @override
  Widget build(BuildContext context) {
    final e = Theme.of(context).colorScheme;
    return switch (estado) {
      EstadoReserva.pendiente =>
        Etiqueta(texto: estado.etiqueta, fondo: e.tertiaryContainer, colorTexto: e.onTertiaryContainer),
      EstadoReserva.confirmada ||
      EstadoReserva.enCurso =>
        Etiqueta(texto: estado.etiqueta, fondo: e.primaryContainer, colorTexto: e.onPrimaryContainer),
      EstadoReserva.devuelta =>
        Etiqueta(texto: estado.etiqueta, fondo: e.secondaryContainer, colorTexto: e.onSecondaryContainer),
      EstadoReserva.cancelada =>
        Etiqueta(texto: estado.etiqueta, fondo: e.surfaceContainerHighest, colorTexto: e.onSurfaceVariant),
    };
  }
}

class TarjetaEquipo extends StatelessWidget {
  const TarjetaEquipo({
    super.key,
    required this.equipo,
    required this.esFavorito,
    required this.alPulsar,
    required this.alCambiarFavorito,
  });

  final Equipo equipo;
  final bool esFavorito;
  final VoidCallback alPulsar;
  final VoidCallback alCambiarFavorito;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final extra = [
      equipo.totalResenas > 0 ? '(${equipo.totalResenas})' : 'Nuevo',
      if (Formato.distancia(equipo.distanciaKm) != null) Formato.distancia(equipo.distanciaKm)!,
    ].join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alPulsar,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ImagenEquipo(
                url: equipo.fotoUrl,
                categoria: equipo.categoria,
                descripcion: 'Foto de ${equipo.nombre}',
                ancho: 84,
                alto: 84,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      equipo.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${Formato.soles(equipo.precioDia)} / día',
                      style: tema.textTheme.bodyLarge?.copyWith(
                        color: tema.colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(equipo.empresaNombre, maxLines: 1, overflow: TextOverflow.ellipsis, style: tema.textTheme.bodySmall),
                    Row(
                      children: [
                        Estrellas(valor: equipo.calificacionPromedio, tamano: 14),
                        const SizedBox(width: 6),
                        Flexible(child: Text(extra, style: tema.textTheme.bodySmall)),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: esFavorito ? 'Quitar de favoritos' : 'Agregar a favoritos',
                onPressed: alCambiarFavorito,
                icon: Icon(
                  esFavorito ? Icons.favorite : Icons.favorite_border,
                  color: esFavorito ? tema.colorScheme.error : tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Resumen de la política de privacidad (Ley N.° 29733 y su reglamento, D.S. N.° 016-2024-JUS).
class TextoPoliticaPrivacidad extends StatelessWidget {
  const TextoPoliticaPrivacidad({super.key});

  static const List<List<String>> secciones = [
    [
      'Qué datos usamos',
      'Correo de acceso, RUC, razón social y teléfono de la empresa; los equipos que publicas '
          '(fotos, precio y ubicación aproximada del equipo) y el historial de reservas y calificaciones.',
    ],
    [
      'Para qué',
      'Verificar que eres una empresa (RUC), mostrar tus equipos en el catálogo, gestionar reservas y '
          'generar confianza mediante calificaciones. No vendemos tus datos ni enviamos mensajes a tus contactos.',
    ],
    [
      'Ubicación',
      'Solo se usa, con tu permiso, para ordenar equipos por cercanía y ubicar el equipo que publicas. '
          'Puedes usar la app sin conceder este permiso.',
    ],
    [
      'Dónde se guardan',
      'En el servidor de EQUISHARE y, para la sesión y los favoritos, en Firebase (Google). '
          'En tu teléfono se guarda una copia del catálogo para usarlo sin conexión; se borra al cerrar sesión.',
    ],
    [
      'Tus derechos',
      'Puedes solicitar acceso, rectificación, cancelación u oposición sobre tus datos personales '
          '(derechos ARCO) escribiendo al equipo del proyecto.',
    ],
    [
      'Sin trampas',
      'No hay casillas premarcadas, cargos ocultos ni mensajes de urgencia falsos. La comisión del 12 % '
          'y las penalidades se muestran antes de confirmar cualquier reserva.',
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in secciones) ...[
          Text(s[0], style: tema.titleSmall),
          const SizedBox(height: 2),
          Text(s[1], style: tema.bodySmall),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Carga tipo esqueleto: tarjetas grises con brillo suave que tienen la misma forma de las reales.
/// Así se nota que la app está trabajando y no que se colgó.
class ListaEsqueleto extends StatefulWidget {
  const ListaEsqueleto({super.key, this.cantidad = 4});

  final int cantidad;

  @override
  State<ListaEsqueleto> createState() => _ListaEsqueletoState();
}

class _ListaEsqueletoState extends State<ListaEsqueleto> with SingleTickerProviderStateMixin {
  late final AnimationController _brillo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
    lowerBound: 0.35,
    upperBound: 0.9,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _brillo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gris = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget barra(double fraccion, double alto) => FractionallySizedBox(
          widthFactor: fraccion,
          alignment: Alignment.centerLeft,
          child: Container(
            height: alto,
            decoration: BoxDecoration(color: gris, borderRadius: BorderRadius.circular(4)),
          ),
        );
    return Semantics(
      label: 'Cargando equipos',
      child: ExcludeSemantics(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: FadeTransition(
            opacity: _brillo,
            child: Column(
              children: [
                for (var i = 0; i < widget.cantidad; i++)
                  Padding(
                    padding: EdgeInsets.only(bottom: i == widget.cantidad - 1 ? 0 : 12),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(color: gris, borderRadius: BorderRadius.circular(12)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  barra(0.7, 16),
                                  const SizedBox(height: 8),
                                  barra(0.45, 12),
                                  const SizedBox(height: 8),
                                  barra(0.3, 12),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
