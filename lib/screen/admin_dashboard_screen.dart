import 'package:flutter/material.dart';

import '../services/user_service.dart';
import 'area_laboral_screen.dart';
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
  bool _deleting = false;
  String? _error;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();
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
    final password = _passwordCtrl.text;
    final confirmPassword = _confirmPasswordCtrl.text;
    if (name.isEmpty || email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa nombre y un email válido.')),
      );
      return;
    }
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La contraseña debe tener al menos 6 caracteres.')),
      );
      return;
    }
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas no coinciden.')),
      );
      return;
    }

    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      await UserService().createAdmin(email: email, name: name, password: password);
      _nameCtrl.clear();
      _emailCtrl.clear();
      _passwordCtrl.clear();
      _confirmPasswordCtrl.clear();
      await _loadAdmins();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Administrador creado con acceso listo para iniciar sesión.')),
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

  Future<void> _deleteAdmin(Map<String, dynamic> adminData) async {
    final role = adminData['role'] as String? ?? 'admin';
    final email = adminData['email'] as String? ?? '';
    if (role != 'admin' || email.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Eliminar administrador'),
          content: Text('Se eliminará $email y su acceso al sistema. Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _deleting = true;
      _error = null;
    });

    try {
      await UserService().deleteAdmin(email);
      await _loadAdmins();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Administrador eliminado.')),
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
          _deleting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
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

  Future<void> _openAdminManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AdminManagementScreen(
          admins: _admins,
          nameCtrl: _nameCtrl,
          emailCtrl: _emailCtrl,
          passwordCtrl: _passwordCtrl,
          confirmPasswordCtrl: _confirmPasswordCtrl,
          onCreate: _createAdmin,
          onDelete: _deleteAdmin,
        ),
      ),
    );

    if (!mounted) {
      return;
    }
    await _loadAdmins();
  }

  Future<void> _openWorkArea() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AreaLaboralScreen()),
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
            _AdminAccessCard(
              title: 'Acceso',
              value: 'Solo email autorizado',
              accent: Color(0xFF60A5FA),
              icon: Icons.lock,
              onManageAdmins: _openAdminManagement,
            ),
            const SizedBox(height: 12),
            _AdminActionCard(
              title: 'Area laboral',
              value: 'Gestión interna',
              accent: Color(0xFF38BDF8),
              icon: Icons.work_outline,
              buttonLabel: 'Gestionar area laboral',
              onPressed: _openWorkArea,
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

class _AdminAccessCard extends StatelessWidget {
  const _AdminAccessCard({
    required this.title,
    required this.value,
    required this.accent,
    required this.icon,
    required this.onManageAdmins,
  });

  final String title;
  final String value;
  final Color accent;
  final IconData icon;
  final VoidCallback onManageAdmins;

  @override
  Widget build(BuildContext context) {
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
          Row(
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
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onManageAdmins,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF60A5FA)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('Gestionar administradores'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminActionCard extends StatelessWidget {
  const _AdminActionCard({
    required this.title,
    required this.value,
    required this.accent,
    required this.icon,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String value;
  final Color accent;
  final IconData icon;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
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
          Row(
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
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: accent),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.open_in_new),
              label: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminManagementScreen extends StatefulWidget {
  const _AdminManagementScreen({
    required this.admins,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.confirmPasswordCtrl,
    required this.onCreate,
    required this.onDelete,
  });

  final List<Map<String, dynamic>> admins;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final TextEditingController confirmPasswordCtrl;
  final Future<void> Function() onCreate;
  final Future<void> Function(Map<String, dynamic> adminData) onDelete;

  @override
  State<_AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<_AdminManagementScreen> {
  late List<Map<String, dynamic>> _admins;
  bool _loadingAdmins = false;
  bool _creating = false;
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _admins = List<Map<String, dynamic>>.from(widget.admins);
  }

  Future<void> _refreshAdmins() async {
    setState(() {
      _loadingAdmins = true;
      _error = null;
    });

    try {
      final admins = await UserService().fetchAdmins();
      if (!mounted) return;
      setState(() {
        _admins = admins;
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

  Future<void> _handleCreate() async {
    setState(() {
      _creating = true;
      _error = null;
    });

    try {
      await widget.onCreate();
      if (!mounted) return;
      await _refreshAdmins();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _creating = false;
        });
      }
    }
  }

  Future<void> _handleDelete(Map<String, dynamic> adminData) async {
    setState(() {
      _deleting = true;
      _error = null;
    });

    try {
      await widget.onDelete(adminData);
      if (!mounted) return;
      await _refreshAdmins();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _deleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        foregroundColor: Colors.white,
        title: const Text('Gestión de administradores'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1F2937)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Registrar administrador'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: widget.nameCtrl,
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
                    controller: widget.emailCtrl,
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
                  const SizedBox(height: 8),
                  TextField(
                    controller: widget.passwordCtrl,
                    style: const TextStyle(color: Colors.white),
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña inicial',
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
                    controller: widget.confirmPasswordCtrl,
                    style: const TextStyle(color: Colors.white),
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar contraseña',
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
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF60A5FA),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          onPressed: _creating ? null : _handleCreate,
                          icon: const Icon(Icons.add),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _creating ? 'Creando...' : 'Registrar administrador',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_loadingAdmins)
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1F2937)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(child: SizedBox()),
                      IconButton(
                        onPressed: _loadingAdmins ? null : _refreshAdmins,
                        tooltip: 'Recargar',
                        icon: const Icon(Icons.refresh, color: Colors.white),
                      ),
                    ],
                  ),
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
                      final hasLoginAccess = adm['hasLoginAccess'] == true;
                      final canDelete = role == 'admin' && !_deleting;
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
                                  Text(
                                    hasLoginAccess ? 'Acceso listo' : 'Sin acceso todavía',
                                    style: TextStyle(
                                      color: hasLoginAccess ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: canDelete ? () => _handleDelete(adm) : null,
                              tooltip: role == 'admin'
                                  ? 'Eliminar administrador'
                                  : 'No se puede eliminar super_admin',
                              icon: Icon(
                                Icons.delete_outline,
                                color: role == 'admin'
                                    ? const Color(0xFFF87171)
                                    : const Color(0xFF4B5563),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
