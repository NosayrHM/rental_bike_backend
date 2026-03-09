import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'rental_success_screen.dart';
import '../services/rental_subscription_service.dart';
import '../services/stripe_service.dart';

const _backgroundColor = Color(0xFFF6F1FF);
const _accentColor = Color(0xFF353B4A);
const _priceBadgeColor = Color(0xFF1C6FFF);

class RentalConfigScreen extends StatefulWidget {
  const RentalConfigScreen({
    super.key,
    required this.planLabel,
    required this.planPrice,
    required this.planPriceLabel,
    required this.bikeName,
    this.stripeSubscriptionPriceId,
  });

  final String planLabel;
  final double planPrice;
  final String planPriceLabel;
  final String bikeName;
  final String? stripeSubscriptionPriceId;

  @override
  State<RentalConfigScreen> createState() => _RentalConfigScreenState();
}

class _RentalConfigScreenState extends State<RentalConfigScreen> {
  static const _extras = <_ExtraOption>[
    _ExtraOption(
      id: 'helmet',
      title: 'Casco',
      description:
          'Casco de protección con luz trasera LED. Incluye certificación de seguridad y sistema de ventilación. Talla universal ajustable.',
      price: '15€',
      priceValue: 15,
    ),
    _ExtraOption(
      id: 'gloves',
      title: 'Guantes',
      description:
          'Guantes deportivos de alta resistencia con palma antideslizante. Protegen contra abrasiones y frío. Talla universal ajustable.',
      price: '8€',
      priceValue: 8,
    ),
    _ExtraOption(
      id: 'battery',
      title: 'Batería extra',
      description:
          'Batería de repuesto de iones de litio de 10Ah. Compatible con el sistema de la Fatbike V8 Pro. Autonomía adicional de 40km.',
      price: '180€',
      priceValue: 180,
    ),
  ];

  final Set<String> _selectedExtras = <String>{};
  bool _processingPayment = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          widget.planLabel,
          style: const TextStyle(color: Colors.black87),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const SizedBox(height: 8),
          const Text(
            'Añadir extras',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          for (final extra in _extras) ...[
            _ExtraCard(
              option: extra,
              selected: _selectedExtras.contains(extra.id),
              priceLabel: extra.price,
              onChanged: (value) {
                setState(() {
                  if (value) {
                    _selectedExtras.add(extra.id);
                  } else {
                    _selectedExtras.remove(extra.id);
                  }
                });
              },
            ),
            const SizedBox(height: 16),
          ],
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total estimado',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      _buildTotalLabel(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Alquiler',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    Text(
                      widget.planPriceLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _buildExtrasSummary(),
                  style: const TextStyle(color: Colors.black54, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _priceBadgeColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            onPressed: _processingPayment ? null : _handlePayment,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_processingPayment)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  const Text(
                    'Pagar ahora',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                const SizedBox(width: 12),
                const Icon(Icons.arrow_forward, size: 22),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildTotalLabel() {
    final total = _totalWithExtras();
    return '${_formatAmount(total)}€';
  }

  String _buildExtrasSummary() {
    final extrasTotal = _calculateExtrasTotal();
    if (extrasTotal == 0) {
      return 'Selecciona extras opcionales para tu alquiler.';
    }
    return 'Extras seleccionados: ${_formatAmount(extrasTotal)}€';
  }

  double _calculateExtrasTotal() {
    return _extras
        .where((extra) => _selectedExtras.contains(extra.id))
        .fold<double>(0, (total, extra) => total + extra.priceValue);
  }

  double _totalWithExtras() {
    return widget.planPrice + _calculateExtrasTotal();
  }

  String _formatAmount(double amount) {
    final isInt = amount % 1 == 0;
    final formatted = isInt
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
    return formatted.replaceAll('.', ',');
  }

  Future<void> _handlePayment() async {
    final subscriptionPriceId = (widget.stripeSubscriptionPriceId ?? '').trim();
    final isRecurringPlan =
        widget.planLabel.toLowerCase().contains('semanal') ||
        widget.planLabel.toLowerCase().contains('mensual');
    final isRecurringSubscription = subscriptionPriceId.isNotEmpty;

    if (isRecurringPlan && !isRecurringSubscription) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Este plan es de suscripción, pero no tiene Price ID configurado (price_...).',
          ),
        ),
      );
      return;
    }

    final total = _totalWithExtras();
    final totalInCents = (total * 100).round();
    setState(() {
      _processingPayment = true;
    });
    try {
      if (isRecurringSubscription) {
        final subscription = await StripeService.instance.presentSubscriptionSheet(
          priceId: subscriptionPriceId,
          description: 'Suscripción ${widget.planLabel}',
        );

        final subscriptionId = subscription.subscriptionId;
        final renewalAt = subscription.currentPeriodEndMillis;
        if (subscriptionId != null && renewalAt != null) {
          await RentalSubscriptionService.instance.upsert(
            RentalSubscriptionRecord(
              subscriptionId: subscriptionId,
              customerId: subscription.customerId,
              bikeName: widget.bikeName,
              planLabel: widget.planLabel,
              priceLabel: widget.planPriceLabel,
              status: subscription.status ?? 'unknown',
              createdAtMillis: DateTime.now().millisecondsSinceEpoch,
              nextRenewalAtMillis: renewalAt,
              cancelAtPeriodEnd: false,
            ),
          );
        }
      } else {
        await StripeService.instance.presentPaymentSheet(
          amountCents: totalInCents,
          currency: 'eur',
          description: 'Alquiler ${widget.planLabel}',
        );
      }

        if (!mounted) {
          return;
        }

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const RentalSuccessScreen(),
          ),
          (route) => false,
        );
    } on StripeException catch (error) {
      if (!mounted) {
        return;
      }
      final message = error.error.localizedMessage ?? 'Pago cancelado.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al procesar el pago: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingPayment = false;
        });
      }
    }
  }
}

class _ExtraOption {
  const _ExtraOption({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.priceValue,
  });

  final String id;
  final String title;
  final String description;
  final String price;
  final double priceValue;
}

class _ExtraCard extends StatelessWidget {
  const _ExtraCard({
    required this.option,
    required this.selected,
    required this.priceLabel,
    required this.onChanged,
  });

  final _ExtraOption option;
  final bool selected;
  final String priceLabel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => onChanged(!selected),
        child: Ink(
          decoration: BoxDecoration(
            color: _accentColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: selected,
                onChanged: (value) => onChanged(value ?? false),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                checkColor: Colors.white,
                activeColor: _priceBadgeColor,
                side: const BorderSide(color: Colors.white70),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      option.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _priceBadgeColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  priceLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
