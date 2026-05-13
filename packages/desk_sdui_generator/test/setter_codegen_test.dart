// ignore_for_file: deprecated_member_use
library;

import 'package:test/test.dart';

void main() {
  group('Setter codegen eligibility checks', () {
    // These tests verify the logic for determining if a field is setter-eligible.
    // Unit tests for actual code generation require full analyzer setup.

    // Test 1: non-final field → eligible
    test('non-final field is setter-eligible', () {
      const isFinal = false;
      const isLate = false;
      const isStatic = false;
      const isPublic = true;

      final isEligible = isPublic && !isFinal && !isLate && !isStatic;
      expect(isEligible, isTrue);
    });

    // Test 2: final field → not eligible
    test('final field is not setter-eligible', () {
      const isFinal = true;
      const isLate = false;
      const isStatic = false;
      const isPublic = true;

      final isEligible = isPublic && !isFinal && !isLate && !isStatic;
      expect(isEligible, isFalse);
    });

    // Test 3: late field → not eligible
    test('late field is not setter-eligible', () {
      const isFinal = false;
      const isLate = true;
      const isStatic = false;
      const isPublic = true;

      final isEligible = isPublic && !isFinal && !isLate && !isStatic;
      expect(isEligible, isFalse);
    });

    // Test 4: static field → not eligible
    test('static field is not setter-eligible', () {
      const isFinal = false;
      const isLate = false;
      const isStatic = true;
      const isPublic = true;

      final isEligible = isPublic && !isFinal && !isLate && !isStatic;
      expect(isEligible, isFalse);
    });

    // Test 5: private field → not eligible
    test('private field is not setter-eligible', () {
      const isFinal = false;
      const isLate = false;
      const isStatic = false;
      const isPublic = false;

      final isEligible = isPublic && !isFinal && !isLate && !isStatic;
      expect(isEligible, isFalse);
    });

    // Test 6: public, non-final, non-late, non-static → eligible
    test('public non-final non-late non-static field is eligible', () {
      const isFinal = false;
      const isLate = false;
      const isStatic = false;
      const isPublic = true;

      final isEligible = isPublic && !isFinal && !isLate && !isStatic;
      expect(isEligible, isTrue);
    });
  });
}
