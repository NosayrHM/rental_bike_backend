import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'main_menu_screen.dart';

class AnimatedIntroScreen extends StatefulWidget {
  final VoidCallback onAnimationEnd;
  const AnimatedIntroScreen({required this.onAnimationEnd, super.key});

  @override
  State<AnimatedIntroScreen> createState() => _AnimatedIntroScreenState();
}

class _AnimatedIntroScreenState extends State<AnimatedIntroScreen> {
    @override
    void initState() {
      super.initState();
      // Fallback: si la animación no navega, forzar navegación tras 5 segundos
      Future.delayed(const Duration(seconds: 5), () {
        if (!_animationEnded && mounted) {
          _handleAnimationEnd();
        }
      });
    }
  bool _animationEnded = false;

  void _handleAnimationEnd() {
    if (!_animationEnded && mounted) {
      _animationEnded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => MainMenuScreen()),
          (route) => false,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Lottie.asset(
          'assets/animation.json',
          repeat: false,
          onLoaded: (composition) {
            // Llama a la navegación justo al terminar la animación, sin retardo extra
            Future.delayed(composition.duration, _handleAnimationEnd);
          },
        ),
      ),
    );
  }
}
