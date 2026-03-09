import 'package:flutter/material.dart';
import 'personal_info_screen.dart';
import 'email_edit_screen.dart';
import 'password_edit_screen.dart';
import 'notifications_screen.dart';
import '../services/user_service.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.grey.shade200,
                    radius: 24,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black, size: 28),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Cuenta',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _accountOption(Icons.person_outline, 'Información personal', onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const PersonalInfoScreen()),
              );
            }),
            _accountOption(Icons.add_circle_outline, 'GoBikePro', onTap: () {}),
            _accountOption(Icons.mail_outline, 'Email', onTap: () {
              final currentEmail = UserService().currentUser?.email ?? '';
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => EmailEditScreen(initialEmail: currentEmail)),
              );
            }),
            _accountOption(Icons.lock_outline, 'Contraseña', onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const PasswordEditScreen()),
              );
            }),
            _accountOption(Icons.notifications_none, 'Notificaciones', onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const NotificationsScreen()),
              );
            }),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(left: 24, bottom: 32),
              child: GestureDetector(
                onTap: () {},
                child: Row(
                  children: const [
                    Icon(Icons.delete_outline, color: Colors.pink, size: 28),
                    SizedBox(width: 8),
                    Text('Cerrar mi cuenta', style: TextStyle(color: Colors.pink, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accountOption(IconData icon, String label, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, size: 28, color: Colors.black87),
      title: Text(label, style: const TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.w500)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      horizontalTitleGap: 16,
    );
  }
}
