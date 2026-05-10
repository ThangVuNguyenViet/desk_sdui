/// Tests for [RegistrationEmitter] — verifies that each `emit*` method
/// produces the correct `rt.register*` call from a real analyzer element.
///
/// We resolve Flutter type elements using the same `resolveScreen` helper
/// pattern established in `type_collector_test.dart`: write a temp Dart file
/// into the `desk_sdui_demo/lib` directory (which has a valid Flutter context),
/// resolve with `resolveFile2`, then extract elements from the resolved unit.
// ignore_for_file: deprecated_member_use
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:desk_sdui_generator/src/registration_emitter.dart';
import 'package:desk_sdui_generator/src/type_collector.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

const _demoPackageRoot =
    '/Users/vietthangvunguyen/Workspace/dart_desk_workspace/desk_sdui/packages/desk_sdui_demo';

/// Resolve a Dart source string using the desk_sdui_demo analysis context
/// (which has Flutter available) and return the [ResolvedUnitResult].
Future<ResolvedUnitResult> _resolveSource(String source) async {
  final dir = Directory(p.join(_demoPackageRoot, 'lib'));
  final tempFile = File(
    p.join(
      dir.path,
      '_emitter_temp_${DateTime.now().microsecondsSinceEpoch}.dart',
    ),
  );
  tempFile.writeAsStringSync(source);
  try {
    final result = await resolveFile2(path: tempFile.path);
    if (result is! ResolvedUnitResult) {
      throw StateError('resolveFile2 returned ${result.runtimeType}');
    }
    return result;
  } finally {
    if (tempFile.existsSync()) tempFile.deleteSync();
  }
}

/// Resolve the source and extract the first top-level [FunctionDeclaration]
/// (used as the screen body for the type collector helper).
Future<FunctionDeclaration> _resolveScreen(String source) async {
  final result = await _resolveSource(source);
  return result.unit.declarations.whereType<FunctionDeclaration>().first;
}

/// Get the [ClassElement] for [name] from [result].
/// Searches all imported libraries (direct only — deep search is slow).
ClassElement _classElement(ResolvedUnitResult result, String name) {
  final lib = result.libraryElement;
  for (final imp in lib.importedLibraries) {
    final el = imp.exportNamespace.get(name);
    if (el is ClassElement) return el;
  }
  throw StateError('ClassElement "$name" not found in resolved unit');
}

/// Get the [InterfaceElement] for [name] — covers both [ClassElement] and
/// [EnumElement] (which is an [InterfaceElement] but not a [ClassElement]).
InterfaceElement _interfaceElement(ResolvedUnitResult result, String name) {
  final lib = result.libraryElement;
  for (final imp in lib.importedLibraries) {
    final el = imp.exportNamespace.get(name);
    if (el is InterfaceElement) return el;
  }
  throw StateError('InterfaceElement "$name" not found in resolved unit');
}

/// Get the [MethodElement] named [methodName] on class [className].
MethodElement _methodElement(
  ResolvedUnitResult result,
  String className,
  String methodName,
) {
  final cls = _classElement(result, className);
  for (final m in cls.methods) {
    if (m.name == methodName) return m;
  }
  throw StateError('MethodElement "$className.$methodName" not found');
}

/// Get the named [ConstructorElement] for `ClassName.ctorName`, or the unnamed
/// ctor when [ctorName] is empty.
ConstructorElement _ctorElement(
  ResolvedUnitResult result,
  String className,
  String ctorName,
) {
  final cls = _classElement(result, className);
  for (final c in cls.constructors) {
    if (c.name == ctorName) return c;
  }
  throw StateError('Constructor "$className.$ctorName" not found');
}

/// Get the static [Element] for `InterfaceName.memberName` (field / getter /
/// enum constant). Works for both class and enum types.
Element _staticMemberElement(
  ResolvedUnitResult result,
  String interfaceName,
  String memberName,
) {
  final iface = _interfaceElement(result, interfaceName);
  for (final f in iface.fields) {
    if (f.name == memberName) return f;
  }
  for (final a in iface.accessors) {
    if (a.name == memberName) return a;
  }
  throw StateError(
    'Static member "$interfaceName.$memberName" not found',
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  final emitter = RegistrationEmitter();

  // The source we resolve for most tests — needs material.dart available.
  const materialSource = '''
import 'package:flutter/material.dart';
void _dummy() {}
''';

  late ResolvedUnitResult materialResult;

  setUpAll(() async {
    materialResult = await _resolveSource(materialSource);
  });

  // -------------------------------------------------------------------------
  // emitWidget — Padding
  // -------------------------------------------------------------------------

  group('emitWidget — Padding', () {
    test('produces rt.registerWidget call', () {
      final cls = _classElement(materialResult, 'Padding');
      final code = emitter.emitWidget(cls);
      expect(code, contains("rt.registerWidget('Padding'"));
    });

    test('covers key parameter', () {
      final cls = _classElement(materialResult, 'Padding');
      final code = emitter.emitWidget(cls);
      expect(code, contains("key:"));
    });

    test('covers padding parameter with required cast (non-nullable)', () {
      final cls = _classElement(materialResult, 'Padding');
      final code = emitter.emitWidget(cls);
      // padding is required non-nullable → no `?` on type, no fallback
      expect(
        code,
        contains("padding: args['padding'] as EdgeInsetsGeometry"),
      );
    });

    test('covers child parameter as nullable', () {
      final cls = _classElement(materialResult, 'Padding');
      final code = emitter.emitWidget(cls);
      // child is Widget? (optional nullable)
      expect(code, contains("child: args['child'] as Widget?"));
    });
  });

  // -------------------------------------------------------------------------
  // emitWidget — Column
  // -------------------------------------------------------------------------

  group('emitWidget — Column', () {
    test('produces rt.registerWidget call', () {
      final cls = _classElement(materialResult, 'Column');
      final code = emitter.emitWidget(cls);
      expect(code, contains("rt.registerWidget('Column'"));
    });

    test('covers mainAxisAlignment with default inlined', () {
      final cls = _classElement(materialResult, 'Column');
      final code = emitter.emitWidget(cls);
      expect(
        code,
        contains('mainAxisAlignment'),
        reason: 'mainAxisAlignment param should be present',
      );
      expect(
        code,
        contains('MainAxisAlignment.start'),
        reason: 'default value should be inlined verbatim',
      );
    });

    test('covers crossAxisAlignment param', () {
      final cls = _classElement(materialResult, 'Column');
      final code = emitter.emitWidget(cls);
      expect(code, contains('crossAxisAlignment'));
    });

    test('covers mainAxisSize param', () {
      final cls = _classElement(materialResult, 'Column');
      final code = emitter.emitWidget(cls);
      expect(code, contains('mainAxisSize'));
    });

    test('covers children with safe List<Widget> cast pattern', () {
      final cls = _classElement(materialResult, 'Column');
      final code = emitter.emitWidget(cls);
      expect(
        code,
        contains("(args['children'] as List?)?.cast<Widget>() ?? const []"),
      );
    });
  });

  // -------------------------------------------------------------------------
  // emitWidget — Text (positional + named params)
  // -------------------------------------------------------------------------

  group('emitWidget — Text', () {
    test('produces rt.registerWidget call', () {
      final cls = _classElement(materialResult, 'Text');
      final code = emitter.emitWidget(cls);
      expect(code, contains("rt.registerWidget('Text'"));
    });

    test('includes the data positional param name', () {
      final cls = _classElement(materialResult, 'Text');
      final code = emitter.emitWidget(cls);
      // Text's first positional param is `data` (String)
      expect(code, contains("data"));
    });

    test('includes String type in cast', () {
      final cls = _classElement(materialResult, 'Text');
      final code = emitter.emitWidget(cls);
      expect(code, contains("as String"));
    });
  });

  // -------------------------------------------------------------------------
  // emitConstant
  // -------------------------------------------------------------------------

  group('emitConstant', () {
    test('Icons.menu produces registerConstant call', () {
      final el = _staticMemberElement(materialResult, 'Icons', 'menu');
      final code = emitter.emitConstant(el);
      expect(code, "rt.registerConstant('Icons.menu', Icons.menu);");
    });

    test('CrossAxisAlignment.start (enum) produces registerConstant call', () {
      // CrossAxisAlignment is an EnumElement — _interfaceElement handles it.
      final el = _staticMemberElement(
        materialResult,
        'CrossAxisAlignment',
        'start',
      );
      final code = emitter.emitConstant(el);
      expect(
        code,
        "rt.registerConstant('CrossAxisAlignment.start', CrossAxisAlignment.start);",
      );
    });
  });

  // -------------------------------------------------------------------------
  // emitMethod
  // -------------------------------------------------------------------------

  group('emitMethod', () {
    test('String.toUpperCase produces registerMethod call', () {
      final method = _methodElement(materialResult, 'String', 'toUpperCase');
      final receiverType =
          (method.enclosingElement3 as InterfaceElement).thisType;
      final code = emitter.emitMethod(method, receiverType: receiverType);
      expect(code, contains("rt.registerMethod('String.toUpperCase'"));
      expect(
        code,
        contains('(recv, args) => (recv as String).toUpperCase()'),
      );
    });

    test('num.toStringAsFixed produces positional arg cast', () {
      final method = _methodElement(materialResult, 'num', 'toStringAsFixed');
      final receiverType =
          (method.enclosingElement3 as InterfaceElement).thisType;
      final code = emitter.emitMethod(method, receiverType: receiverType);
      expect(code, contains("rt.registerMethod('num.toStringAsFixed'"));
      expect(code, contains('(recv as num).toStringAsFixed('));
      expect(code, contains('args[0] as int'));
    });
  });

  // -------------------------------------------------------------------------
  // emitValueBuilder
  // -------------------------------------------------------------------------

  group('emitValueBuilder', () {
    test('EdgeInsets.all (named ctor, one positional double) produces builder',
        () {
      final ctor = _ctorElement(materialResult, 'EdgeInsets', 'all');
      final code = emitter.emitValueBuilder(ctor);
      expect(code, contains("rt.registerValueBuilder('EdgeInsets.all'"));
      expect(code, contains('(args) => EdgeInsets.all('));
      expect(code, contains('args[0] as double'));
    });

    test('TextStyle unnamed ctor (named params with defaults) produces builder',
        () {
      // TextStyle() has all-optional named params — use it as unnamed ctor test
      final ctor = _ctorElement(materialResult, 'TextStyle', '');
      final code = emitter.emitValueBuilder(ctor);
      expect(code, contains("rt.registerValueBuilder('TextStyle'"));
      expect(code, contains('(args) => TextStyle('));
    });
  });

  // -------------------------------------------------------------------------
  // emitSubscript
  // -------------------------------------------------------------------------

  group('emitSubscript', () {
    test('subscript type produces registerSubscript call with .[] key', () async {
      // Resolve a source that uses a subscript on MaterialColor so we get
      // the actual DartType from the type collector.
      final screen = await _resolveScreen('''
import 'package:flutter/material.dart';
Widget build() => Container(color: Colors.grey[300]);
''');
      final types = collectTypes(screen);
      expect(types.subscriptables, isNotEmpty);
      final subType = types.subscriptables.first;
      final code = emitter.emitSubscript(subType);
      expect(code, contains("rt.registerSubscript('"));
      expect(code, contains(".[]'"));
      expect(code, contains('(recv, key) => (recv as '));
      expect(code, contains(')[key'));
    });
  });

  // -------------------------------------------------------------------------
  // emitAll
  // -------------------------------------------------------------------------

  group('emitAll', () {
    test('produces widget and valueBuilder registrations', () async {
      final screen = await _resolveScreen('''
import 'package:flutter/material.dart';
Widget build() => Padding(padding: EdgeInsets.all(8), child: const SizedBox());
''');
      final collected = collectTypes(screen);
      final code = emitter.emitAll(collected);

      expect(code, contains("rt.registerWidget('Padding'"));
      expect(code, contains("rt.registerWidget('SizedBox'"));
      expect(code, contains("rt.registerValueBuilder('EdgeInsets.all'"));
    });

    test('all emitted lines end with a semicolon', () async {
      final screen = await _resolveScreen('''
import 'package:flutter/material.dart';
Widget build() => Padding(padding: EdgeInsets.all(8), child: const SizedBox());
''');
      final collected = collectTypes(screen);
      final code = emitter.emitAll(collected);
      for (final line in code.split('\n')) {
        if (line.trim().isNotEmpty) {
          expect(line.trim(), endsWith(';'), reason: 'Line: $line');
        }
      }
    });

    test('Column registration covers mainAxisAlignment default and children',
        () async {
      final screen = await _resolveScreen('''
import 'package:flutter/material.dart';
Widget build() => Column(children: [const Text('hi')]);
''');
      final collected = collectTypes(screen);
      final code = emitter.emitAll(collected);

      expect(code, contains("rt.registerWidget('Column'"));
      expect(code, contains('MainAxisAlignment.start'));
      expect(code, contains("(args['children'] as List?)?.cast<Widget>()"));
    });
  });
}
