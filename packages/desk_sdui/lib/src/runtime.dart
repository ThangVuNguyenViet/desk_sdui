import 'package:crypto/crypto.dart';
import 'package:desk_sdui_annotation/desk_sdui_annotation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'loader/asset_bundle_ir_fetcher.dart';

/// Describes a single parameter of a @Screen function.
class InputBinding<T> {
  const InputBinding({required this.name, required this.read});
  final String name;
  final T Function(Object? input) read;
}

/// A method exposed to the IR (e.g. `vm.removeItem`).
class MethodBinding {
  const MethodBinding({required this.name, required this.invoke});
  final String name;
  final Function invoke;
}

/// A reactive source exposed to the IR (e.g. `vm.showPromoCode` of type
/// `Signal<bool>`). The runtime subscribes via `ListenableBuilder`.
class ReactiveBinding {
  const ReactiveBinding({required this.path, required this.read});
  final List<String> path;
  final ValueListenable<Object?> Function(Map<String, Object?> input) read;
}

/// Static binding for a @Screen — emitted by codegen.
class ScreenBinding {
  const ScreenBinding({
    required this.name,
    required this.ir,
    required this.inputs,
    this.methods = const [],
    this.reactives = const [],
  });
  final String name;
  final IrTree ir;
  final List<InputBinding<Object?>> inputs;
  final List<MethodBinding> methods;
  final List<ReactiveBinding> reactives;
}

typedef WidgetBuilderFn = Widget Function(
  BuildContext context,
  Map<String, Object?> args,
);

abstract class IrFetcher {
  Future<List<int>> fetch(String name);
}

class Runtime {
  Runtime({
    this.fetcher,
    this.assetBundle,
    this.errorBuilder,
    this.loadingBuilder,
  });

  final IrFetcher? fetcher;
  final AssetBundle? assetBundle;
  final Widget Function(BuildContext, Object error)? errorBuilder;
  final Widget Function(BuildContext)? loadingBuilder;

  final Map<String, ScreenBinding> _screens = {};
  final Map<String, WidgetBuilderFn> _widgets = {};
  final Map<String, Function> _fns = {};
  final Map<String, IrTree> _cache = {};

  void registerScreen(ScreenBinding binding) {
    _screens[binding.name] = binding;
  }

  void registerWidget(String name, WidgetBuilderFn builder) {
    _widgets[name] = builder;
  }

  void registerFn(String name, Function fn) {
    _fns[name] = fn;
  }

  ScreenBinding? screenFor(String name) => _screens[name];
  WidgetBuilderFn? widgetFor(String name) => _widgets[name];
  Function? fnFor(String name) => _fns[name];

  Future<IrTree> load(String name) async {
    if (fetcher != null) {
      try {
        final bytes = await fetcher!.fetch(name);
        return _decodeAndCache(name, bytes);
      } on Exception {
        // fall through
      }
    }
    if (assetBundle != null) {
      try {
        final abFetcher = AssetBundleIrFetcher(bundle: assetBundle!);
        final bytes = await abFetcher.fetch(name);
        return _decodeAndCache(name, bytes);
      } on Exception {
        // fall through
      }
    }
    final binding = screenFor(name);
    if (binding != null) return binding.ir;
    throw StateError('No source produced IR for "$name"');
  }

  IrTree _decodeAndCache(String name, List<int> bytes) {
    final hash = sha1.convert(bytes).toString();
    final key = '$name:$hash';
    final hit = _cache[key];
    if (hit != null) return hit;
    final tree = const JsonIrCodec().decodeBytes(bytes);
    if (tree.version > currentIrVersion) {
      throw StateError(
        'IR v${tree.version} exceeds runtime ($currentIrVersion)',
      );
    }
    _cache[key] = tree;
    return tree;
  }
}
