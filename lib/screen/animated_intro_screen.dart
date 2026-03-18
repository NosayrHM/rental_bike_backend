import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../services/user_service.dart';
import 'admin_dashboard_screen.dart';
import 'main_menu_screen.dart';

class AnimatedIntroScreen extends StatefulWidget {
  final ValueChanged<BuildContext>? onAnimationEnd;
  const AnimatedIntroScreen({this.onAnimationEnd, super.key});

  @override
  State<AnimatedIntroScreen> createState() => _AnimatedIntroScreenState();
}

class _AnimatedIntroScreenState extends State<AnimatedIntroScreen> {
  bool _animationEnded = false;

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

  Future<void> _navigateByRole() async {
    final isAdmin = await UserService().isCurrentUserAdmin();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => isAdmin ? const AdminDashboardScreen() : MainMenuScreen(),
      ),
      (route) => false,
    );
  }

  void _handleAnimationEnd() {
    if (!_animationEnded && mounted) {
      _animationEnded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final callback = widget.onAnimationEnd;
        if (callback != null) {
          callback(context);
          return;
        }
        _navigateByRole();
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
