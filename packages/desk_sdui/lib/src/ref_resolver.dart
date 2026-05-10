import 'package:flutter/material.dart';

/// Walks a pre-split path through nested maps/lists and returns the leaf.
///
/// Codegen emits paths like `['data','items','0','title']`; per-build cost
/// is one `Map.[]` or `List.[]` per segment.
Object? resolveRef(List<String> path, Map<String, Object?> input) {
  Object? current = input;
  for (final seg in path) {
    if (current == null) return null;
    if (current is Map) {
      final getters = current['__getters__'];
      if (getters is Map && getters.containsKey(seg)) {
        final g = getters[seg];
        if (g is Function) {
          current = Function.apply(g, const []);
          continue;
        }
      }
      current = current[seg];
      continue;
    }
    if (current is List) {
      final i = int.tryParse(seg);
      if (i == null || i < 0 || i >= current.length) return null;
      current = current[i];
      continue;
    }
    // Try dynamic property access on arbitrary objects
    current = _getProperty(current, seg);
    if (current == null) return null;
  }
  return current;
}

/// Resolves a reference path that may start with a Flutter class name
/// (e.g., ['Icons', 'arrow_back_ios_new'], ['CrossAxisAlignment', 'start']).
Object? resolveFlutterRef(List<String> path, Map<String, Object?> input) {
  if (path.isEmpty) return null;
  // Check if the first segment is a Flutter class reference
  final flutterValue = _resolveFlutterConstant(path);
  if (flutterValue != null) return flutterValue;
  // Fall back to normal ref resolution
  return resolveRef(path, input);
}

Object? _resolveFlutterConstant(List<String> path) {
  if (path.length < 2) return null;
  final className = path[0];
  final memberName = path[1];
  return switch (className) {
    'Icons' => _resolveIcon(memberName),
    'CrossAxisAlignment' => _resolveCrossAxisAlignment(memberName),
    'MainAxisAlignment' => _resolveMainAxisAlignment(memberName),
    'MainAxisSize' => _resolveMainAxisSize(memberName),
    'TextAlign' => _resolveTextAlign(memberName),
    'TextBaseline' => _resolveTextBaseline(memberName),
    'TextOverflow' => _resolveTextOverflow(memberName),
    'FontStyle' => _resolveFontStyle(memberName),
    'FontWeight' => _resolveFontWeight(memberName),
    'BoxFit' => _resolveBoxFit(memberName),
    'Axis' => _resolveAxis(memberName),
    'WrapCrossAlignment' => _resolveWrapCrossAlignment(memberName),
    'StackFit' => _resolveStackFit(memberName),
    'Clip' => _resolveClip(memberName),
    'Colors' => _resolveColor(memberName),
    'BoxShape' => _resolveBoxShape(memberName),
    _ => null,
  };
}

IconData? _resolveIcon(String name) => switch (name) {
  'arrow_back_ios_new' => Icons.arrow_back_ios,
  'arrow_back_ios' => Icons.arrow_back_ios,
  'bookmark' => Icons.bookmark,
  'bookmark_border' => Icons.bookmark_border,
  'play_arrow' => Icons.play_arrow,
  'person' => Icons.person,
  'image' => Icons.image,
  'home' => Icons.home,
  'search' => Icons.search,
  'settings' => Icons.settings,
  'menu' => Icons.menu,
  'close' => Icons.close,
  'check' => Icons.check,
  'add' => Icons.add,
  'remove' => Icons.remove,
  'delete' => Icons.delete,
  'edit' => Icons.edit,
  'favorite' => Icons.favorite,
  'favorite_border' => Icons.favorite_border,
  'star' => Icons.star,
  'star_border' => Icons.star_border,
  'visibility' => Icons.visibility,
  'visibility_off' => Icons.visibility_off,
  'lock' => Icons.lock,
  'lock_open' => Icons.lock_open,
  'email' => Icons.email,
  'phone' => Icons.phone,
  'location_on' => Icons.location_on,
  'calendar_today' => Icons.calendar_today,
  'shopping_cart' => Icons.shopping_cart,
  'restaurant' => Icons.restaurant,
  'local_dining' => Icons.local_dining,
  _ => null,
};

CrossAxisAlignment _resolveCrossAxisAlignment(String name) => switch (name) {
  'start' => CrossAxisAlignment.start,
  'end' => CrossAxisAlignment.end,
  'center' => CrossAxisAlignment.center,
  'stretch' => CrossAxisAlignment.stretch,
  'baseline' => CrossAxisAlignment.baseline,
  _ => CrossAxisAlignment.center,
};

MainAxisAlignment _resolveMainAxisAlignment(String name) => switch (name) {
  'start' => MainAxisAlignment.start,
  'end' => MainAxisAlignment.end,
  'center' => MainAxisAlignment.center,
  'spaceBetween' => MainAxisAlignment.spaceBetween,
  'spaceAround' => MainAxisAlignment.spaceAround,
  'spaceEvenly' => MainAxisAlignment.spaceEvenly,
  _ => MainAxisAlignment.start,
};

MainAxisSize _resolveMainAxisSize(String name) => switch (name) {
  'min' => MainAxisSize.min,
  'max' => MainAxisSize.max,
  _ => MainAxisSize.max,
};

TextAlign _resolveTextAlign(String name) => switch (name) {
  'left' => TextAlign.left,
  'right' => TextAlign.right,
  'center' => TextAlign.center,
  'justify' => TextAlign.justify,
  'start' => TextAlign.start,
  'end' => TextAlign.end,
  _ => TextAlign.start,
};

TextBaseline _resolveTextBaseline(String name) => switch (name) {
  'alphabetic' => TextBaseline.alphabetic,
  'ideographic' => TextBaseline.ideographic,
  _ => TextBaseline.alphabetic,
};

TextOverflow _resolveTextOverflow(String name) => switch (name) {
  'clip' => TextOverflow.clip,
  'fade' => TextOverflow.fade,
  'ellipsis' => TextOverflow.ellipsis,
  'visible' => TextOverflow.visible,
  _ => TextOverflow.clip,
};

FontStyle _resolveFontStyle(String name) => switch (name) {
  'normal' => FontStyle.normal,
  'italic' => FontStyle.italic,
  _ => FontStyle.normal,
};

FontWeight _resolveFontWeight(String name) => switch (name) {
  'normal' => FontWeight.normal,
  'bold' => FontWeight.bold,
  'w100' => FontWeight.w100,
  'w200' => FontWeight.w200,
  'w300' => FontWeight.w300,
  'w400' => FontWeight.w400,
  'w500' => FontWeight.w500,
  'w600' => FontWeight.w600,
  'w700' => FontWeight.w700,
  'w800' => FontWeight.w800,
  'w900' => FontWeight.w900,
  _ => FontWeight.normal,
};

BoxFit _resolveBoxFit(String name) => switch (name) {
  'fill' => BoxFit.fill,
  'contain' => BoxFit.contain,
  'cover' => BoxFit.cover,
  'fitWidth' => BoxFit.fitWidth,
  'fitHeight' => BoxFit.fitHeight,
  'none' => BoxFit.none,
  'scaleDown' => BoxFit.scaleDown,
  _ => BoxFit.cover,
};

Axis _resolveAxis(String name) => switch (name) {
  'horizontal' => Axis.horizontal,
  'vertical' => Axis.vertical,
  _ => Axis.vertical,
};

WrapCrossAlignment _resolveWrapCrossAlignment(String name) => switch (name) {
  'start' => WrapCrossAlignment.start,
  'end' => WrapCrossAlignment.end,
  'center' => WrapCrossAlignment.center,
  _ => WrapCrossAlignment.start,
};

StackFit _resolveStackFit(String name) => switch (name) {
  'loose' => StackFit.loose,
  'expand' => StackFit.expand,
  'passthrough' => StackFit.passthrough,
  _ => StackFit.loose,
};

Clip _resolveClip(String name) => switch (name) {
  'none' => Clip.none,
  'hardEdge' => Clip.hardEdge,
  'antiAlias' => Clip.antiAlias,
  'antiAliasWithSaveLayer' => Clip.antiAliasWithSaveLayer,
  _ => Clip.hardEdge,
};

Color? _resolveColor(String name) => switch (name) {
  'transparent' => Colors.transparent,
  'white' => Colors.white,
  'black' => Colors.black,
  'red' => Colors.red,
  'green' => Colors.green,
  'blue' => Colors.blue,
  'yellow' => Colors.yellow,
  'grey' => Colors.grey,
  'orange' => Colors.orange,
  'purple' => Colors.purple,
  'pink' => Colors.pink,
  'cyan' => Colors.cyan,
  'brown' => Colors.brown,
  _ => null,
};

BoxShape _resolveBoxShape(String name) => switch (name) {
  'circle' => BoxShape.circle,
  'rectangle' => BoxShape.rectangle,
  _ => BoxShape.rectangle,
};

Object? _getProperty(Object obj, String name) {
  switch (obj) {
    case _:
      // Use dynamic dispatch to access properties
      return _dynamicGet(obj, name);
  }
}

Object? _dynamicGet(Object obj, String name) {
  // Since Flutter doesn't support mirrors, we use a workaround:
  // Convert the object to a map-like structure via JSON or explicit handling.
  // For now, we handle known data types explicitly.
  // This is a Phase 3 fix-up: proper reflection would be ideal.
  return _tryGet(obj, name);
}

Object? _tryGet(Object obj, String name) {
  // Attempt to access common property patterns on data objects
  // This handles the demo data classes (ChefData, HomeData, etc.)
  final dynamic d = obj;
  try {
    return _accessProperty(d, name);
  } catch (_) {
    return null;
  }
}

Object? _accessProperty(dynamic obj, String name) {
  switch (name) {
    case 'headline':
      return obj.headline;
    case 'bio':
      return obj.bio;
    case 'pullQuote':
      return obj.pullQuote;
    case 'chefName':
      return obj.chefName;
    case 'chefRole':
      return obj.chefRole;
    case 'chefRoleUpper':
      return obj.chefRoleUpper;
    case 'chefPortraitUrl':
      return obj.chefPortraitUrl;
    case 'refreshCadence':
      return obj.refreshCadence;
    case 'dishes':
      return obj.dishes;
    case 'numberLabel':
      return obj.numberLabel;
    case 'name':
      return obj.name;
    case 'description':
      return obj.description;
    case 'price':
      return obj.price;
    case 'priceLabel':
      return obj.priceLabel;
    case 'imageUrl':
      return obj.imageUrl;
    case 'greeting':
      return obj.greeting;
    case 'points':
      return obj.points;
    case 'bannerImageUrl':
      return obj.bannerImageUrl;
    case 'backgroundImageUrl':
      return obj.backgroundImageUrl;
    case 'featuredItems':
      return obj.featuredItems;
    case 'categories':
      return obj.categories;
    case 'recentOrders':
      return obj.recentOrders;
    case 'orderAgainText':
      return obj.orderAgainText;
    case 'startOrderLabel':
      return obj.startOrderLabel;
    case 'showCategories':
      return obj.showCategories;
    case 'showRecentOrders':
      return obj.showRecentOrders;
    case 'showFeatured':
      return obj.showFeatured;
    case 'id':
      return obj.id;
    case 'restaurantName':
      return obj.restaurantName;
    case 'items':
      return obj.items;
    case 'total':
      return obj.total;
    case 'date':
      return obj.date;
    case 'isNotEmpty':
      return obj.isNotEmpty;
    case 'isEmpty':
      return obj.isEmpty;
    case 'length':
      return obj.length;
    default:
      return null;
  }
}
