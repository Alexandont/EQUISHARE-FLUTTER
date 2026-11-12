import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../contenedor.dart';
import '../../domain/formato.dart';
import '../../domain/modelos.dart';
import '../../domain/repositorios.dart';
import '../../domain/resultado.dart';
import '../modelo_vista.dart';

/// Saludo del inicio y panel de Mis equipos (HU-10): nombre de la empresa y sus números.
class PanelViewModel extends ModeloVista {
  PanelViewModel(this._empresas, FavoritosRepository favoritos) {
    _suscripcion = favoritos.observar().listen((ids) {
      this.favoritos = ids.length;
      avisar();
    });
    cargar();
  }

  final EmpresaRepository _empresas;
  late final StreamSubscription<Set<String>> _suscripcion;

  bool cargando = true;
  String? empresa;
  MetricasEmpresa? metricas;
  int favoritos = 0;
  String? error;

  Future<void> cargar() async {
    cargando = true;
    error = null;
    avisar();
    final datosEmpresa = await _empresas.miEmpresa();
    final numeros = await _empresas.metricas();
    if (cerrado) return;
    cargando = false;
    // Si la red falla, se conservan los datos que ya se tenían.
    empresa = datosEmpresa.datosONull?.razonSocial ?? empresa;
    metricas = numeros.datosONull ?? metricas;
    error = numeros.errorONull?.mensaje;
    avisar();
  }

  @override
  void dispose() {
    _suscripcion.cancel();
    super.dispose();
  }
}

/// Crea el ViewModel del panel con lo del contenedor (o usa el que se le pase, en las pruebas).
mixin _ConPanel<T extends StatefulWidget> on State<T> {
  late final PanelViewModel vm;
  bool _propio = false;

  PanelViewModel? get vmDado;

  @override
  void initState() {
    super.initState();
    final dado = vmDado;
    if (dado != null) {
      vm = dado;
    } else {
      final c = context.read<Contenedor>();
      vm = PanelViewModel(c.empresas, c.favoritos);
      _propio = true;
    }
  }

  @override
  void dispose() {
    if (_propio) vm.dispose();
    super.dispose();
  }
}

/// Saludo arriba del catálogo: "Hola, (nombre de la empresa)" con tres números rápidos.
class SaludoInicio extends StatefulWidget {
  const SaludoInicio({super.key, this.vm});

  final PanelViewModel? vm;

  @override
  State<SaludoInicio> createState() => _SaludoInicioState();
}

class _SaludoInicioState extends State<SaludoInicio> with _ConPanel<SaludoInicio> {
  @override
  PanelViewModel? get vmDado => widget.vm;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final visible = !vm.cargando && vm.empresa != null;
        return AnimatedSize(
          duration: const Duration(milliseconds: 300),
          alignment: Alignment.topCenter,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: visible ? 1 : 0,
            child: !visible
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Card(
                      margin: EdgeInsets.zero,
                      color: tema.colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Hola, ${vm.empresa ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(child: _Dato(valor: '${vm.metricas?.reservasPendientes ?? 0}', etiqueta: 'por aceptar')),
                                const SizedBox(width: 8),
                                Expanded(child: _Dato(valor: '${vm.metricas?.equiposPublicados ?? 0}', etiqueta: 'publicados')),
                                const SizedBox(width: 8),
                                Expanded(child: _Dato(valor: '${vm.favoritos}', etiqueta: 'favoritos')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

/// Panel de Mis equipos (HU-10): cuánto se alquilan los equipos de la empresa.
class PanelMetricas extends StatefulWidget {
  const PanelMetricas({super.key, this.vm});

  final PanelViewModel? vm;

  @override
  State<PanelMetricas> createState() => _PanelMetricasState();
}

class _PanelMetricasState extends State<PanelMetricas> with _ConPanel<PanelMetricas> {
  @override
  PanelViewModel? get vmDado => widget.vm;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final m = vm.metricas;
        final hijos = <Widget>[
          Text('Tu panel', style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
        ];
        if (m == null) {
          hijos.add(Text(
            vm.cargando ? 'Cargando tus números…' : (vm.error ?? 'Todavía no hay datos.'),
            style: tema.textTheme.bodySmall,
          ));
          if (!vm.cargando) {
            hijos.add(Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: vm.cargar, child: const Text('Reintentar')),
            ));
          }
        } else {
          hijos.addAll([
            Row(
              children: [
                Expanded(
                  child: _Dato(valor: '${m.equiposPublicados} de ${m.equiposTotales}', etiqueta: 'equipos publicados'),
                ),
                const SizedBox(width: 8),
                Expanded(child: _Dato(valor: '${m.reservasPendientes}', etiqueta: 'reservas por aceptar')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _Dato(valor: '${m.alquileresCompletados}', etiqueta: 'alquileres completados')),
                const SizedBox(width: 8),
                Expanded(child: _Dato(valor: Formato.soles(m.ingresosEstimados), etiqueta: 'ingresos estimados')),
              ],
            ),
          ]);
          final masAlquilado = m.equipoMasAlquilado;
          if (masAlquilado != null) {
            hijos.addAll([
              const SizedBox(height: 8),
              Text(
                'Más alquilado: $masAlquilado (${m.vecesMasAlquilado} ${m.vecesMasAlquilado == 1 ? 'vez' : 'veces'})',
                style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
            ]);
          }
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: hijos),
            ),
          ),
        );
      },
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.valor, required this.etiqueta});

  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(valor, maxLines: 1, style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        Text(etiqueta, style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
