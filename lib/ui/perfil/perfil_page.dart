import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../contenedor.dart';
import '../../domain/formato.dart';
import '../../domain/modelos.dart';
import '../../domain/repositorios.dart';
import '../../domain/resultado.dart';
import '../../domain/validadores.dart';
import '../componentes.dart';
import '../modelo_vista.dart';
import 'dialogo_servidor.dart';

/// Ventanas de "Mi cuenta" en Perfil.
enum DialogoCuenta { editarDatos, cambiarContrasena, eliminarCuenta }

class PerfilViewModel extends ModeloVista {
  PerfilViewModel(this._empresas, this._auth, this._favoritos, this._limpiarDatosLocales)
      : email = _auth.sesionActual?.email,
        esDemo = _auth.esModoDemo,
        correoVerificado = _auth.sesionActual?.correoVerificado ?? false {
    cargar();
  }

  final EmpresaRepository _empresas;
  final AuthRepository _auth;
  final FavoritosRepository _favoritos;
  final Future<void> Function() _limpiarDatosLocales;

  static const String datosActualizados = 'Datos actualizados.';
  static const String contrasenaCambiada = 'Contraseña cambiada. Úsala la próxima vez que ingreses.';

  final String? email;
  final bool esDemo;
  final bool correoVerificado;
  Empresa? empresa;
  bool cargando = true;
  ErrorApp? error;
  DialogoCuenta? dialogo;
  bool procesando = false;
  String? errorDialogo;

  /// Aviso corto después de un cambio correcto (por ejemplo "Datos actualizados.").
  String? mensaje;

  Future<void> cargar() async {
    cargando = true;
    error = null;
    avisar();
    final r = await _empresas.miEmpresa();
    if (cerrado) return;
    cargando = false;
    if (r is Exito<Empresa?>) {
      empresa = r.datos;
    } else {
      error = r.errorONull;
    }
    avisar();
  }

  /// Cierra sesión y borra la caché privada del teléfono (reservas y equipos propios).
  Future<void> cerrarSesion() async {
    await _limpiarDatosLocales();
    await _auth.cerrarSesion();
  }

  void abrirDialogo(DialogoCuenta nuevo) {
    dialogo = nuevo;
    errorDialogo = null;
    mensaje = null;
    avisar();
  }

  void cerrarDialogo() {
    if (procesando) return;
    dialogo = null;
    errorDialogo = null;
    avisar();
  }

  /// Derecho de rectificación: corrige la razón social y el celular. El RUC no cambia.
  Future<void> guardarDatos(String razonSocial, String telefono) async {
    final actual = empresa;
    if (actual == null || procesando) return;
    final falla = Validadores.razonSocial(razonSocial) ?? Validadores.telefono(telefono);
    if (falla != null) {
      errorDialogo = falla;
      avisar();
      return;
    }
    procesando = true;
    errorDialogo = null;
    avisar();
    final r = await _empresas.guardar(actual.ruc, razonSocial.trim(), telefono.trim());
    if (cerrado) return;
    procesando = false;
    if (r is Exito<Empresa>) {
      empresa = r.datos;
      dialogo = null;
      mensaje = datosActualizados;
    } else {
      errorDialogo = r.errorONull!.mensaje;
    }
    avisar();
  }

  Future<void> cambiarContrasena(String actual, String nueva, String confirmacion) async {
    if (procesando) return;
    final falla = actual.isEmpty
        ? 'Escribe tu contraseña actual.'
        : Validadores.password(nueva) ??
            Validadores.confirmacion(nueva, confirmacion) ??
            (nueva == actual ? 'La contraseña nueva debe ser distinta de la actual.' : null);
    if (falla != null) {
      errorDialogo = falla;
      avisar();
      return;
    }
    procesando = true;
    errorDialogo = null;
    avisar();
    final r = await _auth.cambiarContrasena(actual, nueva);
    if (cerrado) return;
    procesando = false;
    if (r.esExito) {
      dialogo = null;
      mensaje = contrasenaCambiada;
    } else {
      errorDialogo = r.errorONull!.mensaje;
    }
    avisar();
  }

  /// Derecho de cancelación: borra la cuenta en este orden, deteniéndose en el primer error:
  /// 1) confirma la contraseña, 2) borra la empresa y sus equipos en el servidor (falla si hay
  /// reservas activas), 3) borra favoritos y consentimiento, 4) limpia el teléfono y
  /// 5) borra el usuario de inicio de sesión. Los pasos 2 y 3 se pueden repetir sin problema.
  Future<void> eliminarCuenta(String password) async {
    if (procesando) return;
    if (!esDemo && password.isEmpty) {
      errorDialogo = 'Escribe tu contraseña para confirmar.';
      avisar();
      return;
    }
    procesando = true;
    errorDialogo = null;
    avisar();
    var falla = esDemo ? null : (await _auth.confirmarContrasena(password)).errorONull?.mensaje;
    falla ??= (await _empresas.eliminarMiCuenta()).errorONull?.mensaje;
    falla ??= (await _favoritos.borrarMisDatos()).errorONull?.mensaje;
    if (falla == null) {
      await _limpiarDatosLocales();
      falla = (await _auth.eliminarUsuario()).errorONull?.mensaje;
    }
    if (cerrado) return;
    procesando = false;
    if (falla == null) {
      dialogo = null;
    } else {
      errorDialogo = falla;
    }
    avisar();
  }
}

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  late final PerfilViewModel vm;

  /// Ventana de "Mi cuenta" abierta en este momento (en Kotlin es parte de la pantalla;
  /// en Flutter es una ruta aparte, por eso se cierra a mano cuando la pantalla deja de existir).
  DialogRoute<void>? _ruta;

  @override
  void initState() {
    super.initState();
    final c = context.read<Contenedor>();
    vm = PerfilViewModel(c.empresas, c.auth, c.favoritos, c.limpiarDatosDeSesion);
    vm.addListener(_alCambiar);
  }

  static void _quitar(DialogRoute<void> ruta) {
    if (ruta.isCurrent) {
      ruta.navigator?.pop();
    } else if (ruta.isActive) {
      ruta.navigator?.removeRoute(ruta);
    }
  }

  /// Cuando el ViewModel cierra la ventana (por ejemplo, al guardar), también se quita de la pantalla.
  void _alCambiar() {
    final ruta = _ruta;
    if (ruta != null && vm.dialogo == null) {
      _ruta = null;
      _quitar(ruta);
    }
  }

  @override
  void dispose() {
    // Si la cuenta se eliminó, la app vuelve al inicio de sesión: la ventana abierta también se va.
    final ruta = _ruta;
    _ruta = null;
    if (ruta != null) WidgetsBinding.instance.addPostFrameCallback((_) => _quitar(ruta));
    vm.removeListener(_alCambiar);
    vm.dispose();
    super.dispose();
  }

  Future<void> _abrir(DialogoCuenta dialogo) async {
    vm.abrirDialogo(dialogo);
    final ruta = DialogRoute<void>(
      context: context,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      builder: (_) => ListenableBuilder(
        listenable: vm,
        builder: (context, _) => PopScope(
          canPop: !vm.procesando,
          child: switch (dialogo) {
            DialogoCuenta.editarDatos => _DialogoEditarDatos(vm: vm),
            DialogoCuenta.cambiarContrasena => _DialogoCambiarContrasena(vm: vm),
            DialogoCuenta.eliminarCuenta => _DialogoEliminarCuenta(vm: vm),
          },
        ),
      ),
    );
    _ruta = ruta;
    await Navigator.of(context, rootNavigator: true).push(ruta);
    // Se cerró tocando fuera o con "atrás".
    if (identical(_ruta, ruta)) {
      _ruta = null;
      vm.cerrarDialogo();
    }
  }

  Future<void> _confirmarSalida() async {
    final si = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Se borrarán de este teléfono tus reservas y equipos guardados para proteger tu información.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(contexto).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(contexto).pop(true), child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (si == true) await vm.cerrarSesion();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil de la empresa')),
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) {
          final e = vm.empresa;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Círculo con las iniciales de la empresa.
                          Container(
                            width: 52,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: tema.colorScheme.primary, shape: BoxShape.circle),
                            child: Text(
                              Formato.iniciales(e?.razonSocial),
                              style: tema.textTheme.titleMedium?.copyWith(
                                color: tema.colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              e?.razonSocial ?? (vm.cargando ? 'Cargando…' : 'Empresa'),
                              style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      if (e != null) ...[
                        const SizedBox(height: 4),
                        Text('RUC: ${e.ruc}${e.verificada ? '  ✓ verificado' : ''}', style: tema.textTheme.bodyMedium),
                        Text('Celular: ${e.telefono}', style: tema.textTheme.bodyMedium),
                        Row(
                          children: [
                            Text('Como arrendatario: ', style: tema.textTheme.bodySmall),
                            Estrellas(valor: e.calificacionComoArrendatario, tamano: 14),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                Formato.calificacion(e.calificacionComoArrendatario, e.totalResenasComoArrendatario),
                                style: tema.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                      Text(
                        'Correo: ${vm.email ?? '-'}${(vm.correoVerificado && !vm.esDemo) ? '  ✓ verificado' : ''}',
                        style: tema.textTheme.bodySmall,
                      ),
                      if (vm.mensaje != null)
                        Text(vm.mensaje!, style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.primary)),
                      if (vm.error != null) ...[
                        Text(vm.error!.mensaje, style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.error)),
                        TextButton(onPressed: vm.cargar, child: const Text('Reintentar')),
                      ],
                    ],
                  ),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Acerca de EQUISHARE', style: tema.textTheme.titleSmall),
                      Text('Alquiler y préstamo de equipos entre empresas de Trujillo.', style: tema.textTheme.bodySmall),
                      Text('Versión ${Config.version}', style: tema.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
              TarjetaMiCuenta(
                puedeEditar: e != null,
                esDemo: vm.esDemo,
                alEditar: () => _abrir(DialogoCuenta.editarDatos),
                alCambiarContrasena: () => _abrir(DialogoCuenta.cambiarContrasena),
                alEliminar: () => _abrir(DialogoCuenta.eliminarCuenta),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => mostrarDialogoServidor(context, alGuardar: vm.cargar),
                icon: const Icon(Icons.dns_outlined),
                label: const Text('Conexión con el servidor'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const PrivacidadPage()),
                ),
                icon: const Icon(Icons.privacy_tip_outlined),
                label: const Text('Privacidad y uso ético'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _confirmarSalida,
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Tarjeta "Mi cuenta" de Perfil: editar datos, cambiar contraseña y eliminar la cuenta.
class TarjetaMiCuenta extends StatelessWidget {
  const TarjetaMiCuenta({
    super.key,
    required this.puedeEditar,
    required this.esDemo,
    required this.alEditar,
    required this.alCambiarContrasena,
    required this.alEliminar,
  });

  final bool puedeEditar;
  final bool esDemo;
  final VoidCallback alEditar;
  final VoidCallback alCambiarContrasena;
  final VoidCallback alEliminar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Mi cuenta', style: tema.textTheme.titleSmall),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: puedeEditar ? alEditar : null,
              icon: const Icon(Icons.edit),
              label: const Text('Editar datos de la empresa'),
            ),
            if (!esDemo) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: alCambiarContrasena,
                icon: const Icon(Icons.lock),
                label: const Text('Cambiar contraseña'),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: alEliminar,
              style: OutlinedButton.styleFrom(foregroundColor: tema.colorScheme.error),
              icon: const Icon(Icons.delete),
              label: const Text('Eliminar mi cuenta'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogoEditarDatos extends StatefulWidget {
  const _DialogoEditarDatos({required this.vm});

  final PerfilViewModel vm;

  @override
  State<_DialogoEditarDatos> createState() => _DialogoEditarDatosState();
}

class _DialogoEditarDatosState extends State<_DialogoEditarDatos> {
  late final TextEditingController _razon = TextEditingController(text: widget.vm.empresa?.razonSocial ?? '');
  late final TextEditingController _telefono = TextEditingController(text: widget.vm.empresa?.telefono ?? '');

  @override
  void dispose() {
    _razon.dispose();
    _telefono.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    return AlertDialog(
      title: const Text('Editar datos de la empresa'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('RUC: ${vm.empresa?.ruc ?? ''} (no se puede cambiar)', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            TextField(controller: _razon, decoration: const InputDecoration(labelText: 'Razón social')),
            const SizedBox(height: 8),
            TextField(
              controller: _telefono,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
              decoration: const InputDecoration(labelText: 'Celular de contacto'),
            ),
            _ErrorDialogo(vm.errorDialogo),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: vm.procesando ? null : vm.cerrarDialogo, child: const Text('Cancelar')),
        TextButton(
          onPressed: vm.procesando ? null : () => vm.guardarDatos(_razon.text, _telefono.text),
          child: Text(vm.procesando ? 'Guardando…' : 'Guardar'),
        ),
      ],
    );
  }
}

class _DialogoCambiarContrasena extends StatefulWidget {
  const _DialogoCambiarContrasena({required this.vm});

  final PerfilViewModel vm;

  @override
  State<_DialogoCambiarContrasena> createState() => _DialogoCambiarContrasenaState();
}

class _DialogoCambiarContrasenaState extends State<_DialogoCambiarContrasena> {
  final TextEditingController _actual = TextEditingController();
  final TextEditingController _nueva = TextEditingController();
  final TextEditingController _confirmacion = TextEditingController();

  @override
  void dispose() {
    _actual.dispose();
    _nueva.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    return AlertDialog(
      title: const Text('Cambiar contraseña'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CampoContrasena(controlador: _actual, etiqueta: 'Contraseña actual'),
            const SizedBox(height: 8),
            _CampoContrasena(controlador: _nueva, etiqueta: 'Contraseña nueva'),
            const SizedBox(height: 8),
            _CampoContrasena(controlador: _confirmacion, etiqueta: 'Repite la contraseña nueva'),
            _ErrorDialogo(vm.errorDialogo),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: vm.procesando ? null : vm.cerrarDialogo, child: const Text('Cancelar')),
        TextButton(
          onPressed: vm.procesando ? null : () => vm.cambiarContrasena(_actual.text, _nueva.text, _confirmacion.text),
          child: Text(vm.procesando ? 'Cambiando…' : 'Cambiar'),
        ),
      ],
    );
  }
}

class _DialogoEliminarCuenta extends StatefulWidget {
  const _DialogoEliminarCuenta({required this.vm});

  final PerfilViewModel vm;

  @override
  State<_DialogoEliminarCuenta> createState() => _DialogoEliminarCuentaState();
}

class _DialogoEliminarCuentaState extends State<_DialogoEliminarCuenta> {
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final error = Theme.of(context).colorScheme.error;
    return AlertDialog(
      title: const Text('¿Eliminar tu cuenta?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Se borrarán tu empresa, tus equipos publicados, tus favoritos y tu usuario. '
              'Las reservas terminadas quedarán como «Empresa eliminada». Esto no se puede deshacer.',
            ),
            if (!vm.esDemo) ...[
              const SizedBox(height: 8),
              _CampoContrasena(controlador: _password, etiqueta: 'Tu contraseña'),
            ],
            _ErrorDialogo(vm.errorDialogo),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: vm.procesando ? null : vm.cerrarDialogo, child: const Text('Cancelar')),
        TextButton(
          onPressed: vm.procesando ? null : () => vm.eliminarCuenta(_password.text),
          child: Text(vm.procesando ? 'Eliminando…' : 'Eliminar definitivamente', style: TextStyle(color: error)),
        ),
      ],
    );
  }
}

class _CampoContrasena extends StatelessWidget {
  const _CampoContrasena({required this.controlador, required this.etiqueta});

  final TextEditingController controlador;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controlador,
      obscureText: true,
      keyboardType: TextInputType.visiblePassword,
      decoration: InputDecoration(labelText: etiqueta),
    );
  }
}

class _ErrorDialogo extends StatelessWidget {
  const _ErrorDialogo(this.error);

  final String? error;

  @override
  Widget build(BuildContext context) {
    final texto = error;
    if (texto == null) return const SizedBox.shrink();
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(texto, style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.error)),
    );
  }
}

class PrivacidadPage extends StatelessWidget {
  const PrivacidadPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacidad y uso ético')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: TextoPoliticaPrivacidad(),
      ),
    );
  }
}
