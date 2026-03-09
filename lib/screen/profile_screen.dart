import 'package:flutter/material.dart';
import 'main_menu_screen.dart';
import 'account_screen.dart';
import 'payment_methods_screen.dart';
import '../services/user_service.dart';
import '../models/user.dart';
import 'splash_screen.dart';
import 'about_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _user;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await UserService().getToken();
      if (token == null) {
        setState(() {
          _error = 'No autenticado.';
          _loading = false;
        });
        return;
      }
      final user = await UserService().getProfile(token);
      setState(() {
        _user = user;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar perfil';
        _loading = false;
      });
    }
  }

  void _showHelpSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.only(top: 16, left: 0, right: 0, bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: CircleAvatar(
                    backgroundColor: Colors.grey.shade100,
                    child: const Icon(Icons.close, color: Colors.black87),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Ayuda',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _HelpOption(
                    text: 'Escribe a nuestro asistente virtual',
                    onTap: () {},
                  ),
                  const SizedBox(height: 12),
                  _HelpOption(text: 'Centro de ayuda', onTap: () {}),
                  const SizedBox(height: 12),
                  _HelpOption(
                    text: 'Ponte en contacto con nosotros',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    setState(() {}); // Fuerza reconstrucción al volver
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user ?? UserService().currentUser;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 53, 59, 74),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red, fontSize: 18),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Botón cerrar (arriba izquierda)
                          Padding(
                            padding: const EdgeInsets.only(left: 16, top: 8),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: CircleAvatar(
                                backgroundColor: const Color.fromARGB(
                                  255,
                                  255,
                                  255,
                                  255,
                                ),
                                radius: 24,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.black87,
                                    size: 28,
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(
                                        builder: (context) => MainMenuScreen(),
                                      ),
                                      (route) => false,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Avatar y nombre
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: const Color.fromARGB(
                              255,
                              255,
                              255,
                              255,
                            ),
                            child: Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.grey[400],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            user?.name ?? 'Usuario',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Tarjeta validación
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3C4),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    '¡Haz un chequeo rápido!',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Necesitamos saber quien eres, pincha aquí para verificar tu validacion antes de alquilar una bicicleta.',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          // Opciones principales
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 0,
                              margin: EdgeInsets.zero,
                              child: Column(
                                children: [
                                  ListTile(
                                    leading: const Icon(
                                      Icons.person_outline,
                                      size: 28,
                                    ),
                                    title: const Text(
                                      'Cuenta',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const AccountScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  const Divider(height: 1),
                                  ListTile(
                                    leading: const Icon(
                                      Icons.credit_card,
                                      size: 28,
                                    ),
                                    title: const Text(
                                      'Métodos de pago',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (context) =>
                                              PaymentMethodsScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  const Divider(height: 1),
                                  ListTile(
                                    leading: const Icon(
                                      Icons.card_giftcard_outlined,
                                      size: 28,
                                    ),
                                    title: const Text(
                                      'Consigue tu descuento',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: const Text(
                                      'Recomienda a un amigo GoBike',
                                    ),
                                    onTap: () {},
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Ayuda, Sobre, Renting
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  onTap: () => _showHelpSheet(context),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.help_outline,
                                        size: 28,
                                        color: Colors.black87,
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Ayuda',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => AboutScreen(),
                                      ),
                                    );
                                  },
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.description_outlined,
                                        size: 28,
                                        color: Colors.black87,
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Sobre',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    Icon(
                                      Icons.directions_bike_outlined,
                                      size: 28,
                                      color: Colors.black87,
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Renting',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Versión
                          const Text(
                            'Versión: 1.0.0',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: SizedBox(
                      width: 180,
                      child: TextButton(
                        onPressed: () async {
                          // Cerrar sesión correctamente
                          await UserService().logout();
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => SplashScreen()),
                            (route) => false,
                          );
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 0, 0, 0),
                          foregroundColor: const Color.fromARGB(
                            255,
                            255,
                            255,
                            255,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Cerrar sesión',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _HelpOption extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _HelpOption({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 0, 0, 0), // Azul claro
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color.fromARGB(
              255,
              255,
              255,
              255,
            ), // Azul oscuro para el texto
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
      ),
    );
  }
}
