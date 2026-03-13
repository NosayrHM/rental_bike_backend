import 'package:flutter/material.dart';

class EmailVerificationPendingScreen extends StatelessWidget {
  const EmailVerificationPendingScreen({
    super.key,
    required this.email,
  });

  final String email;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 53, 59, 74),
      body: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.97),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Estamos verificando tu email',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              Text(
                'Hemos enviado un enlace de verificacion a:\n$email',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Abre el correo y pulsa el enlace. Te redirigiremos automaticamente a la app para iniciar sesion.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Esperando confirmacion del correo...',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
