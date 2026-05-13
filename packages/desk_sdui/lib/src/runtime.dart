import 'dart:typed_data';

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
    this.methodRefs = const {},
    this.reactives = const [],
  });
  final String name;
  final IrTree ir;
  final List<InputBinding<Object?>> inputs;

  /// Method references indexed by input name.
  /// e.g. `{'vm': ['increment', 'decrement']}`
  final Map<String, List<String>> methodRefs;
  final List<ReactiveBinding> reactives;

  /// Returns the method names referenced for a given input slot.
  List<String> referencedMethodsFor(String inputName) =>
      methodRefs[inputName] ?? const [];
}

typedef WidgetBuilderFn = Widget Function(
  BuildContext context,
  Map<String, Object?> args,
);

// ---------------------------------------------------------------------------
// New codegen-driven registry typedefs (Task 1 — Phase 3 v2)
// ---------------------------------------------------------------------------

/// Builds a widget from a resolved args map. No BuildContext needed.
///
/// If the IR ctor invocation carried generic type args (e.g.
/// `MyWidget<MyType>(...)`), they appear in `args` under the reserved key
/// `__typeArgs__` as a `List<String>` of simple type names (no library URIs,
/// no nested generics). Builders that don't care about generics may ignore
/// this key.
typedef SduiWidgetBuilder = Widget Function(Map<String, Object?> args);

/// Handles a method call: `receiver.name(args)`.
///
/// [args] is a named-param map. Positional parameters are keyed by their
/// declaration-order index as `'arg0'`, `'arg1'`, etc.
typedef SduiMethodHandler = Object? Function(
    Object? receiver, Map<String, Object?> args);

/// Resolves a getter call `receiver.name` to a value. Registered against the
/// qualified handler name, e.g. `'String.isNotEmpty'`.
typedef SduiGetterHandler = Object? Function(Object? receiver);

/// Mutates a field on `receiver` by writing `value`. Registered against the
/// qualified handler name, e.g. `'Vm.count'`. Codegen emits one per
/// non-final, non-late, non-static, public instance field of each
/// `@Register`-ed type.
typedef SduiSetterHandler = void Function(Object? receiver, Object? value);

/// Handles a subscript access: `receiver[key]`.
typedef SduiSubscriptHandler = Object? Function(Object? receiver, Object? key);

/// Builds a value-type instance from a named-param map.
///
/// Named parameters are keyed by their Dart name. Positional parameters are
/// keyed by their declaration-order index as `'arg0'`, `'arg1'`, etc.
///
/// If the IR ctor invocation carried generic type args (e.g. `List<MyType>()`),
/// they appear in `args` under the reserved key `__typeArgs__` as a
/// `List<String>` of simple type names. Type args are erased to simple names
/// (no library URIs, no nested generics). Builders that don't care about
/// generics may ignore this key.
typedef SduiValueBuilder = Object? Function(Map<String, Object?> args);

/// Handles a free function call.
///
/// [args] is a named-param map. Positional parameters are keyed as `'arg0'`,
/// `'arg1'`, etc.
typedef SduiFunctionHandler = Object? Function(Map<String, Object?> args);

abstract class IrFetcher {
  Future<Uint8List> fetch(String name);
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
  final Map<String, SduiGetterHandler> _getters = {};
  final Map<String, SduiSetterHandler> _setters = {};
  final Map<String, SduiSubscriptHandler> _subscripts = {};
  final Map<String, SduiValueBuilder> _valueBuilders = {};
  final Map<String, SduiFunctionHandler> _functions = {};

  // Unified callable registry — everything keyed by "TypeName.MemberName"
  // (or just "TypeName" for unnamed ctors), with optional receiver via $this.
  final Map<String, Function> _callables = {};

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

  void registerGetter(String name, SduiGetterHandler handler) =>
      _getters[name] = handler;

  void registerSetter(String name, SduiSetterHandler handler) =>
      _setters[name] = handler;

  void registerSubscript(String name, SduiSubscriptHandler handler) =>
      _subscripts[name] = handler;

  void registerValueBuilder(String name, SduiValueBuilder builder) =>
      _valueBuilders[name] = builder;

  void registerFunction(String name, SduiFunctionHandler handler) =>
      _functions[name] = handler;

  void registerFn(String name, Function fn) {
    _fns[name] = fn;
  }

  // ---------------------------------------------------------------------------
  // Type-check registry (for sealed-type pattern matching in @Screen bodies)
  // ---------------------------------------------------------------------------

  final Map<String, bool Function(Object?)> _typeChecks = {};

  /// Registers a predicate that returns true iff [value] is an instance of the
  /// Dart type identified by [name]. Generated by codegen for sealed classes
  /// referenced in @Screen bodies.
  void registerTypeCheck(String name, bool Function(Object?) check) =>
      _typeChecks[name] = check;

  bool checkType(String name, Object? value) {
    final pred = _typeChecks[name];
    if (pred == null) {
      throw StateError(
        'No type check registered for "$name". '
        'Sealed types used in switch expressions must be registered '
        'via the @Register annotation on the sealed parent.',
      );
    }
    return pred(value);
  }

  /// Unified registration entry point — everything is a callable keyed by
  /// `"TypeName.MemberName"` (or just `"TypeName"` for unnamed ctors).
  void register(String name, Function fn) {
    _callables[name] = fn;
  }

  /// Look up a callable by its unified key.
  Function? callableFor(String name) => _callables[name];

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

  /// Returns the registered [SduiGetterHandler] for [name], or null if not
  /// registered. Used by resolve.dart to dispatch [GetterNode].
  SduiGetterHandler? resolveGetter(String name) => _getters[name];

  /// Returns the registered [SduiSetterHandler] for [name], or null if not
  /// registered. Used by resolve.dart to dispatch [SetterCallNode].
  SduiSetterHandler? resolveSetter(String name) => _setters[name];

  /// Returns the registered [SduiValueBuilder] for [name], or null if not
  /// registered. Used by resolve.dart to dispatch [ValueCtorNode].
  SduiValueBuilder? resolveValueBuilder(String name) => _valueBuilders[name];

  Object? invokeMethod(
          String name, Object? receiver, Map<String, Object?> args) =>
      _methods[name]?.call(receiver, args);

  Object? invokeGetter(String name, Object? receiver) =>
      _getters[name]?.call(receiver);

  void invokeSetter(String name, Object? receiver, Object? value) {
    final h = _setters[name];
    if (h == null) {
      throw StateError(
        'No setter registered for "$name" (receiver: ${receiver?.runtimeType}). '
        'If this is a registered type, verify the field is non-final and public.',
      );
    }
    h(receiver, value);
  }

  Object? invokeSubscript(String name, Object? receiver, Object? key) =>
      _subscripts[name]?.call(receiver, key);
  Object? invokeValueBuilder(String name, Map<String, Object?> args) =>
      _valueBuilders[name]?.call(args);
  Object? invokeFunction(String name, Map<String, Object?> args) =>
      _functions[name]?.call(args);

  bool hasFunction(String name) => _functions.containsKey(name);

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

  IrTree _decodeAndCache(String name, Uint8List bytes) {
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
