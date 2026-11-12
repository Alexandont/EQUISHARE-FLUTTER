import 'package:flutter/material.dart';

// Paleta de marca (la misma de la versión Kotlin). Contrastes de texto de al menos 4.5:1.
const Color azulMarca = Color(0xFF1E3A5F);
const Color azulClaro = Color(0xFFD5E3F7);
const Color verdeConfirmar = Color(0xFF2E7D32);
const Color naranjaAcento = Color(0xFFB85C00);
const Color rojoError = Color(0xFFB3261E);
const Color dorado = Color(0xFFF2A100);

ThemeData temaClaro() {
  final esquema = ColorScheme.fromSeed(
    seedColor: azulMarca,
    primary: azulMarca,
    onPrimary: Colors.white,
    primaryContainer: azulClaro,
    onPrimaryContainer: const Color(0xFF0B1F36),
    secondary: verdeConfirmar,
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFFC8E6C9),
    onSecondaryContainer: const Color(0xFF0B3D0F),
    tertiary: naranjaAcento,
    onTertiary: Colors.white,
    tertiaryContainer: const Color(0xFFFFE0C2),
    onTertiaryContainer: const Color(0xFF3A1D00),
    error: rojoError,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: const Color(0xFFF7F9FC),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
  );
}

ThemeData temaOscuro() {
  final esquema = ColorScheme.fromSeed(
    seedColor: azulMarca,
    brightness: Brightness.dark,
    primary: const Color(0xFFA9C7F0),
    onPrimary: const Color(0xFF0B1F36),
    primaryContainer: const Color(0xFF2B4A70),
    onPrimaryContainer: azulClaro,
    secondary: const Color(0xFF8FD694),
    onSecondary: const Color(0xFF0B3D0F),
    secondaryContainer: const Color(0xFF1F5A23),
    onSecondaryContainer: const Color(0xFFC8E6C9),
    tertiary: const Color(0xFFFFB877),
    onTertiary: const Color(0xFF3A1D00),
    tertiaryContainer: const Color(0xFF6B3A00),
    onTertiaryContainer: const Color(0xFFFFE0C2),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
  );
}
