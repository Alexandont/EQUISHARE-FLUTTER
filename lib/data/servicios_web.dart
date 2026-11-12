import '../domain/repositorios.dart';

/*
 * En la web no existen ML Kit ni el Geocoder del teléfono: se usan versiones vacías
 * que nunca sugieren nada (la app sigue funcionando sin esas ayudas).
 */

AnalizadorFoto crearAnalizadorFoto() => const AnalizadorFotoNinguno();

LectorTextoFoto crearLectorTexto() => const LectorTextoFotoNinguno();

BuscadorDirecciones crearBuscadorDirecciones() => const BuscadorDireccionesNinguno();
