import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:desk_sdui_generator/src/analyzer_plugin/rules/no_async_in_screen.dart';
import 'package:desk_sdui_generator/src/analyzer_plugin/rules/no_set_state.dart';
import 'package:desk_sdui_generator/src/analyzer_plugin/rules/no_mutable_locals.dart';
import 'package:desk_sdui_generator/src/analyzer_plugin/rules/no_function_definition.dart';
import 'package:desk_sdui_generator/src/analyzer_plugin/rules/no_try_catch.dart';
import 'package:desk_sdui_generator/src/analyzer_plugin/rules/unsupported_loop.dart';
import 'package:desk_sdui_generator/src/analyzer_plugin/rules/missing_key_warning.dart';
import 'package:desk_sdui_generator/src/analyzer_plugin/rules/error_info.dart';
import 'package:test/test.dart';

void main() {
  group('no_async_in_screen', () {
    test('flags await in function body', () {
      final result = parseString(content: '''
void fn() async {
  await someFuture;
}
''');
      final errors = <AnalysisErrorInfo>[];
      result.unit.accept(NoAsyncInScreenVisitor(errors));
      expect(errors, isNotEmpty);
    });

    test('no error without await', () {
      final result = parseString(content: 'void fn() {}');
      final errors = <AnalysisErrorInfo>[];
      result.unit.accept(NoAsyncInScreenVisitor(errors));
      expect(errors, isEmpty);
    });
  });

  group('no_set_state', () {
    test('flags setState call', () {
      final result = parseString(content: '''
void fn() {
  setState(() {});
}
''');
      final errors = <AnalysisErrorInfo>[];
      result.unit.accept(NoSetStateVisitor(errors));
      expect(errors, isNotEmpty);
    });
  });

  group('no_mutable_locals', () {
    test('flags var declaration', () {
      final result = parseString(content: '''
void fn() {
  var x = 1;
}
''');
      final errors = <AnalysisErrorInfo>[];
      result.unit.accept(NoMutableLocalsVisitor(errors));
      expect(errors, isNotEmpty);
    });

    test('no error with final', () {
      final result = parseString(content: '''
void fn() {
  final x = 1;
}
''');
      final errors = <AnalysisErrorInfo>[];
      result.unit.accept(NoMutableLocalsVisitor(errors));
      expect(errors, isEmpty);
    });
  });

  group('no_function_definition', () {
    test('flags nested function', () {
      final result = parseString(content: '''
void fn() {
  void nested() {}
}
''');
      final errors = <AnalysisErrorInfo>[];
      result.unit.accept(NoFunctionDefinitionVisitor(errors));
      expect(errors, isNotEmpty);
    });
  });

  group('no_try_catch', () {
    test('flags try/catch', () {
      final result = parseString(content: '''
void fn() {
  try {} catch (e) {}
}
''');
      final errors = <AnalysisErrorInfo>[];
      result.unit.accept(NoTryCatchVisitor(errors));
      expect(errors, isNotEmpty);
    });
  });

  group('unsupported_loop', () {
    test('flags while loop', () {
      final result = parseString(content: '''
void fn() {
  while (true) {}
}
''');
      final errors = <AnalysisErrorInfo>[];
      result.unit.accept(UnsupportedLoopVisitor(errors));
      expect(errors, isNotEmpty);
    });

    test('flags counter for loop', () {
      final result = parseString(content: '''
void fn() {
  for (var i = 0; i < 10; i++) {}
}
''');
      final errors = <AnalysisErrorInfo>[];
      result.unit.accept(UnsupportedLoopVisitor(errors));
      expect(errors, isNotEmpty);
    });
  });

  group('missing_key_warning', () {
    test('flags for-element without key', () {
      final result = parseString(content: '''
void fn() => [for (final x in items) Text(x)];
''');
      final warnings = <AnalysisErrorInfo>[];
      result.unit.accept(MissingKeyWarningVisitor(warnings));
      expect(warnings, isNotEmpty);
    });
  });
}
