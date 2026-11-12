import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../contenedor.dart';
import '../../domain/repositorios.dart';
import '../../domain/resultado.dart';
import '../modelo_vista.dart';

/// Pantalla "Revisa tu correo": la cuenta no se puede usar hasta abrir el enlace de verificación.
/// Así no quedan cuentas con correos falsos o mal escritos (por ejemplo "@gmai.com").
class VerificarCorreoViewModel extends ModeloVista {
  VerificarCorreoViewModel(this._auth, {int Function()? reloj})
      : _reloj = reloj ?? (() => DateTime.now().millisecondsSinceEpoch),
        email = _auth.sesionActual?.email {
    // Si la persona ya abrió el enlace con la app cerrada, entra directo sin tocar nada.
    revisar(silencioso: true);
  }

  final AuthRepository _auth;
  final int Function() _reloj;

  static const int esperaMs = 60000;
  static const String verificado = '¡Correo verificado! Entrando…';
  static const String todaviaNo =
      'Todavía no está verificado. Abre el enlace del correo y vuelve a tocar «Ya lo verifiqué».';
  static const String reenviado = 'Te enviamos un correo nuevo. Revisa también la carpeta de spam.';

  final String? email;
  bool revisando = false;
  bool enviando = false;
  String? mensaje;
  bool esError = false;

  /// Momento del último reenvío, para no mandar muchos correos seguidos.
  int? ultimoEnvioMs;

  /// Botón "Ya lo verifiqué". Si está verificado, la app pasa sola a la siguiente pantalla.
  Future<void> revisar({bool silencioso = false}) async {
    if (revisando) return;
    revisando = true;
    avisar();
    final r = await _auth.revisarVerificacion();
    if (cerrado) return;
    revisando = false;
    if (r is Exito<bool>) {
      if (r.datos) {
        mensaje = verificado;
        esError = false;
      } else if (!silencioso) {
        mensaje = todaviaNo;
        esError = true;
      }
    } else if (!silencioso) {
      mensaje = r.errorONull!.mensaje;
      esError = true;
    }
    avisar();
  }

  /// Segundos que faltan para poder pedir otro correo (0 si ya se puede).
  int segundosParaReenviar() {
    final ultimo = ultimoEnvioMs;
    if (ultimo == null) return 0;
    final restante = esperaMs - (_reloj() - ultimo);
    return restante <= 0 ? 0 : (restante + 999) ~/ 1000;
  }

  Future<void> reenviar() async {
    if (enviando) return;
    final faltan = segundosParaReenviar();
    if (faltan > 0) {
      mensaje = 'Espera $faltan s para pedir otro correo.';
      esError = true;
      avisar();
      return;
    }
    enviando = true;
    avisar();
    final r = await _auth.enviarVerificacion();
    if (cerrado) return;
    enviando = false;
    if (r.esExito) {
      ultimoEnvioMs = _reloj();
      mensaje = reenviado;
      esError = false;
    } else {
      mensaje = r.errorONull!.mensaje;
      esError = true;
    }
    avisar();
  }

  /// Para quien escribió mal su correo: sale y crea la cuenta con el correo correcto.
  Future<void> cerrarSesion() => _auth.cerrarSesion();
}

class VerificarCorreoPage extends StatefulWidget {
  const VerificarCorreoPage({super.key});

  @override
  State<VerificarCorreoPage> createState() => _VerificarCorreoPageState();
}

class _VerificarCorreoPageState extends State<VerificarCorreoPage> {
  late final VerificarCorreoViewModel vm;
  Timer? _cuentaRegresiva;
  int _segundos = 0;
  int? _envioVisto;

  @override
  void initState() {
    super.initState();
    vm = VerificarCorreoViewModel(context.read<Contenedor>().auth);
    vm.addListener(_alCambiar);
  }

  /// Cuenta regresiva del botón "Reenviar" para no mandar muchos correos seguidos.
  void _alCambiar() {
    if (vm.ultimoEnvioMs == _envioVisto) return;
    _envioVisto = vm.ultimoEnvioMs;
    _cuentaRegresiva?.cancel();
    setState(() => _segundos = vm.segundosParaReenviar());
    if (_segundos > 0) {
      _cuentaRegresiva = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _segundos = vm.segundosParaReenviar());
        if (_segundos == 0) t.cancel();
      });
    }
  }

  @override
  void dispose() {
    _cuentaRegresiva?.cancel();
    vm.removeListener(_alCambiar);
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListenableBuilder(
              listenable: vm,
              builder: (context, _) => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.email, size: 64, color: tema.colorScheme.primary),
                    const SizedBox(height: 12),
                    Text(
                      'Revisa tu correo',
                      textAlign: TextAlign.center,
                      style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Te enviamos un enlace a ${vm.email ?? 'tu correo'}. Ábrelo y luego toca «Ya lo verifiqué».',
                      style: tema.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Esto protege a todas las empresas: una cuenta solo se usa con un correo real.',
                          style: tema.textTheme.bodySmall,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: vm.revisando ? null : () => vm.revisar(),
                        child: vm.revisando
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Ya lo verifiqué'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: (!vm.enviando && _segundos == 0) ? vm.reenviar : null,
                      child: Text(_segundos > 0 ? 'Reenviar en $_segundos s' : 'Reenviar correo'),
                    ),
                    if (vm.mensaje != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        vm.mensaje!,
                        style: tema.textTheme.bodyMedium?.copyWith(
                          color: vm.esError ? tema.colorScheme.error : tema.colorScheme.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      '¿Escribiste mal tu correo? Cierra sesión y crea la cuenta otra vez con el correo correcto.',
                      style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                    ),
                    TextButton(onPressed: vm.cerrarSesion, child: const Text('Cerrar sesión')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
