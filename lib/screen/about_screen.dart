import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.grey.shade100,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
        centerTitle: true,
        title: const Text(
          'Sobre',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _AboutOption(
              icon: Icons.lock_outline,
              text: 'Política de privacidad',
              onTap: () {},
            ),
            const SizedBox(height: 18),
            _AboutOption(
              icon: Icons.description_outlined,
              text: 'Condiciones de servicio',
              onTap: () {},
            ),
            const SizedBox(height: 18),
            _AboutOption(
              icon: Icons.thumb_up_alt_outlined,
              text: 'Agradecimientos',
              onTap: () {},
            ),
            const SizedBox(height: 18),
            _AboutOption(
              icon: Icons.check_circle_outline,
              text: 'Consentimiento',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutOption extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  const _AboutOption({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Icon(icon, size: 32, color: Colors.black87),
          const SizedBox(width: 18),
          Text(
            text,
            style: const TextStyle(
              fontSize: 20,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
