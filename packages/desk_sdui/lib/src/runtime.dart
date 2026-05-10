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

// ---------------------------------------------------------------------------
// New codegen-driven registry typedefs (Task 1 — Phase 3 v2)
// ---------------------------------------------------------------------------

/// Builds a widget from a resolved args map. No BuildContext needed.
typedef SduiWidgetBuilder = Widget Function(Map<String, Object?> args);

/// Handles a method call: `receiver.name(args)`.
typedef SduiMethodHandler = Object? Function(
    Object? receiver, List<Object?> args);

/// Handles a subscript access: `receiver[key]`.
typedef SduiSubscriptHandler = Object? Function(Object? receiver, Object? key);

/// Builds a value-type instance from positional args, e.g. EdgeInsets.all.
typedef SduiValueBuilder = Object? Function(List<Object?> args);

/// Handles a free function call.
typedef SduiFunctionHandler = Object? Function(List<Object?> args);

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
  // Legacy widget map — keyed by name, builder receives (BuildContext, args).
  // Still used by resolve.dart._buildWidget; populated via registerWidget shim.
  final Map<String, WidgetBuilderFn> _widgets = {};
  final Map<String, Function> _fns = {};
  final Map<String, IrTree> _cache = {};

  // ---------------------------------------------------------------------------
  // New codegen-driven registries (Task 1 — Phase 3 v2)
  // ---------------------------------------------------------------------------
  final Map<String, SduiWidgetBuilder> _sduiWidgets = {};
  final Map<String, Object?> _constants = {};
  final Map<String, SduiMethodHandler> _methods = {};
  final Map<String, SduiSubscriptHandler> _subscripts = {};
  final Map<String, SduiValueBuilder> _valueBuilders = {};
  final Map<String, SduiFunctionHandler> _functions = {};

  void registerScreen(ScreenBinding binding) {
    _screens[binding.name] = binding;
  }

  /// Registers a widget builder using the legacy [WidgetBuilderFn] signature
  /// (receives [BuildContext] + args map). Used by the existing resolve pipeline.
  void registerWidgetWithContext(String name, WidgetBuilderFn builder) {
    _widgets[name] = builder;
  }

  /// Registers a widget builder using the new [SduiWidgetBuilder] signature
  /// (args-only, no [BuildContext]). Used by codegen-emitted registration
  /// functions. Also installs a shim into [_widgets] so the existing
  /// resolve.dart pipeline can find it via [widgetFor].
  void registerWidget(String name, SduiWidgetBuilder builder) {
    _sduiWidgets[name] = builder;
    // Shim: wrap as WidgetBuilderFn so widgetFor() / resolve.dart still works.
    _widgets[name] = (_, args) => builder(args);
  }

  void registerConstant(String name, Object? value) =>
      _constants[name] = value;

  void registerMethod(String name, SduiMethodHandler handler) =>
      _methods[name] = handler;

  void registerSubscript(String name, SduiSubscriptHandler handler) =>
      _subscripts[name] = handler;

  void registerValueBuilder(String name, SduiValueBuilder builder) =>
      _valueBuilders[name] = builder;

  void registerFunction(String name, SduiFunctionHandler handler) =>
      _functions[name] = handler;

  void registerFn(String name, Function fn) {
    _fns[name] = fn;
  }

  ScreenBinding? screenFor(String name) => _screens[name];
  WidgetBuilderFn? widgetFor(String name) => _widgets[name];
  Function? fnFor(String name) => _fns[name];

  // ---------------------------------------------------------------------------
  // New resolve/invoke accessors (Task 1 — Phase 3 v2)
  // ---------------------------------------------------------------------------

  SduiWidgetBuilder? resolveWidget(String name) => _sduiWidgets[name];
  Object? resolveConstant(String name) => _constants[name];

  /// Returns the registered [SduiMethodHandler] for [name], or null if not
  /// registered. Used by resolve.dart to dispatch [MethodCallNode].
  SduiMethodHandler? resolveMethodHandler(String name) => _methods[name];

  /// Returns the registered [SduiValueBuilder] for [name], or null if not
  /// registered. Used by resolve.dart to dispatch [ValueCtorNode].
  SduiValueBuilder? resolveValueBuilder(String name) => _valueBuilders[name];

  Object? invokeMethod(String name, Object? receiver, List<Object?> args) =>
      _methods[name]?.call(receiver, args);
  Object? invokeSubscript(String name, Object? receiver, Object? key) =>
      _subscripts[name]?.call(receiver, key);
  Object? invokeValueBuilder(String name, List<Object?> args) =>
      _valueBuilders[name]?.call(args);
  Object? invokeFunction(String name, List<Object?> args) =>
      _functions[name]?.call(args);

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
