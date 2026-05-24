import 'package:desk_sdui/desk_sdui.dart';
import 'package:flutter/material.dart';
import 'demo_actions.dart';

part 'product_demo_v1.sdui.g.dart';

@Register([Product, ProductViewModel])
class Product {
  final String id;
  final String title;
  final double price;
  final String description;

  Product({
    required this.id,
    required this.title,
    required this.price,
    required this.description,
  });
}

class ProductViewModel extends ChangeNotifier {
  final List<Product> products;
  
  ProductViewModel(this.products);

  void addToCart(BuildContext context, Product p) {
    print('Added ${p.title} to cart');
    notifyListeners();
  }
}

class ProductViewModelProvider extends InheritedWidget {
  final ProductViewModel vm;

  const ProductViewModelProvider({
    super.key,
    required this.vm,
    required super.child,
  });

  static ProductViewModel of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<ProductViewModelProvider>();
    assert(result != null, 'No ProductViewModelProvider found in context');
    return result!.vm;
  }

  @override
  bool updateShouldNotify(ProductViewModelProvider oldWidget) => vm != oldWidget.vm;
}

@Screen('product_demo')
Widget productDemoV1(BuildContext context) {
  final vm = ProductViewModelProvider.of(context);
  final theme = Theme.of(context);

  return ListView(
    children: [
      for (final p in vm.products)
        Card(
          margin: const EdgeInsets.all(8.0),
          child: ListTile(
            title: Text(p.title),
            subtitle: Text(p.description),
            trailing: ElevatedButton(
              onPressed: () {
                vm.addToCart(context, p);
                demoShowSnackBar(context, p.title);
              },
              child: const Text('Add to Cart'),
            ),
          ),
        ),
    ],
  );
}
