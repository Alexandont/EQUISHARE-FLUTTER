import 'package:flutter/material.dart';

import '../catalogo/catalogo_page.dart';
import '../detalle/detalle_page.dart';
import '../mapa/mapa_page.dart';
import '../mis_equipos/mis_equipos_page.dart';
import '../panel/panel.dart';
import '../perfil/perfil_page.dart';
import '../reservas/reservas_page.dart';

/// App principal con barra de navegación inferior (5 pestañas).
/// Cada pestaña se crea la primera vez que se visita y luego conserva su estado.
class PrincipalPage extends StatefulWidget {
  const PrincipalPage({super.key});

  @override
  State<PrincipalPage> createState() => _PrincipalPageState();
}

class _PrincipalPageState extends State<PrincipalPage> {
  int _indice = 0;
  final Set<int> _visitadas = {0};

  void _abrirEquipo(String id) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DetallePage(equipoId: id)));
  }

  Widget _pestana(int i) {
    if (!_visitadas.contains(i)) return const SizedBox.shrink();
    switch (i) {
      case 0:
        return CatalogoPage(alAbrirEquipo: _abrirEquipo, encabezado: const SaludoInicio());
      case 1:
        return MapaPage(alAbrirEquipo: _abrirEquipo);
      case 2:
        return const ReservasPage();
      case 3:
        return MisEquiposPage(alAbrirEquipo: _abrirEquipo, encabezado: const PanelMetricas());
      default:
        return const PerfilPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _indice,
        children: [for (var i = 0; i < 5; i++) _pestana(i)],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() {
          _indice = i;
          _visitadas.add(i);
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Catálogo'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Mapa'),
          NavigationDestination(icon: Icon(Icons.date_range), label: 'Reservas'),
          NavigationDestination(icon: Icon(Icons.build_outlined), selectedIcon: Icon(Icons.build), label: 'Mis equipos'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
