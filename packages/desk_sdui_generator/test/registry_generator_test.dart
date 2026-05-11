/// Tests for [RegistryBuilder._emitRegistry] — verifies that the generated
/// `desk_sdui_setup.g.dart` file contains both `rt.registerScreen(...)` and
/// `register<Screen>Dependencies(rt)` calls for each discovered screen.
///
/// These tests exercise the private `_emitRegistry` method indirectly via
/// a unit-style test that constructs [_ScreenInfo]-equivalent data and calls
/// the public string-generation logic through a test-accessible subclass.
library;

import 'package:test/test.dart';
import 'package:desk_sdui_generator/src/registry/registry_generator.dart';

void main() {
  group('RegistryBuilder — _emitRegistry', () {
    final builder = RegistryBuilder();

    test('emits rt.registerScreen and registerDependencies for a single screen',
        () {
      final output = builder.emitRegistryForTest(
        screens: [
          ScreenInfoForTest(
            name: 'chef',
            bindingSymbol: 'chefBinding',
            registrationFn: 'registerChefDependencies',
            sourceUri: Uri.parse(
                'package:desk_sdui_demo/screens/chef.dart'),
          ),
        ],
        packageName: 'desk_sdui_demo',
      );

      expect(output, contains('rt.registerScreen(chefBinding)'),
          reason: 'Must register screen binding');
      expect(output, contains('registerChefDependencies(rt)'),
          reason: 'Must call per-screen dependency registration');
    });

    test('import show clause includes binding from source and fn from reg file',
        () {
      final output = builder.emitRegistryForTest(
        screens: [
          ScreenInfoForTest(
            name: 'chef',
            bindingSymbol: 'chefBinding',
            registrationFn: 'registerChefDependencies',
            sourceUri: Uri.parse(
                'package:desk_sdui_demo/screens/chef.dart'),
          ),
        ],
        packageName: 'desk_sdui_demo',
      );

      expect(output, contains("show chefBinding"),
          reason: 'binding symbol must be in source import');
      expect(output, contains("show registerChefDependencies"),
          reason: 'registration fn must be in reg file import');
      expect(output, contains('chef.sdui_reg.g.dart'),
          reason: 'reg file URI must reference .sdui_reg.g.dart');
    });

    test('emits correct calls for multiple screens', () {
      final output = builder.emitRegistryForTest(
        screens: [
          ScreenInfoForTest(
            name: 'chef',
            bindingSymbol: 'chefBinding',
            registrationFn: 'registerChefDependencies',
            sourceUri:
                Uri.parse('package:desk_sdui_demo/screens/chef.dart'),
          ),
          ScreenInfoForTest(
            name: 'menu',
            bindingSymbol: 'menuBinding',
            registrationFn: 'registerMenuDependencies',
            sourceUri:
                Uri.parse('package:desk_sdui_demo/screens/menu.dart'),
          ),
        ],
        packageName: 'desk_sdui_demo',
      );

      expect(output, contains('rt.registerScreen(chefBinding)'));
      expect(output, contains('registerChefDependencies(rt)'));
      expect(output, contains('rt.registerScreen(menuBinding)'));
      expect(output, contains('registerMenuDependencies(rt)'));
    });

    test('capitalizes single-char screen name correctly', () {
      final output = builder.emitRegistryForTest(
        screens: [
          ScreenInfoForTest(
            name: 'a',
            bindingSymbol: 'aBinding',
            registrationFn: 'registerADependencies',
            sourceUri:
                Uri.parse('package:desk_sdui_demo/screens/a.dart'),
          ),
        ],
        packageName: 'desk_sdui_demo',
      );
      expect(output, contains('registerADependencies(rt)'));
    });
  });
}
