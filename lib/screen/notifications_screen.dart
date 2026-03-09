import 'package:flutter/material.dart';

import '../services/payment_method_service.dart';
import 'payment_methods_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  bool _hasPaymentMethod = true;

  @override
  void initState() {
    super.initState();
    _loadPaymentStatus();
  }

  Future<void> _loadPaymentStatus() async {
    final hasPayment = await PaymentMethodService.instance.hasPaymentMethod();
    if (!mounted) {
      return;
    }
    setState(() {
      _hasPaymentMethod = hasPayment;
      _loading = false;
    });
  }

  Future<void> _openPaymentMethods() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const PaymentMethodsScreen()),
    );
    // Si se eliminó la última tarjeta, refrescar notificaciones
    await _loadPaymentStatus();
    if (result == true) {
      setState(() {}); // Forzar rebuild si hubo cambio relevante
    }
  }

  List<_NotificationEntry> get _notifications {
    final entries = <_NotificationEntry>[];
    if (!_hasPaymentMethod) {
      entries.add(
        _NotificationEntry(
          icon: Icons.credit_card_outlined,
          title: 'Añade un método de pago',
          description:
              'Para completar tus reservas necesitas registrar al menos una tarjeta. Esta alerta permanecerá hasta que agregues un método de pago.',
          timestamp: 'Pendiente',
          actionLabel: 'Configurar método de pago',
          onActionTap: _openPaymentMethods,
        ),
      );
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F1FF),
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: const Color(0xFFF6F1FF),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final notifications = _notifications;
    if (notifications.isEmpty) {
      return const _EmptyNotifications();
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        return _NotificationCard(entry: notifications[index]);
      },
    );
  }
}

class _NotificationEntry {
  const _NotificationEntry({
    required this.icon,
    required this.title,
    required this.description,
    required this.timestamp,
    this.actionLabel,
    this.onActionTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final String timestamp;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  bool get hasAction => actionLabel != null && onActionTap != null;
}

class _NotificationCard extends StatelessWidget {
  // ignore: unused_element_parameter
  const _NotificationCard({required this.entry, super.key});

  final _NotificationEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1C6FFF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(entry.icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF353B4A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  entry.description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  entry.timestamp,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                if (entry.hasAction) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: entry.onActionTap,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFF1C6FFF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(entry.actionLabel!),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.notifications_none, size: 64, color: Colors.black26),
            SizedBox(height: 16),
            Text(
              'No tienes notificaciones pendientes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Cuando haya información importante aparecerá en este espacio.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
