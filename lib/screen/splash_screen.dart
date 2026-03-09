import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_screen.dart';
import 'register_screen.dart';
import '../utils/deep_link_handler.dart';

final GoogleSignIn _googleSignIn = GoogleSignIn();

// Configura estos valores con los de tu app de Instagram
const String instagramClientId = 'TU_CLIENT_ID';
const String instagramRedirectUri = 'TU_REDIRECT_URI'; // Debe coincidir con el registrado en Instagram
const String instagramClientSecret = 'TU_CLIENT_SECRET';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  final DeepLinkHandler _deepLinkHandler = DeepLinkHandler();
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late AnimationController _buttonsController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeButtonsAnim;
  late AnimationController? _bikeController;
  late Animation<Offset>? _bikeSlideAnim;

  @override
  void initState() {
    super.initState();
    // Inicializar deep links multiplataforma
    _deepLinkHandler.init(context);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();

    _bikeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: false);
    _bikeSlideAnim = Tween<Offset>(
      begin: const Offset(-2.2, 0), // más a la izquierda
      end: const Offset(2.2, 0),   // más a la derecha
    ).animate(CurvedAnimation(
      parent: _bikeController!,
      curve: Curves.linear,
    ));

    _buttonsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3), // antes 5
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _buttonsController,
      curve: Curves.easeOutBack,
    ));
    _fadeButtonsAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _buttonsController, curve: Curves.easeIn),
    );

    // Iniciar animación de botones después de que la pantalla se haya renderizado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _buttonsController.forward();
      });
    });
  }

  @override
  void dispose() {
      _deepLinkHandler.dispose();
    _controller.dispose();
    _buttonsController.dispose();
    _bikeController?.dispose();
    super.dispose();
  }

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account != null) {
        // Éxito: puedes acceder a account.displayName, account.email, etc.
        print('Usuario: \\${account.displayName}, Email: \\${account.email}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bienvenido, \\${account.displayName ?? account.email}')),
        );
      } else {
        // El usuario canceló el login
        print('Login cancelado');
      }
    } catch (error) {
      print('Error en Google Sign-In: \\${error.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error en Google Sign-In: \\${error.toString()}')),
      );
    }
  }

  Future<void> signInWithInstagram(BuildContext context) async {
    final authUrl =
        'https://api.instagram.com/oauth/authorize?client_id=$instagramClientId&redirect_uri=$instagramRedirectUri&scope=user_profile&response_type=code';

    try {
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl,
        callbackUrlScheme: instagramRedirectUri.split('://').first,
      );

      final code = Uri.parse(result).queryParameters['code'];
      if (code != null) {
        // Intercambiar el código por un token de acceso
        final response = await http.post(
          Uri.parse('https://api.instagram.com/oauth/access_token'),
          body: {
            'client_id': instagramClientId,
            'client_secret': instagramClientSecret,
            'grant_type': 'authorization_code',
            'redirect_uri': instagramRedirectUri,
            'code': code,
          },
        );
        final data = json.decode(response.body);
        final String? accessToken = data['access_token'] as String?;
        if (accessToken == null || accessToken.isEmpty) {
          throw Exception('No se recibió token de acceso');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login Instagram exitoso')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error en login Instagram: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 53, 59, 74), // Gris solicitado
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            height: MediaQuery.of(context).size.height -
                MediaQuery.of(context).padding.top -
                MediaQuery.of(context).padding.bottom,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                const SizedBox(height: 10),
                SlideTransition(
                  position: _bikeSlideAnim!,
                  child: Image.asset(
                    'assets/images/bike.gif',
                    width: 180,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                const SizedBox(height: 0),
                FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: Transform(
                      alignment: Alignment.center,
                      // Perspectiva y leve inclinación para efecto 3D
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0012)
                        ..rotateX(-0.18)
                        ..rotateY(-0.10),
                      child: Stack(
                        children: [
                          // Capa de "relieve" oscura
                          Text(
                            'RENTALBIKE',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              letterSpacing: 2,
                              color: Colors.black.withOpacity(0.35),
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.5),
                                  offset: Offset(0, 7),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          // Capa de "relieve" clara
                          Positioned(
                            left: 2,
                            top: 2,
                            child: Text(
                              'RENTALBIKE',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                letterSpacing: 2,
                                color: Colors.white.withOpacity(0.7),
                                shadows: [
                                  Shadow(
                                    color: Colors.white.withOpacity(0.5),
                                    offset: Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Capa principal con borde negro y sombra
                          Text(
                            'RENTALBIKE',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              letterSpacing: 2,
                              foreground: Paint()
                                ..style = PaintingStyle.stroke
                                ..strokeWidth = 3
                                ..color = Colors.black,
                            ),
                          ),
                          const Text(
                            'RENTALBIKE',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              letterSpacing: 2,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  offset: Offset(0, 3),
                                  blurRadius: 6,
                                ),
                                Shadow(
                                  color: Colors.black26,
                                  offset: Offset(0, 8),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SlideTransition(
                  position: _slideAnim,
                  child: FadeTransition(
                    opacity: _fadeButtonsAnim,
                    child: Column(
                      children: [
                        // Botón Email
                        SizedBox(
                          width: 280,
                          height: 48,
                          child: GestureDetector(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                ),
                                builder: (context) => Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.black,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            side: BorderSide(color: Colors.black, width: 2),
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(builder: (_) => LoginScreen()),
                                          );
                                        },
                                        child: const Text('Iniciar sesión'),
                                      ),
                                      const SizedBox(height: 12),
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.black,
                                          side: BorderSide(color: Colors.black, width: 2),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(builder: (_) => RegisterScreen()),
                                          );
                                        },
                                        child: const Text('Registrarse'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.35),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                                border: Border.all(color: Colors.black, width: 2),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'Continuar con email',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Botón Google
                        SizedBox(
                          width: 280,
                          height: 48,
                          child: AnimatedScaleRotateButton(
                            onTap: signInWithGoogle,
                            logo: Image.asset(
                              'assets/images/google_logo.png',
                              height: 32,
                              width: 32,
                            ),
                            text: 'Continuar con Google',
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black87,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.30),
                                  blurRadius: 14,
                                  spreadRadius: 2,
                                  offset: Offset(0, 7),
                                ),
                              ],
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Botón Instagram
                        SizedBox(
                          width: 280,
                          height: 48,
                          child: AnimatedScaleRotateButton(
                            onTap: () => signInWithInstagram(context),
                            logo: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Image.asset(
                                'assets/images/instagram_logo.png',
                                height: 40,
                                width: 40,
                              ),
                            ),
                            text: 'Continuar con Instagram',
                            textStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFF58529),
                                  Color(0xFFDD2A7B),
                                  Color(0xFF8134AF),
                                  Color(0xFF515BD4),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.40),
                                  blurRadius: 18,
                                  spreadRadius: 3,
                                  offset: Offset(0, 9),
                                ),
                              ],
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedScaleRotateButton extends StatefulWidget {
  final Widget logo;
  final String text;
  final TextStyle? textStyle;
  final VoidCallback onTap;
  final double scale;
  final Duration duration;
  final BoxDecoration decoration;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double spacing;
  final double height;
  const AnimatedScaleRotateButton({
    super.key,
    required this.logo,
    required this.text,
    required this.onTap,
    required this.decoration,
    this.textStyle,
    this.scale = 0.95,
    this.duration = const Duration(milliseconds: 90),
    this.padding,
    this.borderRadius = 16,
    this.spacing = 8,
    this.height = 48,
  });

  @override
  State<AnimatedScaleRotateButton> createState() => _AnimatedScaleRotateButtonState();
}

class _AnimatedScaleRotateButtonState extends State<AnimatedScaleRotateButton>
    with SingleTickerProviderStateMixin {
  double _currentScale = 1.0;
  late AnimationController _rotationController;
  late Animation<double> _rotationAnim;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _rotationAnim = Tween<double>(begin: 0, end: 0.5).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _onTapDown(_) {
    setState(() => _currentScale = widget.scale);
    _rotationController.forward(from: 0);
  }

  void _onTapUp(_) {
    setState(() => _currentScale = 1.0);
    _rotationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: () {
        setState(() => _currentScale = 1.0);
        _rotationController.reverse();
      },
      child: AnimatedScale(
        scale: _currentScale,
        duration: widget.duration,
        curve: Curves.easeOut,
        child: Container(
          height: widget.height,
          decoration: widget.decoration,
          padding: widget.padding,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _rotationAnim,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationAnim.value * 3.1416, // 0.5 vueltas (180°)
                    child: child,
                  );
                },
                child: widget.logo,
              ),
              SizedBox(width: widget.spacing),
              Text(
                widget.text,
                style: widget.textStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
