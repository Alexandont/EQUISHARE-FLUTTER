import 'dart:convert';

import 'package:hive_ce_flutter/hive_ce_flutter.dart';

/// Persistencia local con Hive (equivale a Room + DataStore de la versión Kotlin).
/// Funciona en Android (archivos de la app) y en web (IndexedDB del navegador).
///  - Caja "cache": catálogo, equipos propios y reservas en JSON, para usar la app sin conexión.
///  - Caja "ajustes": dirección del servidor, último filtro y sesión del modo demostración.
/// No se guardan contraseñas ni tokens.
class AlmacenLocal {
  AlmacenLocal._(this._cache, this._ajustes);

  final Box<String> _cache;
  final Box<String> _ajustes;

  static Future<AlmacenLocal> abrir() async {
    await Hive.initFlutter();
    final cache = await Hive.openBox<String>('cache');
    final ajustes = await Hive.openBox<String>('ajustes');
    return AlmacenLocal._(cache, ajustes);
  }

  List<Map<String, dynamic>> leerLista(String clave) {
    final texto = _cache.get(clave);
    if (texto == null) return [];
    try {
      final datos = jsonDecode(texto);
      if (datos is! List) return [];
      return datos.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> guardarLista(String clave, List<Map<String, dynamic>> items) => _cache.put(clave, jsonEncode(items));

  Future<void> borrar(String clave) => _cache.delete(clave);

  String? leerAjuste(String clave) => _ajustes.get(clave);

  Future<void> guardarAjuste(String clave, String? valor) =>
      valor == null ? _ajustes.delete(clave) : _ajustes.put(clave, valor);
}
