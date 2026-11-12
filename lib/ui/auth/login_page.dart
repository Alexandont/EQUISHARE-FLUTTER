import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../contenedor.dart';
import '../../domain/validadores.dart';
import '../componentes.dart';
import '../perfil/dialogo_servidor.dart';
import 'login_vm.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.alRegistrarse});

  /// Se llama con el correo cuando se crea una cuenta nueva.
  final void Function(String email)? alRegistrarse;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final LoginViewModel vm;
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmacion = TextEditingController();
  bool _verPassword = false;

  @override
  void initState() {
    super.initState();
    vm = LoginViewModel(context.read<Contenedor>().auth);
    vm.addListener(_sincronizar);
  }

  /// Si el ViewModel cambia el texto (sugerencia de correo o formulario limpio), también cambian los campos.
  void _sincronizar() {
    _poner(_email, vm.email);
    _poner(_password, vm.password);
    _poner(_confirmacion, vm.confirmacion);
  }

  static void _poner(TextEditingController campo, String valor) {
    if (campo.text == valor) return;
    campo.value = TextEditingValue(text: valor, selection: TextSelection.collapsed(offset: valor.length));
  }

  @override
  void dispose() {
    vm.removeListener(_sincronizar);
    vm.dispose();
    _email.dispose();
    _password.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  void _verPolitica() {
    showDialog<void>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Política de privacidad'),
        content: const SingleChildScrollView(child: TextoPoliticaPrivacidad()),
        actions: [TextButton(onPressed: () => Navigator.of(contexto).pop(), child: const Text('Cerrar'))],
      ),
    );
  }

  /// "¿Olvidaste tu contraseña?": pide el correo y envía el enlace para crear una contraseña nueva.
  Future<void> _abrirRecuperar() async {
    vm.abrirRecuperar();
    await showDialog<void>(context: context, builder: (_) => _DialogoRecuperar(vm: vm));
    vm.cerrarRecuperar();
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
                    Icon(Icons.handshake, size: 64, color: tema.colorScheme.primary),
                    const SizedBox(height: 8),
                    Text(
                      'EQUISHARE',
                      textAlign: TextAlign.center,
                      style: tema.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: tema.colorScheme.primary,
                      ),
                    ),
                    Text(
                      'Alquila y comparte equipos entre empresas',
                      textAlign: TextAlign.center,
                      style: tema.textTheme.bodyMedium?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    if (vm.esModoDemo) ...[
                      Card(
                        color: tema.colorScheme.tertiaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'Modo demostración. Ingresa con constructora@demo.pe, eventos@demo.pe o '
                            'taller@demo.pe y cualquier contraseña de 8 caracteres con letras y números.',
                            style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.onTertiaryContainer),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(vm.modoRegistro ? 'Crear cuenta' : 'Iniciar sesión', style: tema.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        labelText: 'Correo de la empresa',
                        prefixIcon: const Icon(Icons.email_outlined),
                        errorText: vm.errorEmail,
                      ),
                      onChanged: vm.alCambiarEmail,
                    ),
                    if (vm.sugerenciaCorreo != null)
                      TextButton(
                        onPressed: vm.usarSugerenciaCorreo,
                        child: Text('¿Quisiste decir ${vm.sugerenciaCorreo}?'),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: !_verPassword,
                      textInputAction: vm.modoRegistro ? TextInputAction.next : TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        errorText: vm.errorPassword,
                        suffixIcon: IconButton(
                          tooltip: _verPassword ? 'Ocultar contraseña' : 'Mostrar contraseña',
                          icon: Icon(_verPassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _verPassword = !_verPassword),
                        ),
                      ),
                      onChanged: vm.alCambiarPassword,
                    ),
                    if (vm.modoRegistro && vm.fuerzaPassword != FuerzaPassword.vacia) ...[
                      const SizedBox(height: 8),
                      IndicadorFuerza(fuerza: vm.fuerzaPassword),
                    ],
                    if (!vm.modoRegistro)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(onPressed: _abrirRecuperar, child: const Text('¿Olvidaste tu contraseña?')),
                      ),
                    if (vm.modoRegistro) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirmacion,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Repite la contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          errorText: vm.errorConfirmacion,
                        ),
                        onChanged: vm.alCambiarConfirmacion,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: vm.aceptaPrivacidad,
                            onChanged: (v) => vm.alCambiarPrivacidad(v ?? false),
                          ),
                          const Flexible(child: Text('He leído y acepto la ')),
                          Flexible(
                            child: TextButton(onPressed: _verPolitica, child: const Text('política de privacidad')),
                          ),
                        ],
                      ),
                      if (vm.errorPrivacidad != null)
                        Text(vm.errorPrivacidad!, style: TextStyle(color: tema.colorScheme.error)),
                    ],
                    if (vm.errorGeneral != null) ...[
                      const SizedBox(height: 12),
                      Text(vm.errorGeneral!, style: TextStyle(color: tema.colorScheme.error)),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: vm.cargando ? null : () => vm.enviar(widget.alRegistrarse ?? (_) {}),
                        child: vm.cargando
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(vm.modoRegistro ? 'Crear cuenta' : 'Ingresar'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: vm.alternarModo,
                      child: Text(vm.modoRegistro ? '¿Ya tienes cuenta? Inicia sesión' : '¿Tu empresa es nueva? Crea una cuenta'),
                    ),
                    TextButton(
                      onPressed: () => mostrarDialogoServidor(context),
                      child: const Text('Ajustes de conexión'),
                    ),
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

/// Barra de colores que muestra qué tan segura es la contraseña nueva.
class IndicadorFuerza extends StatelessWidget {
  const IndicadorFuerza({super.key, required this.fuerza});

  final FuerzaPassword fuerza;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final color = switch (fuerza) {
      FuerzaPassword.fuerte => const Color(0xFF2E7D32),
      FuerzaPassword.media => const Color(0xFFBF8B2E),
      _ => tema.colorScheme.error,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(value: fuerza.progreso, color: color),
        const SizedBox(height: 4),
        Text('Seguridad de la contraseña: ${fuerza.etiqueta}', style: tema.textTheme.bodySmall?.copyWith(color: color)),
      ],
    );
  }
}

class _DialogoRecuperar extends StatefulWidget {
  const _DialogoRecuperar({required this.vm});

  final LoginViewModel vm;

  @override
  State<_DialogoRecuperar> createState() => _DialogoRecuperarState();
}

class _DialogoRecuperarState extends State<_DialogoRecuperar> {
  late final TextEditingController _correo = TextEditingController(text: widget.vm.emailRecuperar);

  @override
  void dispose() {
    _correo.dispose();
    super.dispose();
  }

  void _cerrar() {
    widget.vm.cerrarRecuperar();
    if (!widget.vm.mostrarRecuperar) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final mensaje = vm.mensajeRecuperarEnviado;
        return PopScope(
          canPop: !vm.enviandoRecuperar,
          child: AlertDialog(
            title: const Text('Recuperar contraseña'),
            content: SingleChildScrollView(
              child: mensaje != null
                  ? Text(mensaje)
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Escribe el correo de tu cuenta y te enviaremos un enlace para crear una contraseña nueva.'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _correo,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(labelText: 'Correo de la cuenta', errorText: vm.errorRecuperar),
                          onChanged: vm.alCambiarEmailRecuperar,
                        ),
                      ],
                    ),
            ),
            actions: mensaje != null
                ? [TextButton(onPressed: _cerrar, child: const Text('Entendido'))]
                : [
                    TextButton(onPressed: vm.enviandoRecuperar ? null : _cerrar, child: const Text('Cancelar')),
                    TextButton(
                      onPressed: vm.enviandoRecuperar ? null : vm.enviarRecuperar,
                      child: Text(vm.enviandoRecuperar ? 'Enviando…' : 'Enviar enlace'),
                    ),
                  ],
          ),
        );
      },
    );
  }
}
