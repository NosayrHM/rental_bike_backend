import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import '../screen/login_screen.dart';

/// Handler centralizado para deep links multiplataforma
class DeepLinkHandler {
  StreamSubscription? _sub;
  AppLinks? _appLinks;

  void init(BuildContext context) {
    _appLinks = AppLinks();
    // Escucha enlaces mientras la app está abierta
    _sub = _appLinks!.uriLinkStream.listen((Uri uri) {
      // ignore: use_build_context_synchronously
      _handleUri(context, uri);
    }, onError: (err) {
      // Manejo de errores de enlaces
    });
    // Para enlaces recibidos con la app cerrada
    _appLinks!.getInitialAppLink().then((uri) {
      if (uri != null) {
        // ignore: use_build_context_synchronously
        _handleUri(context, uri);
      }
    });
  }

  void dispose() {
    _sub?.cancel();
    _appLinks = null;
  }

  void _handleUri(BuildContext context, Uri uri) {
    if (uri.scheme == 'myapp' && uri.host == 'auth-callback') {
      final verified = uri.queryParameters['verified'] == '1';
      final type = uri.queryParameters['type'] ?? '';

      if (type == 'signup') {
        final message = verified
            ? 'Cuenta verificada. Inicia sesion para continuar.'
            : 'No se pudo verificar el correo. Solicita un nuevo enlace.';

        // Ensure navigation and snackbar run after current frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) {
            return;
          }
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        });
      }
    }
  }
}