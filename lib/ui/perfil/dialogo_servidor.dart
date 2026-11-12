import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../contenedor.dart';
import '../../domain/repositorios.dart';
import '../../domain/resultado.dart';
import '../../domain/validadores.dart';
import '../modelo_vista.dart';

/// Configura la dirección del servidor Node.js (emulador: http://10.0.2.2:3000/, navegador: http://localhost:3000/).
class ServidorViewModel extends ModeloVista {
  ServidorViewModel(this._ajustes) : url = _ajustes.urlServidor;

  final AjustesRepository _ajustes;
  String url;
  bool probando = false;
  String? mensaje;
  bool exito = false;

  void alCambiarUrl(String v) {
    url = v;
    mensaje = null;
    exito = false;
    avisar();
  }

  Future<void> probarYGuardar(VoidCallback alGuardar) async {
    final normalizada = Validadores.normalizarUrlServidor(url);
    if (normalizada == null) {
      mensaje = 'Escribe una dirección válida, por ejemplo http://192.168.1.50:3000/';
      exito = false;
      avisar();
      return;
    }
    url = normalizada;
    probando = true;
    mensaje = null;
    avisar();
    final r = await _ajustes.probarServidor(normalizada);
    if (cerrado) return;
    probando = false;
    if (r is Exito<String>) {
      await _ajustes.guardarUrlServidor(normalizada);
      exito = true;
      mensaje = 'Conectado. Autenticación del servidor: ${r.datos}.';
      avisar();
      alGuardar();
    } else {
      exito = false;
      mensaje = 'No se pudo conectar: ${r.errorONull?.mensaje ?? 'error desconocido'}';
      avisar();
    }
  }
}

Future<void> mostrarDialogoServidor(BuildContext context, {VoidCallback? alGuardar}) {
  final ajustes = context.read<Contenedor>().ajustes;
  return showDialog<void>(
    context: context,
    builder: (_) => DialogoServidor(ajustes: ajustes, alGuardar: alGuardar ?? () {}),
  );
}

class DialogoServidor extends StatefulWidget {
  const DialogoServidor({super.key, required this.ajustes, required this.alGuardar});

  final AjustesRepository ajustes;
  final VoidCallback alGuardar;

  @override
  State<DialogoServidor> createState() => _DialogoServidorState();
}

class _DialogoServidorState extends State<DialogoServidor> {
  late final ServidorViewModel vm = ServidorViewModel(widget.ajustes);
  late final TextEditingController _url = TextEditingController(text: vm.url);

  @override
  void initState() {
    super.initState();
    vm.addListener(_sincronizar);
  }

  void _sincronizar() {
    if (_url.text != vm.url) _url.text = vm.url;
  }

  @override
  void dispose() {
    vm.removeListener(_sincronizar);
    vm.dispose();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) => AlertDialog(
        title: const Text('Servidor de EQUISHARE'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kIsWeb
                    ? 'En el navegador usa http://localhost:3000/ (la misma PC que ejecuta "npm start").'
                    : 'Emulador: http://10.0.2.2:3000/  ·  Celular físico: la IP de la PC que ejecuta '
                        '"npm start" (por ejemplo http://192.168.1.50:3000/), ambos en la misma red Wi-Fi.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _url,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'Dirección del servidor'),
                onChanged: vm.alCambiarUrl,
              ),
              if (vm.probando) const Padding(padding: EdgeInsets.only(top: 12), child: CircularProgressIndicator()),
              if (vm.mensaje != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    vm.mensaje!,
                    style: TextStyle(color: vm.exito ? esquema.secondary : esquema.error),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
          TextButton(
            onPressed: vm.probando ? null : () => vm.probarYGuardar(widget.alGuardar),
            child: const Text('Probar y guardar'),
          ),
        ],
      ),
    );
  }
}
