import 'package:flutter/material.dart';
import 'v8_ouxi_screen.dart';
import 'v20_screen.dart';
import 'v8_pro_screen.dart';
import 'notifications_screen.dart';
import 'payment_methods_screen.dart';
import 'profile_screen.dart';

import '../services/payment_method_service.dart';
import '../services/rental_subscription_service.dart';
import '../services/stripe_service.dart' as stripe;

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({
    super.key,
    this.initialIndex = 0,
    this.showRentalSuccessDialog = false,
  });

  final int initialIndex;
  final bool showRentalSuccessDialog;

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  static const _backgroundColor = Color(0xFFF6F1FF);
  int _selectedIndex = 0;
  late final AnimationController _bounceController;
  Animation<double>? _bounceAnimation;
  bool _showSwipeHint = true;
  double _hintOpacity = 1.0;
  bool _hasPendingNotifications = false;
  bool _loadingRentals = false;
  List<RentalSubscriptionRecord> _rentals = const <RentalSubscriptionRecord>[];
  final Set<String> _cancelingSubscriptions = <String>{};

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, 1);
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: -12.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: -12.0,
          end: 6.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 6.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_bounceController);

    _bounceController.forward();

    _refreshNotificationBadge();
    _loadRentals();

    if (widget.showRentalSuccessDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _showRentalSuccessDialog();
      });
    }

    Future.delayed(const Duration(milliseconds: 3200), () {
      if (!mounted || !_showSwipeHint) {
        return;
      }
      setState(() => _hintOpacity = 0);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) {
          return;
        }
        setState(() => _showSwipeHint = false);
      });
    });
  }

  Future<void> _showRentalSuccessDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF1C6FFF), width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F1FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Color(0xFF1C6FFF),
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '¡Pago confirmado!',
                          style: TextStyle(
                            color: Color(0xFF353B4A),
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'El alquiler de tu bicicleta se ha realizado con éxito.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            if (!mounted) {
                              return;
                            }
                            setState(() {
                              _selectedIndex = 1;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF353B4A),
                            side: const BorderSide(color: Color(0xFF353B4A)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: const Text('Ir a alquileres'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            if (!mounted) {
                              return;
                            }
                            setState(() {
                              _selectedIndex = 0;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1C6FFF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: const Text('Seguir alquilando'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _refreshNotificationBadge() async {
    final hasPayment = await PaymentMethodService.instance.hasPaymentMethod();
    if (!mounted) {
      return;
    }
    setState(() {
      _hasPendingNotifications = !hasPayment;
    });
  }

  Future<void> _loadRentals() async {
    setState(() {
      _loadingRentals = true;
    });


    final localRecords = await RentalSubscriptionService.instance.getAll();
    final updated = <RentalSubscriptionRecord>[];

    for (final record in localRecords) {
      try {
        final details = await stripe.StripeService.instance.fetchSubscriptionDetails(
          subscriptionId: record.subscriptionId,
        );
        updated.add(
          record.copyWith(
            status: details.status,
            nextRenewalAtMillis: details.currentPeriodEndMillis,
            cancelAtPeriodEnd: details.cancelAtPeriodEnd,
          ),
        );
      } catch (_) {
        updated.add(record);
      }
    }

    await RentalSubscriptionService.instance.saveAll(updated);

    if (!mounted) {
      return;
    }
    setState(() {
      _rentals = updated;
      _loadingRentals = false;
    });
  }

  Future<void> _cancelRental(RentalSubscriptionRecord record) async {
    setState(() {
      _cancelingSubscriptions.add(record.subscriptionId);
    });

    try {
      await stripe.StripeService.instance.cancelSubscription(
        subscriptionId: record.subscriptionId,
      );

      await RentalSubscriptionService.instance.upsert(
        record.copyWith(cancelAtPeriodEnd: true),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Suscripción marcada para cancelación al final del periodo.'),
          ),
        );
      }
      await _loadRentals();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cancelar: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _cancelingSubscriptions.remove(record.subscriptionId);
        });
      }
    }
  }

  String _formatDate(int millis) {
    if (millis <= 0) {
      return 'No disponible';
    }
    final date = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _remainingTimeLabel(int millis) {
    if (millis <= 0) {
      return 'No disponible';
    }
    final now = DateTime.now();
    final renewal = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
    final diff = renewal.difference(now);
    if (diff.isNegative) {
      return 'Renovación pendiente';
    }
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    return '${days}d ${hours}h';
  }

  bool _canCancel(RentalSubscriptionRecord record) {
    if (record.cancelAtPeriodEnd) {
      return false;
    }
    const allowed = <String>{'active', 'trialing', 'incomplete'};
    return allowed.contains(record.status);
  }

  Widget _buildRentalsPage() {
    if (_loadingRentals) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_rentals.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Aún no tienes bicicletas alquiladas. Cuando completes un alquiler aparecerá aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRentals,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        itemBuilder: (context, index) {
          final record = _rentals[index];
          final isCanceling = _cancelingSubscriptions.contains(
            record.subscriptionId,
          );
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        record.bikeName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF353B4A),
                        ),
                      ),
                    ),
                    // Solo permitir eliminar si está realmente cancelado
                    if (record.status == 'canceled')
                      IconButton(
                        icon: const Icon(Icons.delete, color: Color(0xFFD32F2F)),
                        tooltip: 'Eliminar alquiler',
                        onPressed: () async {
                          await RentalSubscriptionService.instance.remove(record.subscriptionId);
                          await _loadRentals();
                        },
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: record.status == 'active'
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFF1C6FFF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        record.status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${record.planLabel} · ${record.priceLabel}',
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tiempo restante: ${_remainingTimeLabel(record.nextRenewalAtMillis)}',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  'Próxima renovación: ${_formatDate(record.nextRenewalAtMillis)}',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                if (record.cancelAtPeriodEnd) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Cancelación solicitada al final del periodo.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFFD32F2F),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton(
                    onPressed: !_canCancel(record) || isCanceling
                        ? null
                        : () => _cancelRental(record),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD32F2F),
                      side: const BorderSide(color: Color(0xFFD32F2F)),
                    ),
                    child: isCanceling
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Cancelar suscripción'),
                  ),
                ),
              ],
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemCount: _rentals.length,
      ),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  List<Widget> _buildPages(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardSize = screenWidth.clamp(320.0, 420.0).toDouble();
    final pageViewHeight = cardSize + 140;

    return [
      SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF353B4A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.search, color: Colors.white70),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '¿A dónde?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Título sección
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Electric Bike',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(
                height: pageViewHeight,
                child: PageView(
                  scrollDirection: Axis.vertical,
                  children: [
                    _buildFeaturedCard(cardSize),
                    Align(
                      alignment: Alignment.topCenter,
                      child: _bikeCard(
                        'Fat bike V20',
                        160.00,
                        5.0,
                        'assets/images/v20_1.png',
                        size: cardSize,
                        extraText: 'Velocidad máxima: 25 km/h',
                        onTap: _openEcoRiderDetail,
                        imageBackgroundColor: Colors.white,
                      ),
                    ),
                    Align(
                      alignment: Alignment.topCenter,
                      child: _bikeCard(
                        'Fatbike V8 OUXI',
                        140.00,
                        4.6,
                        'assets/images/1.png',
                        size: cardSize,
                        priceLabel: '/mes',
                        extraText: 'Velocidad máxima: 25 km/h',
                        onTap: _openFatBikeDetail,
                        imageBackgroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_showSwipeHint)
                AnimatedOpacity(
                  opacity: _hintOpacity,
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeInOut,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.import_export, color: Colors.blueGrey),
                      SizedBox(width: 8),
                      Text(
                        'Desliza hacia arriba o hacia abajo para ver más modelos',
                        style: TextStyle(
                          color: Colors.blueGrey,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      _buildRentalsPage(),
    ];
  }

  Widget _buildFeaturedCard(double cardSize) {
    final bikeCard = Align(
      alignment: Alignment.topCenter,
      child: _bikeCard(
        'Fatbike V8 PRO OUXI',
        150.00,
        4.8,
        'assets/images/2.1.png',
        size: cardSize,
        extraText: 'Velocidad máxima: 25 km/h',
        onTap: _openFatbike25Detail,
      ),
    );

    final animation = _bounceAnimation;
    if (animation == null) {
      return bikeCard;
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) =>
          Transform.translate(offset: Offset(0, animation.value), child: child),
      child: bikeCard,
    );
  }

  // Widget para las tarjetas de bicicletas
  Widget _bikeCard(
    String name,
    double price,
    double rating,
    String imagePath, {
    double size = 220,
    String? priceLabel,
    String? extraText,
    VoidCallback? onTap,
    Color? imageBackgroundColor,
  }) {
    // Puedes cambiar el tamaño de las burbujas editando el parámetro size
    // priceLabel permite mostrar "/hr" o "/mes" según la burbuja
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () async {
        final hasPayment = await PaymentMethodService.instance
            .hasPaymentMethod();
        if (!hasPayment) {
          if (!mounted) return;
          showDialog(
            context: context,
            barrierColor: Colors.black45,
            builder: (context) => Dialog(
              backgroundColor: const Color(0xFFF6F1FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1C6FFF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.payment,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Método de pago requerido',
                            style: TextStyle(
                              color: Color(0xFF353B4A),
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE53935)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFD32F2F),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No has añadido ningún método de pago.',
                              style: TextStyle(
                                color: Color(0xFFD32F2F),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Para poder alquilar una bicicleta, necesitas configurar un método de pago.',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 15,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF353B4A),
                              side: const BorderSide(color: Color(0xFF353B4A)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Cancelar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const PaymentMethodsScreen(),
                                ),
                              );
                              await _refreshNotificationBadge();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1C6FFF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'Configurar',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
          return;
        }
        if (onTap != null) {
          onTap();
        }
      },
      child: Container(
        width: size, // ← Cambia este valor para el ancho
        height: size, // ← Cambia este valor para el alto
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: size * 0.55,
              width: double.infinity,
              decoration: BoxDecoration(
                color: imageBackgroundColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '$name - €${price.toStringAsFixed(2)}${priceLabel ?? "/mes"}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
            ),
            if (extraText != null) ...[
              const SizedBox(height: 6),
              Text(
                extraText,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 22),
                Text(
                  rating.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 18,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.directions_bike, color: Colors.blue, size: 22),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openFatBikeDetail() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const BikeDetailScreen(
          name: 'Fat Bike',
          imagePath: 'assets/images/1.png',
          price: 120.0,
          priceLabel: '/mes',
          rating: 4.7,
          galleryImages: [
            'assets/images/1.png',
            'assets/images/2.png',
            'assets/images/3.png',
            'assets/images/4.png',
          ],
        ),
      ),
    );
  }

  void _openFatbike25Detail() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const Fatbike25DetailScreen()),
    );
  }

  void _openEcoRiderDetail() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const EcoRiderDetailScreen()),
    );
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => const ProfileScreen()));
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        leading: _selectedIndex == 0
            ? IconButton(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_none),
                    if (_hasPendingNotifications)
                      Positioned(
                        right: -1,
                        top: -1,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const NotificationsScreen(),
                    ),
                  );
                  await _refreshNotificationBadge();
                },
              )
            : null,
      ),
      body: _buildPages(context)[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: _backgroundColor,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.black54,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_2),
            label: 'Alquileres',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
