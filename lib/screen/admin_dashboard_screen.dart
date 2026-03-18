import 'package:flutter/material.dart';

import '../services/user_service.dart';
import 'splash_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _validating = true;
  bool _loadingAdmins = false;
  bool _creating = false;
  String? _error;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  List<Map<String, dynamic>> _admins = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _validateAdminAccess();
  }

  Future<void> _validateAdminAccess() async {
    final isAdmin = await UserService().isCurrentUserAdmin();
    if (!mounted) {
      return;
    }

    if (!isAdmin) {
      await UserService().logout();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => SplashScreen()),
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Acceso restringido: panel solo para administrador.'),
        ),
      );
      return;
    }

    setState(() {
      _validating = false;
    });

    // Cargar admins después de validar.
    await _loadAdmins();
  }

  Future<void> _loadAdmins() async {
    setState(() {
      _loadingAdmins = true;
      _error = null;
    });
    try {
      final list = await UserService().fetchAdmins();
      if (!mounted) return;
      setState(() {
        _admins = list;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingAdmins = false;
        });
      }
    }
  }

  Future<void> _createAdmin() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    if (name.isEmpty || email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa nombre y un email válido.')),
      );
      return;
    }

    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      await UserService().createAdmin(email: email, name: name);
      _nameCtrl.clear();
      _emailCtrl.clear();
      await _loadAdmins();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Administrador creado.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _creating = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await UserService().logout();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => SplashScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_validating) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
        ),
      );
    }

    final adminEmail =
        UserService().currentUser?.email ?? UserService().adminEmail;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        foregroundColor: Colors.white,
        title: const Text('RentalBike Control'),
        actions: [
          IconButton(
            onPressed: _logout,
            tooltip: 'Cerrar sesion',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1F2937), Color(0xFF111827)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF374151)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Panel Administrador',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sesion autorizada: $adminEmail',
                    style: const TextStyle(color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildAdminManager(),
            const SizedBox(height: 16),
            const _AdminCard(
              title: 'Estado del sistema',
              value: 'Operativo',
              accent: Color(0xFF10B981),
              icon: Icons.shield,
            ),
            const SizedBox(height: 12),
            const _AdminCard(
              title: 'Modulo clientes',
              value: 'Aislado del panel admin',
              accent: Color(0xFFF59E0B),
              icon: Icons.people_alt,
            ),
            const SizedBox(height: 12),
            const _AdminCard(
              title: 'Acceso',
              value: 'Solo email autorizado',
              accent: Color(0xFF60A5FA),
              icon: Icons.lock,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: const Color(0xFF111827),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar sesion de administrador'),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _sectionTitle(String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({
    required this.title,
    required this.value,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String value;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: accent.withOpacity(0.2),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension on _AdminDashboardScreenState {
  Widget _buildAdminManager() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Gestión de administradores'),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Nombre',
              labelStyle: TextStyle(color: Color(0xFF9CA3AF)),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF374151)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF60A5FA)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _emailCtrl,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              labelStyle: TextStyle(color: Color(0xFF9CA3AF)),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF374151)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF60A5FA)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF60A5FA),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: _creating ? null : _createAdmin,
                icon: const Icon(Icons.add),
                label: Text(_creating ? 'Creando...' : 'Registrar Administrador'),
              ),
              const SizedBox(width: 12),
              if (_loadingAdmins) const CircularProgressIndicator(strokeWidth: 2.2),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ],
          const SizedBox(height: 16),
          _sectionTitle('Administradores actuales'),
          const SizedBox(height: 8),
          if (_admins.isEmpty && !_loadingAdmins)
            const Text(
              'No hay administradores registrados.',
              style: TextStyle(color: Color(0xFF9CA3AF)),
            )
          else
            ..._admins.map((adm) {
              final email = adm['email'] as String? ?? '';
              final role = adm['role'] as String? ?? 'admin';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1220),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1F2937)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user, color: Color(0xFF60A5FA)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            email,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            role,
                            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
