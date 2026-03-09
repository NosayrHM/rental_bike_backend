import 'package:flutter/material.dart';
import 'screen/splash_screen.dart';
import 'services/user_service.dart';
import 'screen/main_menu_screen.dart';
import 'screen/animated_intro_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GoBike',
      home: SplashScreenWrapper(),
    );
  }
}

class SplashScreenWrapper extends StatefulWidget {
  const SplashScreenWrapper({super.key});

  @override
  _SplashScreenWrapperState createState() => _SplashScreenWrapperState();
}

class _SplashScreenWrapperState extends State<SplashScreenWrapper> {
  bool _loading = true;
  bool _loggedIn = false;
  bool _showAnimation = false;

  @override
  void initState() {
    super.initState();
    _checkLoginAndRestoreUser();
  }

  void _checkLoginAndRestoreUser() async {
    final loggedIn = await UserService().restoreSession();
    setState(() {
      _loading = false;
      _loggedIn = loggedIn;
      _showAnimation = loggedIn;
    });
  }

  void _onAnimationEnd() {
    setState(() {
      _showAnimation = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SplashScreen();
    }
    if (_loggedIn) {
      if (_showAnimation) {
        return AnimatedIntroScreen(onAnimationEnd: _onAnimationEnd);
      } else {
        return MainMenuScreen();
      }
    } else {
      return SplashScreen();
    }
  }
}
