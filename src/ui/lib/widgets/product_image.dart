import 'package:flutter/material.dart';
import '../theme.dart';
import 'food_image.dart';

/// Do'kon bo'limining ikonkasi va rangi — rasmi yo'q tovarlar uchun
IconData shopIcon(String category) => switch (category) {
      'Forma' => Icons.checkroom_outlined,
      'Suv idishlari' => Icons.local_cafe_outlined,
      'Anjomlar' => Icons.fitness_center_outlined,
      'Protein' => Icons.local_drink_outlined,
      'Gainer' => Icons.inventory_2_outlined,
      'Kreatin' => Icons.science_outlined,
      'L-Karnitin' => Icons.water_drop_outlined,
      'L-Arginin' => Icons.bolt_outlined,
      _ => Icons.medication_liquid_outlined,
    };

Color shopColor(String category) => switch (category) {
      'Forma' => AppColors.water,
      'Suv idishlari' => AppColors.water,
      'Anjomlar' => AppColors.warning,
      'Gainer' => AppColors.accent,
      'Kreatin' => AppColors.success,
      'L-Karnitin' => AppColors.danger,
      'L-Arginin' => AppColors.water,
      _ => AppColors.protein,
    };

/// Tovar rasmi: havola -> nomiga mos ichki rasm (protein, gainer ...) -> bo'lim ikonkasi.
/// Mahsulotlar bazasidagi bilan bir xil qoida ishlatiladi ([FoodImage]).
class ProductImage extends StatelessWidget {
  final String category;
  final String name;
  final String url;
  final double size;
  const ProductImage({
    super.key,
    required this.category,
    this.name = '',
    this.url = '',
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    final hasPicture = url.trim().isNotEmpty || foodAsset(name) != null;
    return hasPicture
        ? FoodImage(name: name, url: url, size: size)
        : _StudioPanel(
            icon: shopIcon(category), tint: shopColor(category), size: size);
  }
}

class _StudioPanel extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final double size;
  const _StudioPanel(
      {required this.icon, required this.tint, required this.size});

  @override
  Widget build(BuildContext context) {
    final light = AppColors.light;
    final center = light ? AppColors.card : AppColors.cardHigh;
    final edge = light ? AppColors.cardHigh : AppColors.card;
    Color mix(Color c) => Color.alphaBlend(tint.withValues(alpha: 0.06), c);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.hairline),
        gradient: RadialGradient(colors: [mix(center), mix(edge)]),
      ),
      child: Stack(alignment: Alignment.center, children: [
        Positioned(
          bottom: size * 0.14,
          child: Container(
            width: size * 0.5,
            height: size * 0.08,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size),
              color: (light ? AppColors.text : AppColors.bgDeep)
                  .withValues(alpha: light ? 0.12 : 0.35),
            ),
          ),
        ),
        Icon(icon, color: tint, size: size * 0.46),
      ]),
    );
  }
}
