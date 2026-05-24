import 'package:desk_sdui/desk_sdui.dart';
import 'package:flutter/material.dart';
import 'product_demo_v1.dart';
import 'demo_actions.dart';

part 'product_demo_v2.sdui.g.dart';

const Color _primaryColor = Color(0xFF00BFA6);

@Register([
  BoxDecoration,
  BorderRadius,
  Radius,
  Border,
  BorderSide,
  Color,
  EdgeInsets,
])
@Screen('product_demo_v2')
Widget productDemoV2(BuildContext context) {
  final vm = ProductViewModelProvider.of(context);
  return Container(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24.0, 32.0, 24.0, 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'THE COLLECTION',
                style: TextStyle(
                  color: Color(0xFF00FFCC),
                  fontSize: 12.0,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 8.0),
              const Text(
                'Featured',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32.0,
                  fontWeight: FontWeight.w300,
                  letterSpacing: -1.0,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            children: [
              for (final p in vm.products)
                ProductCard(
                  p: p, 
                  onAddToCart: () {
                    vm.addToCart(context, p);
                    demoShowSuccess(context, p.title);
                  },
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class ProductCard extends StatelessWidget {
  final Product p;
  final VoidCallback onAddToCart;

  const ProductCard({
    required this.p,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2A),
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: const Color(0xFF2A2A35),
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    p.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                  decoration: BoxDecoration(
                    color: const Color(0x3300BFA6),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Text(
                    'USD ${p.price}',
                    style: const TextStyle(
                      color: Color(0xFF00FFCC),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            Text(
              p.description,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 14.0,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24.0),
            GestureDetector(
              onTap: onAddToCart,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                decoration: BoxDecoration(
                  color: _primaryColor,
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: const Center(
                  child: Text(
                    'ADD TO CART',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.0,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
