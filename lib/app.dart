import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'contenedor.dart';
import 'ui/raiz/raiz_page.dart';
import 'ui/tema.dart';

class EquishareApp extends StatelessWidget {
  const EquishareApp({super.key, required this.contenedor});

  final Contenedor contenedor;

  @override
  Widget build(BuildContext context) {
    return Provider<Contenedor>.value(
      value: contenedor,
      child: MaterialApp(
        title: 'EQUISHARE',
        debugShowCheckedModeBanner: false,
        theme: temaClaro(),
        darkTheme: temaOscuro(),
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const RaizPage(),
      ),
    );
  }
}
