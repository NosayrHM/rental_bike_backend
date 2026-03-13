import 'package:flutter/material.dart';
import 'register_screen.dart';
import 'splash_screen.dart';
import '../services/user_service.dart';
import 'main_menu_screen.dart';
import 'animated_intro_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.initialEmail,
  });

  final String? initialEmail;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _showPassword = false;
  String? errorText;

  @override
  void initState() {
    super.initState();
    final initialEmail = widget.initialEmail?.trim() ?? '';
    if (initialEmail.isNotEmpty) {
      emailController.text = initialEmail;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 53, 59, 74),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: SingleChildScrollView(
              child: Container(
                width: constraints.maxWidth < 500 ? constraints.maxWidth * 0.95 : 420,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Iniciar sesión', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                    if (errorText != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 12, bottom: 4),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Color(0xFFFFE3E3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          errorText!,
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                        ),
                      ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Correo electrónico',
                        prefixIcon: const Icon(Icons.email_outlined, size: 20, color: Colors.grey),
                        border: InputBorder.none,
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFBDBDBD)),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF43cea2), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        filled: true,
                        fillColor: Colors.transparent,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: !_showPassword,
                      style: const TextStyle(fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20, color: Colors.grey),
                        border: InputBorder.none,
                        enabledBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFBDBDBD)),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF43cea2), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        filled: true,
                        fillColor: Colors.transparent,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _showPassword = !_showPassword;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () async {
                          final controller = TextEditingController(text: emailController.text);
                          final result = await showDialog<String>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Recuperar contraseña'),
                              content: TextField(
                                controller: controller,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Correo electrónico',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancelar'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    final email = controller.text.trim();
                                    if (email.isEmpty || !email.contains('@')) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Introduce un correo válido.')),
                                      );
                                    } else {
                                      Navigator.pop(context, email);
                                    }
                                  },
                                  child: const Text('Enviar'),
                                ),
                              ],
                            ),
                          );
                          if (result != null && result.isNotEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Se ha enviado un correo de recuperación a $result')),
                            );
                          }
                        },
                        child: const Text('¿Olvidaste tu contraseña?'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Colors.black, width: 2),
                          ),
                        ),
                        onPressed: () async {
                          final email = emailController.text.trim();
                          final password = passwordController.text;
                          setState(() {
                            errorText = null;
                          });
                          if (email.isEmpty || !email.contains('@') || password.isEmpty) {
                            setState(() {
                              errorText = 'Faltan campos por rellenar';
                            });
                            return;
                          } else if (password.length < 6) {
                            setState(() {
                              errorText = 'La contraseña debe tener al menos 6 caracteres.';
                            });
                            return;
                          }
                          // Lógica de login real
                          try {
                            final user = await UserService().login(email, password);
                            if (user != null) {
                              // Login exitoso, mostrar animación y luego menú principal
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => AnimatedIntroScreen(
                                    onAnimationEnd: () {
                                      // Usar contexto raíz para evitar problemas de contexto cerrado
                                      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                                        MaterialPageRoute(builder: (_) => MainMenuScreen()),
                                        (route) => false,
                                      );
                                    },
                                  ),
                                ),
                                (route) => false,
                              );
                            } else {
                              setState(() {
                                errorText = 'Contraseña o correo incorrectos o error de red';
                              });
                            }
                          } catch (e) {
                            setState(() {
                              errorText = e.toString().replaceFirst('Exception: ', '');
                            });
                          }
                        },
                        child: const Text('Iniciar sesión'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => RegisterScreen()),
                            );
                          },
                          child: const Text('¿No tienes cuenta? Regístrate'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => SplashScreen()),
                              (route) => false,
                            );
                          },
                          child: const Text('Volver al inicio'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}