import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../contenedor.dart';
import '../../domain/modelos.dart';
import '../../domain/repositorios.dart';
import '../../domain/resultado.dart';
import '../auth/completar_perfil_page.dart';
import '../auth/login_page.dart';
import '../auth/verificar_correo_page.dart';
import '../bienvenida/bienvenida_page.dart';
import '../componentes.dart';
import '../modelo_vista.dart';
import '../perfil/dialogo_servidor.dart';
import '../principal/principal_page.dart';

sealed class EstadoRaiz {
  const EstadoRaiz();
}

class RaizCargando extends EstadoRaiz {
  const RaizCargando();
}

class RaizSinSesion extends EstadoRaiz {
  const RaizSinSesion();
}

/// La cuenta existe pero todavía no abrió el enlace de verificación de su correo.
class RaizCorreoSinVerificar extends EstadoRaiz {
  const RaizCorreoSinVerificar(this.sesion);
  final Sesion sesion;
}

class RaizPerfilIncompleto extends EstadoRaiz {
  const RaizPerfilIncompleto(this.sesion);
  final Sesion sesion;
}

class RaizListo extends EstadoRaiz {
  const RaizListo(this.sesion, this.empresa);
  final Sesion sesion;
  final Empresa? empresa;
}

class RaizErrorServidor extends EstadoRaiz {
  const RaizErrorServidor(this.sesion, this.mensaje);
  final Sesion sesion;
  final String mensaje;
}

/// Decide qué mostrar al abrir la app: login, registro de empresa o la app principal.
class RaizViewModel extends ModeloVista {
  RaizViewModel(this._auth, this._empresas, this._favoritos) {
    _suscripcion = _auth.cambios.listen((_) => _evaluar());
  }

  final AuthRepository _auth;
  final EmpresaRepository _empresas;
  final FavoritosRepository _favoritos;
  late final StreamSubscription<Sesion?> _suscripcion;

  EstadoRaiz estado = const RaizCargando();
  bool _sinConexionAceptado = false;
  int _version = 0;

  /// Última sesión revisada. Se compara la sesión completa (como Kotlin): al verificar el correo
  /// cambia la sesión aunque el usuario sea el mismo, y hay que volver a revisar.
  Sesion? _sesionEvaluada;

  Future<void> _evaluar({bool forzar = false}) async {
    final version = ++_version;
    final sesion = _auth.sesionActual;
    if (!_auth.sesionCargada) {
      _poner(const RaizCargando());
      return;
    }
    if (sesion == null) {
      _sesionEvaluada = null;
      _sinConexionAceptado = false;
      _poner(const RaizSinSesion());
      return;
    }
    // Si la misma sesión ya se evaluó, no se vuelve a consultar el servidor.
    if (!forzar && sesion == _sesionEvaluada && estado is! RaizCargando) return;
    _sesionEvaluada = sesion;
    if (!sesion.correoVerificado) {
      _poner(RaizCorreoSinVerificar(sesion));
      return;
    }
    if (_sinConexionAceptado) {
      _poner(RaizListo(sesion, null));
      return;
    }
    _poner(const RaizCargando());
    final r = await _empresas.miEmpresa();
    if (cerrado || version != _version) return;
    if (r is Exito<Empresa?>) {
      final empresa = r.datos;
      _poner(empresa == null ? RaizPerfilIncompleto(sesion) : RaizListo(sesion, empresa));
      return;
    }
    final error = r.errorONull!;
    if (error.tipo == TipoError.noAutenticado) {
      await _auth.cerrarSesion();
      _poner(const RaizSinSesion());
    } else {
      _poner(RaizErrorServidor(sesion, error.mensaje));
    }
  }

  void _poner(EstadoRaiz nuevo) {
    estado = nuevo;
    avisar();
  }

  void reintentar() {
    _sinConexionAceptado = false;
    _evaluar(forzar: true);
  }

  /// Permite usar la app con la información guardada aunque el servidor no responda.
  void continuarSinConexion() {
    _sinConexionAceptado = true;
    _evaluar(forzar: true);
  }

  void perfilCompletado() => reintentar();

  Future<void> cerrarSesion() => _auth.cerrarSesion();

  Future<void> registrarConsentimiento(String? email) async {
    await _favoritos.registrarConsentimiento(email);
  }

  @override
  void dispose() {
    _suscripcion.cancel();
    super.dispose();
  }
}

class RaizPage extends StatefulWidget {
  const RaizPage({super.key});

  @override
  State<RaizPage> createState() => _RaizPageState();
}

class _RaizPageState extends State<RaizPage> {
  late final RaizViewModel vm;
  late final BienvenidaViewModel bienvenida;

  @override
  void initState() {
    super.initState();
    final c = context.read<Contenedor>();
    vm = RaizViewModel(c.auth, c.empresas, c.favoritos);
    bienvenida = BienvenidaViewModel(c.ajustes);
  }

  @override
  void dispose() {
    vm.dispose();
    bienvenida.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([vm, bienvenida]),
      builder: (context, _) {
        // La primera vez que se abre la app se muestran las pantallas de bienvenida.
        if (bienvenida.mostrar) return BienvenidaPage(alTerminar: bienvenida.terminar);
        final estado = vm.estado;
        if (estado is RaizSinSesion) return const LoginPage();
        if (estado is RaizCorreoSinVerificar) return const VerificarCorreoPage();
        if (estado is RaizPerfilIncompleto) return CompletarPerfilPage(alTerminar: vm.perfilCompletado);
        if (estado is RaizListo) return const PrincipalPage();
        if (estado is RaizErrorServidor) {
          return _PantallaSinServidor(
            mensaje: estado.mensaje,
            alReintentar: vm.reintentar,
            alContinuar: vm.continuarSinConexion,
            alCerrarSesion: vm.cerrarSesion,
          );
        }
        return const Scaffold(body: EstadoCargando(texto: 'Preparando EQUISHARE…'));
      },
    );
  }
}

class _PantallaSinServidor extends StatelessWidget {
  const _PantallaSinServidor({
    required this.mensaje,
    required this.alReintentar,
    required this.alContinuar,
    required this.alCerrarSesion,
  });

  final String mensaje;
  final VoidCallback alReintentar;
  final VoidCallback alContinuar;
  final VoidCallback alCerrarSesion;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No se pudo conectar con el servidor',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(mensaje, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(onPressed: alReintentar, child: const Text('Reintentar')),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => mostrarDialogoServidor(context, alGuardar: alReintentar),
                  child: const Text('Ajustes de conexión'),
                ),
                TextButton(onPressed: alContinuar, child: const Text('Usar datos guardados (sin conexión)')),
                TextButton(onPressed: alCerrarSesion, child: const Text('Cerrar sesión')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
