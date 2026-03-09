import 'package:flutter/material.dart';
import '../services/user_service.dart';

class ProfilePreviewScreen extends StatelessWidget {
  const ProfilePreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = UserService().currentUser;
    final name = user?.name ?? 'Usuario';
    final joinDate = DateTime.now();
    final monthNames = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    final joinDateText = 'Miembro desde ${monthNames[joinDate.month - 1]}, ${joinDate.year}';
    final valoraciones = <String>[]; // Aquí puedes cargar valoraciones reales

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: Image.asset(
                    'assets/images/profile_bg_decor.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Color(0xFFF5F5F5),
                    ),
                  ),
                ),
                Positioned(
                  top: 24,
                  left: 16,
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                Positioned(
                  left: 32,
                  top: 130,
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.grey.shade200,
                    child: Icon(Icons.person, size: 60, color: Colors.grey[400]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                name,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.only(left: 32),
              child: Text(
                'Nuevo en GoBike',
                style: TextStyle(fontSize: 17, color: Colors.black54),
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Row(
                children: [
                  const Icon(Icons.sentiment_satisfied_alt, size: 22, color: Colors.black54),
                  const SizedBox(width: 8),
                  Text(
                    joinDateText,
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: valoraciones.isEmpty
                  ? const Text(
                      'Aún no hay valoraciones',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Valoraciones:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        ...valoraciones.map((v) => Text(v)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}