// ignore_for_file: deprecated_member_use
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// Deduped sets of external type references found inside a single @Screen body.
///
/// "External" means not a parameter of the @Screen function itself, and not a
/// local introduced by a `for`/lambda inside the screen body.
///
/// Deduplication is by element identity: multiple call sites that use `Column`
/// contribute a single `ClassElement` for `Column`, not one per call site.
class CollectedTypes {
  CollectedTypes({
    Set<ClassElement>? widgets,
    Set<ClassElement>? valueTypes,
    Set<Element>? constants,
    Set<MethodElement>? methods,
    Set<DartType>? subscriptables,
    Set<TopLevelFunctionElement>? functions,
    Set<String>? extraLibraryUris,
    List<String>? notes,
    Map<String, Set<String>>? genericCtorTypeArgs,
  })  : widgets = widgets ?? {},
        valueTypes = valueTypes ?? {},
        constants = constants ?? {},
        methods = methods ?? {},
        subscriptables = subscriptables ?? {},
        functions = functions ?? {},
        extraLibraryUris = extraLibraryUris ?? {},
        notes = notes ?? [],
        genericCtorTypeArgs = genericCtorTypeArgs ?? {};

  /// Widget subclasses constructed in the screen body (e.g. `Column`, `Text`).
  final Set<ClassElement> widgets;

  /// Non-Widget value types constructed in the screen body
  /// (e.g. `EdgeInsets`, `BoxDecoration`).
  final Set<ClassElement> valueTypes;

  /// Static const/getter references whose prefix is a class
  /// (e.g. `Icons.menu`, `Colors.white`).
  /// Elements are `FieldElement` or `PropertyAccessorElement`.
  final Set<Element> constants;

  /// Instance method references used on a receiver with a known static type
  /// (e.g. `String.toUpperCase`, `num.toStringAsFixed`).
  final Set<MethodElement> methods;

  /// Receiver types whose `[]` operator was used
  /// (e.g. `MaterialColor`, `Map<K,V>`, `List<E>`).
  final Set<DartType> subscriptables;

  /// Top-level function references (e.g. `min`, `max`).
  final Set<TopLevelFunctionElement> functions;

  /// Extra library URIs that must be imported in the generated file so that
  /// types referenced in registration closures (e.g. `DragStartBehavior`,
  /// `HitTestBehavior`, `ViewPadding`, `ColorSpace`) are in scope.
  ///
  /// `dart:core` and the screen's own library are excluded. Duplicates are
  /// deduplicated by the [Set].
  final Set<String> extraLibraryUris;

  /// Optional notes/comments to emit in generated registration blocks
  /// (e.g. elided static-const warnings).
  final List<String> notes;

  /// Maps a constructor simple-name (e.g. `'List'`, `'ValueNotifier'`) to the
  /// set of explicit type-arg names used with it in screen bodies.
  ///
  /// E.g. if a screen body contains `List<MyType>()` and `List<String>()`,
  /// this map will contain `{'List': {'MyType', 'String'}}`.
  ///
  /// Only populated by [collectTypes] (the screen-body visitor). The
  /// annotation-based collector doesn't walk call-site type args.
  final Map<String, Set<String>> genericCtorTypeArgs;

  /// Merges [other] into this (in-place union).
  void unionWith(CollectedTypes other) {
    widgets.addAll(other.widgets);
    valueTypes.addAll(other.valueTypes);
    constants.addAll(other.constants);
    methods.addAll(other.methods);
    subscriptables.addAll(other.subscriptables);
    functions.addAll(other.functions);
    extraLibraryUris.addAll(other.extraLibraryUris);
    notes.addAll(other.notes);
    for (final entry in other.genericCtorTypeArgs.entries) {
      genericCtorTypeArgs.putIfAbsent(entry.key, Set.new).addAll(entry.value);
    }
  }
}

/// Walk [screen]'s body and return the deduped set of external type references.
///
/// [screen] must be a resolved [FunctionDeclaration] (i.e. obtained from an
/// analysis session, not from `parseString`). References that originate from
/// the function's own parameters or from for-loop / lambda-introduced locals
/// are skipped — those are binding-layer concerns, not external Flutter types.
CollectedTypes collectTypes(FunctionDeclaration screen) {
  final visitor = _TypeVisitor(screen);
  screen.accept(visitor);
  return visitor.collected;
}

/// Collect types from a `@Register([T1, T2, ...])` annotation on
/// [annotated].
///
/// Each `Type` literal in the `types` list is extracted via
/// [DartObject.toTypeValue] → [DartType] → [ClassElement]. Types that are
/// Widget subclasses are placed in [CollectedTypes.widgets]; all others in
/// [CollectedTypes.valueTypes].
///
/// After the explicit list is processed, the following auto-discovery rules
/// are applied:
/// 1. **Enum ctor-param discovery:** for every collected widget / value-type,
///    walk its public constructors and collect enum-typed parameters; the
///    enum's constants are added to [CollectedTypes.constants].
/// 2. **Static-const discovery:** for every collected class, collect its
///    public static const fields into [CollectedTypes.constants]. Classes
///    with more than 200 such fields are skipped with a note.
/// 3. **Sealed-subtype discovery:** for every collected widget / value-type,
///    walk its constructor parameters; if a parameter type is a sealed class,
///    all of its subtypes in the same library are collected.
///
/// Returns an empty [CollectedTypes] when the annotation has no elements or
/// any element cannot be resolved to a [ClassElement].
CollectedTypes collectTypesFromAnnotation(
  Element annotated,
  DartObject annotation,
) {
  final collected = CollectedTypes();
  final typesField = annotation.getField('types');
  final typeList = typesField?.toListValue();
  if (typeList == null) return collected;

  for (final typeObj in typeList) {
    final dartType = typeObj.toTypeValue();
    if (dartType == null) continue;
    final element = dartType.element;
    if (element is! ClassElement) continue;
    if (_isWidgetSubtypeStatic(element)) {
      collected.widgets.add(element);
    } else {
      collected.valueTypes.add(element);
    }
  }

  // Auto-discovery passes (finite, bounded, idempotent).
  _autoDiscoverEnums(collected);
  _autoDiscoverStaticConsts(collected);
  _autoDiscoverSealedSubtypes(collected);

  return collected;
}

/// Static helper: true if [cls] is a subtype of Flutter's `Widget`.
/// Mirrors the instance method in [_TypeVisitor] for use outside that class.
bool _isWidgetSubtypeStatic(ClassElement cls) {
  if (cls.name == 'Widget') return true;
  for (final supertype in cls.allSupertypes) {
    if (supertype.element.name == 'Widget') return true;
  }
  return false;
}

// ---------------------------------------------------------------------------
// Implementation
// ---------------------------------------------------------------------------

class _TypeVisitor extends RecursiveAstVisitor<void> {
  _TypeVisitor(this._screen) {
    // Collect the screen's own parameter names so we can skip receiver refs
    // that originate from bindings (controller.someMethod, etc.).
    final params = _screen.functionExpression.parameters?.parameters;
    if (params != null) {
      for (final p in params) {
        final name = p.name?.lexeme;
        if (name != null) _screenParamNames.add(name);
      }
    }
    // Record the screen's own library URI so we can exclude it from extras.
    _ownLibraryUri = _screen.declaredFragment?.element.library.firstFragment.source.uri.toString();
  }

  final FunctionDeclaration _screen;
  final _screenParamNames = <String>{};
  String? _ownLibraryUri;

  final collected = CollectedTypes();

  // Track locals introduced by for-loops / lambdas so we can skip them.
  final _localNames = <String>{};

  // -------------------------------------------------------------------------
  // Instance creation: Widget or value type
  // -------------------------------------------------------------------------

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final ctorElement = node.constructorName.element;
    final enclosing = ctorElement?.enclosingElement;
    if (enclosing is ClassElement) {
      if (_isWidgetSubtype(enclosing)) {
        collected.widgets.add(enclosing);
      } else {
        collected.valueTypes.add(enclosing);
      }
      // Collect library URIs for the class itself and all its constructor
      // parameter types so the generated file has the needed imports.
      _recordElementLibrary(enclosing);
      if (ctorElement != null) {
        _recordConstructorParamLibraries(ctorElement);
      }

      // Record explicit type args (e.g. `List<MyType>()` → {'List': {'MyType'}}).
      final typeArgList = node.constructorName.type.typeArguments;
      if (typeArgList != null && typeArgList.arguments.isNotEmpty) {
        final className = enclosing.name ?? '';
        if (className.isNotEmpty) {
          final argNames = typeArgList.arguments.map((t) {
            if (t is NamedType) return t.name.lexeme;
            return t.toSource();
          }).toSet();
          collected.genericCtorTypeArgs
              .putIfAbsent(className, Set.new)
              .addAll(argNames);
        }
      }
    }
    super.visitInstanceCreationExpression(node);
  }

  // -------------------------------------------------------------------------
  // Method invocations: instance methods on typed receivers
  // -------------------------------------------------------------------------

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target;

    if (target == null) {
      // No receiver — could be a top-level function call.
      final methodElement = node.methodName.element;
      if (methodElement is TopLevelFunctionElement) {
        collected.functions.add(methodElement);
      }
      super.visitMethodInvocation(node);
      return;
    }

    // Collect the instance method so the SDUI runtime can register it.
    // We do NOT skip @Screen parameter receivers here: calling .toUpperCase()
    // on a String param still requires String.toUpperCase to be registered.
    // The only calls we skip are closure-lowered bindings (e.g.
    // `() => controller.doSomething()`), which the closure lowerer handles
    // separately and which appear as FunctionExpression nodes, not bare
    // MethodInvocation nodes.
    final methodElement = node.methodName.element;
    if (methodElement is MethodElement) {
      collected.methods.add(methodElement);
      // Record library URIs for method param types.
      _recordElementLibrary(methodElement.enclosingElement!);
      for (final param in methodElement.formalParameters) {
        _recordDartTypeLibraries(param.type);
      }
    }

    super.visitMethodInvocation(node);
  }

  // -------------------------------------------------------------------------
  // Static const / getter refs: Icons.menu, Colors.white, etc.
  // -------------------------------------------------------------------------

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    final prefixElement = node.prefix.element;
    // Interested when the prefix resolves to a class or enum (static access).
    // Both ClassElement and EnumElement are subtypes of InterfaceElement.
    if (prefixElement is InterfaceElement) {
      final propElement = node.identifier.element;
      if (propElement != null) {
        collected.constants.add(propElement);
        _recordElementLibrary(prefixElement);
        _recordElementLibrary(propElement);
      }
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final target = node.target;
    if (target is SimpleIdentifier) {
      final targetElement = target.element;
      if (targetElement is InterfaceElement) {
        final propElement = node.propertyName.element;
        if (propElement != null) {
          collected.constants.add(propElement);
          _recordElementLibrary(targetElement);
          _recordElementLibrary(propElement);
        }
      }
    }
    super.visitPropertyAccess(node);
  }

  // -------------------------------------------------------------------------
  // Index expressions: Colors.grey[300], list[0], etc.
  // -------------------------------------------------------------------------

  @override
  void visitIndexExpression(IndexExpression node) {
    final type = node.target?.staticType;
    if (type != null) {
      collected.subscriptables.add(type);
    }
    super.visitIndexExpression(node);
  }

  // -------------------------------------------------------------------------
  // For-loop locals — track so we can skip them as receivers
  // -------------------------------------------------------------------------

  @override
  void visitForElement(ForElement node) {
    final parts = node.forLoopParts;
    if (parts is ForEachPartsWithDeclaration) {
      final name = parts.loopVariable.name.lexeme;
      _localNames.add(name);
      super.visitForElement(node);
      _localNames.remove(name);
      return;
    }
    super.visitForElement(node);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // Collect lambda param names as locals.
    final added = <String>[];
    final params = node.parameters?.parameters;
    if (params != null) {
      for (final p in params) {
        final name = p.name?.lexeme;
        if (name != null) {
          _localNames.add(name);
          added.add(name);
        }
      }
    }
    super.visitFunctionExpression(node);
    for (final n in added) {
      _localNames.remove(n);
    }
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  /// True if [cls] is a subtype of Flutter's `Widget`.
  ///
  /// Uses [InterfaceElement.allSupertypes] for a flat O(n) walk instead of
  /// recursive supertype traversal.
  bool _isWidgetSubtype(ClassElement cls) {
    if (cls.name == 'Widget') return true;
    // allSupertypes includes all transitive supertypes (super, interfaces,
    // mixins) in linearisation order — ideal for Widget detection.
    for (final supertype in cls.allSupertypes) {
      if (supertype.element.name == 'Widget') return true;
    }
    return false;
  }

  /// Records the library URI for [element] into [CollectedTypes.extraLibraryUris],
  /// skipping `dart:core` and the screen's own library.
  void _recordElementLibrary(Element element) {
    final uri = element.library?.firstFragment.source.uri.toString();
    if (uri == null) return;
    if (uri == 'dart:core') return;
    if (uri == _ownLibraryUri) return;
    collected.extraLibraryUris.add(uri);
  }

  /// Records library URIs for all parameter types declared by [ctor].
  ///
  /// This covers types like `DragStartBehavior`, `HitTestBehavior`, etc. that
  /// are referenced in the emitted registration closure for a constructor but
  /// aren't the constructor's own class.
  void _recordConstructorParamLibraries(ConstructorElement ctor) {
    for (final param in ctor.formalParameters) {
      _recordDartTypeLibraries(param.type);
    }
  }

  /// Recursively records library URIs for [type] and its type arguments.
  void _recordDartTypeLibraries(DartType type) {
    // Unwrap extension types to their representation type so the backing
    // type's library is recorded (e.g. ChefView → Map<String, Object?>).
    final unwrapped = _unwrapExtensionType(type);
    if (unwrapped != type) {
      _recordDartTypeLibraries(unwrapped);
      return;
    }
    final element = type.element;
    if (element != null) {
      _recordElementLibrary(element);
    }
    if (type is InterfaceType) {
      for (final arg in type.typeArguments) {
        _recordDartTypeLibraries(arg);
      }
    }
    // Record library URIs for record field types.
    if (type is RecordType) {
      for (final field in type.positionalFields) {
        _recordDartTypeLibraries(field.type);
      }
      for (final field in type.namedFields) {
        _recordDartTypeLibraries(field.type);
      }
    }
  }

  /// If [t] is an extension type, returns its representation type; otherwise
  /// returns [t] unchanged. This makes extension-type-backed parameters
  /// transparent to the rest of the type collector.
  DartType _unwrapExtensionType(DartType t) {
    if (t is InterfaceType && t.element is ExtensionTypeElement) {
      return (t.element as ExtensionTypeElement).representation.type;
    }
    return t;
  }
}

// ---------------------------------------------------------------------------
// Auto-discovery helpers (used by collectTypesFromAnnotation)
// ---------------------------------------------------------------------------

/// Discovers enum types referenced as constructor parameter types of every
/// collected widget / value-type, and adds the enum constants to
/// [collected.constants].
void _autoDiscoverEnums(CollectedTypes collected) {
  final toProcess = <ClassElement>[...collected.widgets, ...collected.valueTypes];
  final visited = <InterfaceElement>{};

  for (final cls in toProcess) {
    if (!visited.add(cls)) continue;
    for (final ctor in cls.constructors.where((c) => !c.isPrivate)) {
      for (final param in ctor.formalParameters) {
        _collectEnumTypes(param.type, collected, visited);
      }
    }
  }
}

/// Recursively walks [type] (unwrapping nullability, type arguments, records
/// and extension types) and adds every [EnumElement] encountered to
/// [collected.constants].
void _collectEnumTypes(
  DartType type,
  CollectedTypes collected,
  Set<InterfaceElement> visited,
) {
  final unwrapped = _unwrapExtensionTypeForDiscovery(type);
  if (unwrapped != type) {
    _collectEnumTypes(unwrapped, collected, visited);
    return;
  }

  if (type is InterfaceType) {
    final element = type.element;
    if (element is EnumElement && visited.add(element)) {
      for (final field in element.fields.where((f) => f.isEnumConstant && !f.isPrivate)) {
        collected.constants.add(field);
      }
    }
    for (final arg in type.typeArguments) {
      _collectEnumTypes(arg, collected, visited);
    }
  } else if (type is RecordType) {
    for (final field in type.positionalFields) {
      _collectEnumTypes(field.type, collected, visited);
    }
    for (final field in type.namedFields) {
      _collectEnumTypes(field.type, collected, visited);
    }
  }
}

/// Discovers public static const fields of every collected class and adds
/// them to [collected.constants].
///
/// Classes with more than 200 static const fields are skipped and a note is
/// added to [collected.notes] instead.
void _autoDiscoverStaticConsts(CollectedTypes collected) {
  final toProcess = <ClassElement>[...collected.widgets, ...collected.valueTypes];

  for (final cls in toProcess) {
    final fields = cls.fields.where((f) => f.isStatic && f.isConst && !f.isPrivate);
    final count = fields.length;
    if (count > 200) {
      collected.notes.add(
        '// elided ${cls.name}: $count static consts (over cap; use '
        '@Register([${cls.name}.fieldName, ...]) for explicit subset)',
      );
      continue;
    }
    for (final field in fields) {
      collected.constants.add(field);
    }
  }
}

/// Discovers sealed subtypes of every collected sealed class (or sealed
/// parameter type of a collected class) and adds them to the appropriate
/// bucket ([CollectedTypes.widgets] or [CollectedTypes.valueTypes]).
void _autoDiscoverSealedSubtypes(CollectedTypes collected) {
  final toProcess = <ClassElement>[...collected.widgets, ...collected.valueTypes];
  final visited = <InterfaceElement>{};

  for (final cls in toProcess) {
    if (!visited.add(cls)) continue;

    // If the class itself is sealed, discover its subtypes.
    if (cls.isSealed) {
      _collectSealedSubtypes(cls, collected, visited);
    }

    // Walk constructor parameters looking for sealed types.
    for (final ctor in cls.constructors.where((c) => !c.isPrivate)) {
      for (final param in ctor.formalParameters) {
        _collectSealedTypes(param.type, collected, visited);
      }
    }
  }
}

/// Recursively walks [type] and discovers sealed interface types, then
/// collects all their subtypes in the same library.
void _collectSealedTypes(
  DartType type,
  CollectedTypes collected,
  Set<InterfaceElement> visited,
) {
  final unwrapped = _unwrapExtensionTypeForDiscovery(type);
  if (unwrapped != type) {
    _collectSealedTypes(unwrapped, collected, visited);
    return;
  }

  if (type is InterfaceType) {
    final element = type.element;
    if (element is ClassElement && element.isSealed && visited.add(element)) {
      _collectSealedSubtypes(element, collected, visited);
    }
    for (final arg in type.typeArguments) {
      _collectSealedTypes(arg, collected, visited);
    }
  } else if (type is RecordType) {
    for (final field in type.positionalFields) {
      _collectSealedTypes(field.type, collected, visited);
    }
    for (final field in type.namedFields) {
      _collectSealedTypes(field.type, collected, visited);
    }
  }
}

/// Collects all subtypes of [sealedClass] that live in the same library and
/// adds them to [collected] as widgets or value-types.
void _collectSealedSubtypes(
  ClassElement sealedClass,
  CollectedTypes collected,
  Set<InterfaceElement> visited,
) {
  final library = sealedClass.library;

  for (final classElement in library.classes) {
    if (classElement == sealedClass) continue;
    if (_isSubtypeOf(classElement, sealedClass) && visited.add(classElement)) {
      if (_isWidgetSubtypeStatic(classElement)) {
        collected.widgets.add(classElement);
      } else {
        collected.valueTypes.add(classElement);
      }
    }
  }

  for (final enumElement in library.enums) {
    if (_isSubtypeOf(enumElement, sealedClass) && visited.add(enumElement)) {
      for (final field in enumElement.fields.where((f) => f.isEnumConstant && !f.isPrivate)) {
        collected.constants.add(field);
      }
    }
  }
}

/// True if [candidate] is the same as, or a subtype of, [target].
bool _isSubtypeOf(InterfaceElement candidate, InterfaceElement target) {
  if (candidate == target) return true;
  for (final supertype in candidate.allSupertypes) {
    if (supertype.element == target) return true;
  }
  return false;
}

/// If [t] is an extension type, returns its representation type; otherwise
/// returns [t] unchanged.
DartType _unwrapExtensionTypeForDiscovery(DartType t) {
  if (t is InterfaceType && t.element is ExtensionTypeElement) {
    return (t.element as ExtensionTypeElement).representation.type;
  }
  return t;
}
