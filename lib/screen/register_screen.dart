import 'package:flutter/material.dart';
import 'email_verification_pending_screen.dart';
import '../services/user_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _showPassword = false;
  final nameController = TextEditingController();
  final lastNameController = TextEditingController();
  final phoneController = TextEditingController();
  String? errorText;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 53, 59, 74),
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        // color: Colors.white, // Elimina el fondo blanco
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(28.0),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 255, 255, 255).withOpacity(0.97),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.black, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Registro', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
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
                  const SizedBox(height: 24),
                  TextField(
                    controller: nameController,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Nombre',
                      prefixIcon: const Icon(Icons.person_outline, size: 20, color: Colors.grey),
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
                    controller: lastNameController,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Apellido',
                      prefixIcon: const Icon(Icons.person, size: 20, color: Colors.grey),
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
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Teléfono',
                      prefixIcon: const Icon(Icons.phone, size: 20, color: Colors.grey),
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
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('Volver'),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.black, width: 2),
                        ),
                      ),
                      onPressed: _submitting
                          ? null
                          : () async {
                              if (_submitting) {
                                return;
                              }

                              setState(() {
                                _submitting = true;
                                errorText = null;
                              });

                              final name = nameController.text.trim();
                              final lastName = lastNameController.text.trim();
                              final email = emailController.text.trim();
                              final password = passwordController.text;
                              final phone = phoneController.text.trim();

                              if (name.isEmpty || lastName.isEmpty || phone.isEmpty) {
                                setState(() {
                                  errorText = 'Faltan campos por rellenar';
                                  _submitting = false;
                                });
                                return;
                              }
                              if (email.isEmpty || !email.contains('@')) {
                                setState(() {
                                  errorText = 'Introduce un correo válido.';
                                  _submitting = false;
                                });
                                return;
                              }
                              if (password.isEmpty || password.length < 6) {
                                setState(() {
                                  errorText = 'La contraseña debe tener al menos 6 caracteres.';
                                  _submitting = false;
                                });
                                return;
                              }

                              try {
                                final registered = await UserService().registerUser(
                                  name: '$name $lastName',
                                  email: email,
                                  password: password,
                                  phone: phone,
                                );

                                if (!mounted) {
                                  return;
                                }

                                if (registered) {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) => EmailVerificationPendingScreen(email: email),
                                    ),
                                  );
                                  return;
                                }

                                setState(() {
                                  errorText = 'El correo ya está registrado o hubo un error.';
                                });
                              } catch (e) {
                                if (!mounted) {
                                  return;
                                }
                                setState(() {
                                  errorText = e.toString().replaceFirst('Exception: ', '');
                                });
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _submitting = false;
                                  });
                                }
                              }
                            },
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Registrarse'),
                    ),
                  ),
                ],
              ), // cierre correcto del Column
            ), // cierre correcto del Container
          ),
        ),
      ),
    );
  }
}