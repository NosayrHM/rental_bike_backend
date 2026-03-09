import 'package:flutter/material.dart';

import '../widgets/image_preview.dart';
import '../widgets/spec_row.dart';
import 'rental_config_screen.dart';

const _fatbikeV8ProMonthlyPriceId = String.fromEnvironment(
  'STRIPE_PRICE_V8_PRO_MONTHLY',
  defaultValue: 'price_1T3JWkRUYbbTSSSb9Y2WOHpA',
);
const _fatbikeV8ProWeeklyPriceId = String.fromEnvironment(
  'STRIPE_PRICE_V8_PRO_WEEKLY',
  defaultValue: 'price_1T3JXRRUYbbTSSSbfwf39T3U',
);

class Fatbike25DetailScreen extends StatelessWidget {
  const Fatbike25DetailScreen({super.key});

  void _openRentalConfig(
    BuildContext context,
    String planLabel,
    double planPrice,
    String planPriceLabel,
    String? stripeSubscriptionPriceId,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RentalConfigScreen(
          planLabel: planLabel,
          planPrice: planPrice,
          planPriceLabel: planPriceLabel,
          bikeName: 'Fatbike V8 Pro Ouxi',
          stripeSubscriptionPriceId: stripeSubscriptionPriceId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const mainImagePath = 'assets/images/2.1.png';
    final previewImages = <String>[
      mainImagePath,
      'assets/images/2.2.png',
      'assets/images/2.3.png',
      'assets/images/2.4.png',
    ];
    final thumbnailImages = previewImages.length > 1
        ? previewImages.sublist(1)
        : const <String>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Fatbike V8 Pro')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => showImagePreview(context, previewImages, 0),
              child: Hero(
                tag: mainImagePath,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    mainImagePath,
                    width: double.infinity,
                    height: 220,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (thumbnailImages.isNotEmpty) ...[
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) {
                    final imagePath = thumbnailImages[index];
                    return GestureDetector(
                      onTap: () =>
                          showImagePreview(context, previewImages, index + 1),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          imagePath,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (context, _) => const SizedBox(width: 12),
                  itemCount: thumbnailImages.length,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber.shade600),
                const SizedBox(width: 8),
                const Text(
                  '4.8',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Descripción',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Detalles principales de la Fatbike V8 Pro Ouxi:',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            const SpecRow('Modelo: Fatbike V8 Pro Ouxi'),
            const SpecRow('Sistema de asistencia al pedaleo de 7 niveles'),
            const SpecRow('Frenos de disco hidráulicos'),
            const SpecRow('Alarma con control remoto'),
            const SpecRow('Capacidad de carga: hasta 150 kg'),
            const SpecRow('Velocidad máxima: 25 km/h (con asistencia)'),
            const SpecRow('Autonomía media: 65 km'),
            const SpecRow('Motor: 250W'),
            const SpecRow('Batería de litio extraíble - 48w 15Ah'),
            const SizedBox(height: 24),
            const Text(
              'Opciones de alquiler',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _RentalOptionTile(
              title: 'plan semanal',
              subtitle:
                  'Ideal para trabajos a corto plazo. (pulsa aquí para mas detalles).',
              trailing: '45€/semana',
              onPressed: () => _openRentalConfig(
                context,
                'Plan semanal',
                45,
                '45€/semana',
                _fatbikeV8ProWeeklyPriceId,
              ),
            ),
            const SizedBox(height: 12),
            _RentalOptionTile(
              title: 'plan mensual',
              subtitle:
                  'Ideal para trabajos largo plazo. (pulsa aquí para mas detalles).',
              trailing: '150€/mes',
              onPressed: () => _openRentalConfig(
                context,
                'Plan mensual',
                150,
                '150€/mes',
                _fatbikeV8ProMonthlyPriceId,
              ),
            ),
            const SizedBox(height: 12),
            _RentalOptionTile(
              title: 'Comprar la bicicleta',
              subtitle: 'Compra la bicicleta con garantía y soporte.',
              trailing: '1.599,99€',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Configura la compra de la bicicleta.'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RentalOptionTile extends StatelessWidget {
  const _RentalOptionTile({
    required this.title,
    required this.subtitle,
    required this.onPressed,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final VoidCallback onPressed;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      color: const Color.fromARGB(255, 53, 59, 74),
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.pedal_bike, color: Colors.blue.shade600),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color.fromARGB(255, 255, 255, 255),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 28, 111, 255),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      trailing,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color.fromARGB(255, 255, 255, 255),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.white,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
