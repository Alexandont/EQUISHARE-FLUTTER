import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../contenedor.dart';
import '../../domain/compat_kotlin.dart';
import '../../domain/ia/lector_ruc.dart';
import '../../domain/modelos.dart';
import '../../domain/repositorios.dart';
import '../../domain/resultado.dart';
import '../../domain/validadores.dart';
import '../modelo_vista.dart';

/// La empresa registra y verifica su RUC antes de publicar o alquilar.
class CompletarPerfilViewModel extends ModeloVista {
  CompletarPerfilViewModel(this._empresas, this._favoritos, this._auth, this._lectorTexto);

  final EmpresaRepository _empresas;
  final FavoritosRepository _favoritos;
  final AuthRepository _auth;
  final LectorTextoFoto _lectorTexto;

  static const String avisoCompleto = 'Leímos el RUC y la razón social. Revísalos antes de continuar.';
  static const String avisoSoloRuc = 'Leímos el RUC. Escribe la razón social y revisa los datos.';
  static const String avisoSinRuc =
      'No encontramos un RUC válido en la foto. Toma una foto más nítida de la ficha RUC o escríbelo a mano.';
  static const String avisoSinLectura = 'No se pudo leer la foto. Escribe el RUC a mano.';
  static const String avisoSinCamara = 'No se encontró una app de cámara. Elige la foto de la galería.';

  String ruc = '';
  String razonSocial = '';
  String telefono = '';
  String? errorRuc;
  String? errorRazon;
  String? errorTelefono;
  bool guardando = false;
  String? errorGeneral;

  /// true mientras la IA del teléfono lee la foto de la ficha RUC.
  bool leyendoFoto = false;

  /// Resultado de leer la foto, para mostrarlo debajo de los botones.
  String? avisoFoto;

  /// Cada foto nueva reemplaza a la anterior (como cancelar el trabajo anterior en Kotlin).
  int _fotoActual = 0;

  static String _soloDigitos(String v, int max) {
    final d = filtrarCaracteres(v, esDigito);
    return d.length > max ? d.substring(0, max) : d;
  }

  void alCambiarRuc(String v) {
    ruc = _soloDigitos(v, 11);
    errorRuc = null;
    avisar();
  }

  void alCambiarRazon(String v) {
    razonSocial = v;
    errorRazon = null;
    avisar();
  }

  void alCambiarTelefono(String v) {
    telefono = _soloDigitos(v, 9);
    errorTelefono = null;
    avisar();
  }

  /// La IA del teléfono lee la foto de la ficha RUC y llena el RUC (y la razón social si la encuentra).
  /// Solo usa un RUC válido; si no lo encuentra, no cambia nada y lo dice.
  Future<void> alElegirFotoRuc(String? rutaFoto) async {
    if (rutaFoto == null) return;
    final esta = ++_fotoActual;
    leyendoFoto = true;
    avisoFoto = null;
    avisar();
    String? texto;
    try {
      texto = await _lectorTexto.leerTexto(rutaFoto);
    } catch (_) {
      texto = null;
    }
    if (cerrado || esta != _fotoActual) return;
    final datos = LectorRuc.extraer(texto);
    final rucLeido = datos.ruc;
    final razonLeida = datos.razonSocial;
    leyendoFoto = false;
    if (texto == null) {
      avisoFoto = avisoSinLectura;
    } else if (rucLeido == null) {
      avisoFoto = avisoSinRuc;
    } else if (razonLeida == null) {
      ruc = rucLeido;
      errorRuc = null;
      avisoFoto = avisoSoloRuc;
    } else {
      ruc = rucLeido;
      razonSocial = razonLeida;
      errorRuc = null;
      errorRazon = null;
      avisoFoto = avisoCompleto;
    }
    avisar();
  }

  /// El teléfono no tiene una app de cámara: se sugiere usar la galería.
  void sinCamara() {
    avisoFoto = avisoSinCamara;
    avisar();
  }

  Future<void> guardar(VoidCallback alTerminar) async {
    errorRuc = Validadores.ruc(ruc);
    errorRazon = Validadores.razonSocial(razonSocial);
    errorTelefono = Validadores.telefono(telefono);
    avisar();
    if (errorRuc != null || errorRazon != null || errorTelefono != null || guardando) return;
    guardando = true;
    errorGeneral = null;
    avisar();
    final r = await _empresas.guardar(ruc, razonSocial, telefono);
    if (cerrado) return;
    if (r is Fallo<Empresa>) {
      guardando = false;
      errorGeneral = [r.error.mensaje, ...r.error.detalles].join('\n');
      avisar();
      return;
    }
    await _favoritos.registrarConsentimiento(_auth.sesionActual?.email);
    if (cerrado) return;
    ruc = '';
    razonSocial = '';
    telefono = '';
    guardando = false;
    leyendoFoto = false;
    avisoFoto = null;
    avisar();
    alTerminar();
  }

  Future<void> cerrarSesion() => _auth.cerrarSesion();
}

class CompletarPerfilPage extends StatefulWidget {
  const CompletarPerfilPage({super.key, required this.alTerminar});

  final VoidCallback alTerminar;

  @override
  State<CompletarPerfilPage> createState() => _CompletarPerfilPageState();
}

class _CompletarPerfilPageState extends State<CompletarPerfilPage> {
  late final CompletarPerfilViewModel vm;
  final TextEditingController _ruc = TextEditingController();
  final TextEditingController _razon = TextEditingController();
  final TextEditingController _telefono = TextEditingController();

  @override
  void initState() {
    super.initState();
    final c = context.read<Contenedor>();
    vm = CompletarPerfilViewModel(c.empresas, c.favoritos, c.auth, c.lectorTexto);
    vm.addListener(_sincronizar);
  }

  /// Cuando la IA llena el RUC o la razón social, también se actualizan los campos de texto.
  void _sincronizar() {
    _poner(_ruc, vm.ruc);
    _poner(_razon, vm.razonSocial);
    _poner(_telefono, vm.telefono);
  }

  static void _poner(TextEditingController campo, String valor) {
    if (campo.text == valor) return;
    campo.value = TextEditingValue(text: valor, selection: TextSelection.collapsed(offset: valor.length));
  }

  @override
  void dispose() {
    vm.removeListener(_sincronizar);
    vm.dispose();
    _ruc.dispose();
    _razon.dispose();
    _telefono.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListenableBuilder(
              listenable: vm,
              builder: (context, _) => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Icon(Icons.verified, size: 48, color: tema.colorScheme.primary),
                    ),
                    const SizedBox(height: 8),
                    Text('Registra tu empresa', style: tema.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Para publicar o alquilar equipos debes registrar el RUC de tu empresa. '
                          'Antes de continuar verificamos que el número de RUC sea válido.',
                          style: tema.textTheme.bodySmall,
                        ),
                      ),
                    ),
                    // La IA de ML Kit solo existe en el teléfono (en la web no se muestra esta tarjeta).
                    if (!kIsWeb) ...[
                      const SizedBox(height: 12),
                      LeerRucDesdeFoto(
                        leyendo: vm.leyendoFoto,
                        aviso: vm.avisoFoto,
                        alElegirFoto: vm.alElegirFotoRuc,
                        alFaltarCamara: vm.sinCamara,
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _ruc,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
                      decoration: InputDecoration(
                        labelText: 'RUC (11 dígitos)',
                        prefixIcon: const Icon(Icons.verified_outlined),
                        errorText: vm.errorRuc,
                      ),
                      onChanged: vm.alCambiarRuc,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _razon,
                      decoration: InputDecoration(
                        labelText: 'Razón social',
                        prefixIcon: const Icon(Icons.business),
                        errorText: vm.errorRazon,
                      ),
                      onChanged: vm.alCambiarRazon,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _telefono,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
                      decoration: InputDecoration(
                        labelText: 'Celular de contacto',
                        prefixIcon: const Icon(Icons.phone),
                        errorText: vm.errorTelefono,
                      ),
                      onChanged: vm.alCambiarTelefono,
                    ),
                    if (vm.errorGeneral != null) ...[
                      const SizedBox(height: 12),
                      Text(vm.errorGeneral!, style: TextStyle(color: tema.colorScheme.error)),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: vm.guardando ? null : () => vm.guardar(widget.alTerminar),
                        child: vm.guardando
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Verificar y continuar'),
                      ),
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

/// Tarjeta "Leer RUC desde una foto": la empresa toma una foto de su ficha RUC (o elige una captura)
/// y la IA del teléfono llena el RUC y la razón social. La foto no sale del teléfono.
class LeerRucDesdeFoto extends StatelessWidget {
  const LeerRucDesdeFoto({
    super.key,
    required this.leyendo,
    required this.aviso,
    required this.alElegirFoto,
    required this.alFaltarCamara,
  });

  final bool leyendo;
  final String? aviso;
  final void Function(String? rutaFoto) alElegirFoto;
  final VoidCallback alFaltarCamara;

  /// Las letras pequeñas necesitan detalle: se pide la foto de hasta 2048 px por lado (como en Kotlin).
  static const double _ladoTexto = 2048;

  Future<void> _elegir(ImageSource fuente) async {
    try {
      final foto = await ImagePicker().pickImage(source: fuente, maxWidth: _ladoTexto, maxHeight: _ladoTexto);
      if (foto != null) alElegirFoto(foto.path);
    } on PlatformException catch (e) {
      if (fuente == ImageSource.camera && e.code.contains('camera')) {
        alFaltarCamara();
      } else {
        alElegirFoto(null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('¿Tienes tu ficha RUC a la mano?', style: tema.textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              'Toma una foto o elige una captura y la IA del teléfono llenará el RUC y la razón social.',
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: leyendo ? null : () => _elegir(ImageSource.camera),
                    icon: const Icon(Icons.add_a_photo),
                    label: const Text('Tomar foto'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: leyendo ? null : () => _elegir(ImageSource.gallery),
                    child: const Text('Elegir imagen'),
                  ),
                ),
              ],
            ),
            if (leyendo) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 10),
                  Text('Leyendo la foto con IA…', style: tema.textTheme.bodyMedium),
                ],
              ),
            ],
            if (aviso != null) ...[
              const SizedBox(height: 8),
              Text(aviso!, style: tema.textTheme.bodySmall?.copyWith(color: tema.colorScheme.primary)),
            ],
          ],
        ),
      ),
    );
  }
}
