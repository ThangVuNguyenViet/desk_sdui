import 'package:flutter/foundation.dart';

class ChefController {
  ChefController({this.onDishTapped, this.onBackTapped, this.onBookmarkTapped});

  final void Function(String dishId)? onDishTapped;
  final VoidCallback? onBackTapped;
  final VoidCallback? onBookmarkTapped;

  final ValueNotifier<bool> isBookmarked = ValueNotifier(false);

  void toggleBookmark() {
    isBookmarked.value = !isBookmarked.value;
    onBookmarkTapped?.call();
  }

  void tapDish(String id) => onDishTapped?.call(id);

  void tapBack() => onBackTapped?.call();

  void dispose() {
    isBookmarked.dispose();
  }
}
