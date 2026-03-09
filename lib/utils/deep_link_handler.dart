import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';

/// Handler centralizado para deep links multiplataforma
class DeepLinkHandler {
  StreamSubscription? _sub;
  AppLinks? _appLinks;

  void init(BuildContext context) {
    _appLinks = AppLinks();
    // Escucha enlaces mientras la app está abierta
    _sub = _appLinks!.uriLinkStream.listen((Uri uri) {
      _handleUri(context, uri);
    }, onError: (err) {
      // Manejo de errores de enlaces
    });
    // Para enlaces recibidos con la app cerrada
    _appLinks!.getInitialAppLink().then((uri) {
      if (uri != null) {
        _handleUri(context, uri);
      }
    });
  }

  void dispose() {
    _sub?.cancel();
    _appLinks = null;
  }

  void _handleUri(BuildContext context, Uri uri) {
    // Ejemplo: myapp://auth-callback?type=signup
    if (uri.scheme == 'myapp' && uri.host == 'auth-callback') {
      // Aquí puedes mostrar un mensaje, navegar, etc.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('¡Cuenta confirmada! Ya puedes iniciar sesión.')),
      );
      // Puedes navegar a la pantalla de login o main
      // Navigator.of(context).pushReplacement(...)
    }
  }
}