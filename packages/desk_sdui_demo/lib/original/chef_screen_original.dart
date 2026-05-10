import 'package:flutter/material.dart';
import '../data/chef_data.dart';
import '../controllers/chef_controller.dart';
import '../widgets/app_image.dart';

Widget renderChefOriginal(ChefData data, ChefController controller) {
  return Stack(
    children: [
      SingleChildScrollView(
        padding: const EdgeInsets.only(top: 102, bottom: 130),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.headline,
                    style: const TextStyle(
                      fontSize: 40,
                      height: 1.02,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    data.bio,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF6B6B6B),
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 26),
              decoration: BoxDecoration(
                color: const Color(0xFF2D5F2D),
                borderRadius: BorderRadius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  const Positioned(
                    top: 8,
                    left: 22,
                    child: Text(
                      '\u201C',
                      style: TextStyle(
                        fontSize: 120,
                        fontStyle: FontStyle.italic,
                        color: Color(0x1FFFFFFF),
                        height: 1,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cooking is about patience, passion, and the pursuit of flavor that lingers in memory.',
                          style: TextStyle(
                            fontSize: 22,
                            height: 1.28,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFFE8E8E8),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(
                          color: Color(0x26FFFFFF),
                          height: 1,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(26),
                              child: AppImage(
                                url: data.chefPortraitUrl,
                                width: 52,
                                height: 52,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data.chefName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontStyle: FontStyle.italic,
                                      color: Color(0xFFE8E8E8),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    data.chefRole.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xB2FFFFFF),
                                      letterSpacing: 1,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0x59FFFFFF),
                                ),
                              ),
                              child: const Icon(
                                Icons.play_arrow,
                                size: 14,
                                color: Color(0xFFE8E8E8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            for (int i = 0; i < data.dishes.length; i++) ...[
              _DishRow(
                dish: data.dishes[i],
                isLast: i == data.dishes.length - 1,
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 34, 24, 0),
              child: Text(
                '— ${data.refreshCadence} —',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF6B6B6B),
                ),
              ),
            ),
          ],
        ),
      ),
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 14),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.6, 1.0],
              colors: [
                Color(0xFAF5F0F0),
                Color(0x00F5F0F0),
              ],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: controller.tapBack,
                child: const Icon(Icons.arrow_back_ios_new, size: 20),
              ),
              const Text(
                "CHEF'S CHOICE",
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: controller.isBookmarked,
                builder: (context, value, child) {
                  return GestureDetector(
                    onTap: controller.toggleBookmark,
                    child: Icon(
                      value ? Icons.bookmark : Icons.bookmark_outline,
                      size: 20,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _DishRow extends StatelessWidget {
  final ChefDish dish;
  final bool isLast;

  const _DishRow({
    required this.dish,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        isLast ? 0 : 26,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AppImage(
                url: dish.imageUrl,
                width: 118,
                height: 150,
              ),
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xF2F5F0F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    dish.numberLabel,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          dish.name,
                          style: const TextStyle(
                            fontSize: 19,
                            fontStyle: FontStyle.italic,
                            letterSpacing: -0.2,
                            height: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '\$${dish.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  if (dish.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      dish.description,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF6B6B6B),
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Text(
                          '+ Add to order',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      Text(
                        'single serving',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9E9E9E),
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
