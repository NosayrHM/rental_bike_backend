import 'package:flutter/material.dart';

import '../widgets/image_preview.dart';
import '../widgets/spec_row.dart';
import 'rental_config_screen.dart';

const _ecoRiderMonthlyPriceId = String.fromEnvironment(
  'STRIPE_PRICE_ECO_RIDER_MONTHLY',
  defaultValue: 'price_1T3JOYRUYbbTSSSbEa0FL0ij',
);
const _ecoRiderWeeklyPriceId = String.fromEnvironment(
  'STRIPE_PRICE_ECO_RIDER_WEEKLY',
  defaultValue: 'price_1T3JUdRUYbbTSSSbF9stTjzl',
);

class EcoRiderDetailScreen extends StatelessWidget {
  const EcoRiderDetailScreen({super.key});

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
          bikeName: 'Fat bike V20',
          stripeSubscriptionPriceId: stripeSubscriptionPriceId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const mainImagePath = 'assets/images/v20_1.png';
    final previewImages = <String>[
      mainImagePath,
      'assets/images/v20_2.png',
      'assets/images/v20_3.png',
      'assets/images/v20_4.png',
      'assets/images/v20_5.png',
      'assets/images/v20_6.png',
    ];
    final thumbnailImages = previewImages.length > 1
        ? previewImages.sublist(1)
        : const <String>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Fat bike V20')),
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
                  '5.0',
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
              'Detalles sostenibles de la Eco Rider:',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            const SpecRow('Autonomía urbana: 70 km por carga'),
            const SpecRow('Motor eficiente de 250W con modo eco'),
            const SpecRow('Batería de iones de litio de 36V recargable'),
            const SpecRow('Componentes reciclables y neumáticos antipinchazos'),
            const SizedBox(height: 24),
            const Text(
              'Opciones de alquiler',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _RentalOptionTile(
              title: 'Plan semanal',
              subtitle:
                  'Perfecto para city tours y desplazamientos sostenibles.',
              trailing: '50€/semana',
              onPressed: () =>
                  _openRentalConfig(
                    context,
                    'Plan semanal',
                    50,
                    '50€/semana',
                    _ecoRiderWeeklyPriceId,
                  ),
            ),
            const SizedBox(height: 12),
            _RentalOptionTile(
              title: 'Plan mensual',
              subtitle: 'Incluye casco, soporte y recarga de cortesía.',
              trailing: '160€/mes',
              onPressed: () =>
                  _openRentalConfig(
                    context,
                    'Plan mensual',
                    160,
                    '160€/mes',
                    _ecoRiderMonthlyPriceId,
                  ),
            ),
            const SizedBox(height: 12),
            _RentalOptionTile(
              title: 'Compra la bicicleta',
              subtitle: 'Mantenimiento preventivo y asistencia eco-friendly.',
              trailing: '1.699,99€',
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
