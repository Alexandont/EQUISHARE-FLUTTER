import 'package:flutter/foundation.dart';

/// Base de los ViewModel (MVVM): guarda el estado de la pantalla y avisa cuando cambia.
/// Evita avisar después de que la pantalla se cerró.
abstract class ModeloVista extends ChangeNotifier {
  bool _cerrado = false;

  bool get cerrado => _cerrado;

  void avisar() {
    if (!_cerrado) notifyListeners();
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
