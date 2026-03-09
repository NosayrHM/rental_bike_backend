import 'package:flutter/material.dart';

import '../widgets/image_preview.dart';
import '../widgets/spec_row.dart';
import 'rental_config_screen.dart';

const _v8OuxiMonthlyPriceId = String.fromEnvironment(
  'STRIPE_PRICE_V8_OUXI_MONTHLY',
  defaultValue: 'price_1T3JIvRUYbbTSSSbNtrC9W4c',
);
const _v8OuxiWeeklyPriceId = String.fromEnvironment(
  'STRIPE_PRICE_V8_OUXI_WEEKLY',
  defaultValue: 'price_1T3JMORUYbbTSSSb0ycGXpxh',
);

class BikeDetailScreen extends StatelessWidget {
  const BikeDetailScreen({
    super.key,
    required this.name,
    required this.imagePath,
    required this.price,
    required this.priceLabel,
    required this.rating,
    this.galleryImages = const [],
  });

  final String name;
  final String imagePath;
  final double price;
  final String priceLabel;
  final double rating;
  final List<String> galleryImages;

  @override
  Widget build(BuildContext context) {
    const weeklyLabel = '45€/semana';
    const monthlyLabel = '140€/mes';
    final previewImages = <String>[imagePath, ...galleryImages]
        .fold<List<String>>(<String>[], (acc, path) {
          if (!acc.contains(path)) {
            acc.add(path);
          }
          return acc;
        });
    final thumbnailImages = previewImages.length > 1
        ? previewImages.sublist(1)
        : const <String>[];

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => showImagePreview(context, previewImages, 0),
              child: Hero(
                tag: imagePath,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    imagePath,
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
                Text(
                  rating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
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
              'Características destacadas de la Fatbike V8 Ouxi:',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            const SpecRow('Modelo: V8 Ouxi'),
            const SpecRow('Velocidad máxima: 25 km/h'),
            const SpecRow('Autonomía: 80 km'),
            const SpecRow('Motor: 250W'),
            const SpecRow('Batería: 48V 28.6Ah'),
            const SizedBox(height: 24),
            const Text(
              'Opciones de alquiler',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _RentalOptionTile(
              title: 'Plan semanal',
              subtitle: 'Incluye mantenimiento y casco durante la semana.',
              trailing: weeklyLabel,
              onPressed: () => _openRentalConfig(
                context,
                'Plan semanal',
                45,
                weeklyLabel,
                _v8OuxiWeeklyPriceId,
              ),
            ),
            const SizedBox(height: 12),
            _RentalOptionTile(
              title: 'Plan mensual',
              subtitle: 'Tarifa reducida para uso continuo con soporte 24/7.',
              trailing: monthlyLabel,
              onPressed: () => _openRentalConfig(
                context,
                'Plan mensual',
                140,
                monthlyLabel,
                _v8OuxiMonthlyPriceId,
              ),
            ),
            const SizedBox(height: 12),
            _RentalOptionTile(
              title: 'Comprar bicicleta',
              subtitle: 'Compra la bicicleta con garantía y soporte.',
              trailing: '1.499,99€',
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
          bikeName: name,
          stripeSubscriptionPriceId: stripeSubscriptionPriceId,
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
    this.trailing,
  });

  final String title;
  final String subtitle;
  final VoidCallback onPressed;
  final String? trailing;

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
              if (trailing != null) ...[
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
                        trailing!,
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
              ] else ...[
                const SizedBox(width: 12),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.white,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
