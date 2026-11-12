import 'package:flutter/material.dart';

import '../../domain/repositorios.dart';
import '../modelo_vista.dart';

/// Pantallas de bienvenida: se muestran solo la primera vez que se abre la app.
class BienvenidaViewModel extends ModeloVista {
  BienvenidaViewModel(this._ajustes) : mostrar = !_ajustes.bienvenidaVista;

  final AjustesRepository _ajustes;

  /// true si hay que mostrar la bienvenida.
  bool mostrar;

  Future<void> terminar() async {
    await _ajustes.marcarBienvenidaVista();
    mostrar = false;
    avisar();
  }
}

class _PaginaBienvenida {
  const _PaginaBienvenida(this.icono, this.titulo, this.texto);
  final IconData icono;
  final String titulo;
  final String texto;
}

const List<_PaginaBienvenida> _paginas = [
  _PaginaBienvenida(
    Icons.handshake,
    'Bienvenido a EQUISHARE',
    'Alquila y comparte equipos entre empresas de Trujillo. Lo que tu empresa no usa, otra lo necesita.',
  ),
  _PaginaBienvenida(
    Icons.map,
    'Encuentra equipos cerca',
    'Busca en el catálogo o en el mapa. Cambia la capa a Satélite para ver la obra y toca un equipo para centrarlo.',
  ),
  _PaginaBienvenida(
    Icons.camera_alt,
    'Publica en un minuto',
    'Toma la foto del equipo y la IA del teléfono sugiere la categoría. Escribe la dirección y el mapa la ubica.',
  ),
  _PaginaBienvenida(
    Icons.verified,
    'Empresas verificadas',
    'Cada empresa verifica su correo y su RUC. Tu cuenta y tus datos están protegidos, y puedes borrarlos cuando quieras.',
  ),
];

/// Cuatro pantallas que se deslizan con el dedo y explican la app la primera vez que se abre.
class BienvenidaPage extends StatefulWidget {
  const BienvenidaPage({super.key, required this.alTerminar});

  final VoidCallback alTerminar;

  @override
  State<BienvenidaPage> createState() => _BienvenidaPageState();
}

class _BienvenidaPageState extends State<BienvenidaPage> {
  final PageController _paginador = PageController();
  int _actual = 0;

  bool get _esUltima => _actual == _paginas.length - 1;

  @override
  void dispose() {
    _paginador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: widget.alTerminar, child: const Text('Saltar')),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _paginador,
                  itemCount: _paginas.length,
                  onPageChanged: (i) => setState(() => _actual = i),
                  itemBuilder: (context, indice) {
                    final pagina = _paginas[indice];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(color: tema.colorScheme.primaryContainer, shape: BoxShape.circle),
                          child: Icon(pagina.icono, size: 64, color: tema.colorScheme.primary),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          pagina.titulo,
                          textAlign: TextAlign.center,
                          style: tema.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          pagina.texto,
                          textAlign: TextAlign.center,
                          style: tema.textTheme.bodyLarge?.copyWith(color: tema.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _paginas.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: i == _actual ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == _actual ? tema.colorScheme.primary : tema.colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    if (_esUltima) {
                      widget.alTerminar();
                    } else {
                      _paginador.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                    }
                  },
                  child: Text(_esUltima ? 'Empezar' : 'Siguiente'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
