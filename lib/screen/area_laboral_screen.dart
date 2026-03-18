import 'package:flutter/material.dart';

import '../services/user_service.dart';

class AreaLaboralScreen extends StatefulWidget {
  const AreaLaboralScreen({super.key});

  @override
  State<AreaLaboralScreen> createState() => _AreaLaboralScreenState();
}

class _AreaLaboralScreenState extends State<AreaLaboralScreen> {
  bool _loadingEmployees = false;
  bool _loadingStores = false;
  bool _creating = false;
  bool _deleting = false;
  String? _error;
  String _currentSection = 'employees';
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();
  List<Map<String, dynamic>> _employees = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _stores = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _loadStores();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _loadingEmployees = true;
      _error = null;
    });
    try {
      final list = await UserService().fetchEmployeeUsers();
      if (!mounted) return;
      setState(() {
        _employees = list;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingEmployees = false;
        });
      }
    }
  }

  Future<void> _loadStores() async {
    setState(() {
      _loadingStores = true;
      _error = null;
    });
    try {
      final list = await UserService().fetchStoreUsers();
      if (!mounted) return;
      setState(() {
        _stores = list;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingStores = false;
        });
      }
    }
  }

  Future<void> _createUser() async {
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
      if (_currentSection == 'employees') {
        await UserService().createEmployeeUser(
          email: email,
          name: name,
          password: password,
        );
        _nameCtrl.clear();
        _emailCtrl.clear();
        _passwordCtrl.clear();
        _confirmPasswordCtrl.clear();
        await _loadEmployees();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Empleado creado con éxito.')),
        );
      } else {
        await UserService().createStoreUser(
          email: email,
          name: name,
          password: password,
        );
        _nameCtrl.clear();
        _emailCtrl.clear();
        _passwordCtrl.clear();
        _confirmPasswordCtrl.clear();
        await _loadStores();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario de tienda creado con éxito.')),
        );
      }
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

  Future<void> _deleteUser(Map<String, dynamic> userData) async {
    final email = userData['email'] as String? ?? '';
    if (email.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final label =
            _currentSection == 'employees' ? 'empleado' : 'usuario de tienda';
        return AlertDialog(
          title: Text('Eliminar $label'),
          content: Text(
            'Se eliminará $email y su acceso al sistema. Esta acción no se puede deshacer.',
          ),
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
      if (_currentSection == 'employees') {
        await UserService().deleteEmployeeUser(email);
        await _loadEmployees();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Empleado eliminado.')),
        );
      } else {
        await UserService().deleteStoreUser(email);
        await _loadStores();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario de tienda eliminado.')),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        foregroundColor: Colors.white,
        title: const Text('Área Laboral'),
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
                  const Text(
                    'Gestión de personal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _SectionButton(
                          label: 'Empleados',
                          isActive: _currentSection == 'employees',
                          onPressed: () {
                            setState(() {
                              _currentSection = 'employees';
                              _error = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SectionButton(
                          label: 'Tiendas',
                          isActive: _currentSection == 'stores',
                          onPressed: () {
                            setState(() {
                              _currentSection = 'stores';
                              _error = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
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
                  Text(
                    _currentSection == 'employees'
                        ? 'Registrar empleado'
                        : 'Registrar usuario de tienda',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DarkField(
                    controller: _nameCtrl,
                    label: 'Nombre',
                  ),
                  const SizedBox(height: 8),
                  _DarkField(
                    controller: _emailCtrl,
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 8),
                  _DarkField(
                    controller: _passwordCtrl,
                    label: 'Contraseña',
                    obscureText: true,
                  ),
                  const SizedBox(height: 8),
                  _DarkField(
                    controller: _confirmPasswordCtrl,
                    label: 'Confirmar contraseña',
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38BDF8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _creating ? null : _createUser,
                      icon: const Icon(Icons.add),
                      label: Text(_creating ? 'Creando...' : 'Crear'),
                    ),
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
                      Expanded(
                        child: Text(
                          _currentSection == 'employees'
                              ? 'Empleados registrados'
                              : 'Usuarios de tienda registrados',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: (_loadingEmployees || _loadingStores)
                            ? null
                            : () {
                                if (_currentSection == 'employees') {
                                  _loadEmployees();
                                } else {
                                  _loadStores();
                                }
                              },
                        tooltip: 'Recargar',
                        icon: const Icon(Icons.refresh, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_currentSection == 'employees' && _loadingEmployees)
                    const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF38BDF8),
                      ),
                    )
                  else if (_currentSection == 'stores' && _loadingStores)
                    const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF38BDF8),
                      ),
                    )
                  else if (_currentSection == 'employees'
                      ? _employees.isEmpty
                      : _stores.isEmpty)
                    Text(
                      _currentSection == 'employees'
                          ? 'No hay empleados registrados.'
                          : 'No hay usuarios de tienda registrados.',
                      style: const TextStyle(color: Color(0xFF9CA3AF)),
                    )
                  else
                    ...((_currentSection == 'employees' ? _employees : _stores)
                        .map((user) {
                      final email = user['email'] as String? ?? '';
                      final name = user['name'] as String? ?? '';
                      final hasLoginAccess = user['hasLoginAccess'] == true;
                      final canDelete = !_deleting;

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
                            Icon(
                              _currentSection == 'employees'
                                  ? Icons.person_outline
                                  : Icons.store_outlined,
                              color: const Color(0xFF38BDF8),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    email,
                                    style: const TextStyle(
                                      color: Color(0xFF9CA3AF),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: hasLoginAccess
                                          ? const Color(0xFF10B981).withOpacity(0.2)
                                          : const Color(0xFFF59E0B).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      hasLoginAccess
                                          ? 'Acceso listo'
                                          : 'Sin acceso todavía',
                                      style: TextStyle(
                                        color: hasLoginAccess
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFF59E0B),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: canDelete ? () => _deleteUser(user) : null,
                              tooltip: 'Eliminar',
                              icon: Icon(
                                Icons.delete_outline,
                                color: canDelete
                                    ? const Color(0xFFF87171)
                                    : const Color(0xFF4B5563),
                              ),
                            ),
                          ],
                        ),
                      );
                    })),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionButton extends StatelessWidget {
  const _SectionButton({
    required this.label,
    required this.isActive,
    required this.onPressed,
  });

  final String label;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isActive ? const Color(0xFF38BDF8) : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: isActive
              ? const Color(0xFF38BDF8)
              : const Color(0xFF9CA3AF),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _DarkField extends StatelessWidget {
  const _DarkField({
    required this.controller,
    required this.label,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType keyboardType;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF374151)),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF38BDF8)),
        ),
      ),
    );
  }
}
