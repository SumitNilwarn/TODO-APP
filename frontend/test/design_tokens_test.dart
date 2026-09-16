import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/shared/theme/app_colors.dart';
import 'package:todo_app/shared/theme/design_tokens.dart';

void main() {
  group('AppSpacing', () {
    test('defines the full documented scale', () {
      expect(
        [
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.tight,
          AppSpacing.md,
          AppSpacing.roomy,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.huge,
          AppSpacing.xxl,
          AppSpacing.giant,
        ],
        [4, 8, 12, 16, 20, 24, 32, 40, 48, 64],
      );
    });

    test('semantic aliases map onto the scale', () {
      expect(AppSpacing.page, 24);
      expect(AppSpacing.card, 20);
      expect(AppSpacing.input, 16);
      expect(AppSpacing.section, 24);
    });
  });

  group('AppRadius', () {
    test('semantic levels stay restrained and pill is reserved', () {
      expect(AppRadius.small, 8);
      expect(AppRadius.medium, 14);
      expect(AppRadius.large, 16);
      expect(AppRadius.extraLarge, 20);
      expect(AppRadius.pill, 999);
    });

    test('exposes BorderRadius variants for every level', () {
      expect(AppRadius.smallAll, const BorderRadius.all(Radius.circular(8)));
      expect(AppRadius.mediumAll, const BorderRadius.all(Radius.circular(14)));
      expect(AppRadius.pillAll, isA<BorderRadius>());
    });
  });

  group('AppSizes', () {
    test('interactive targets never fall below the touch target', () {
      expect(AppSizes.touchTarget, 48);
      expect(AppSizes.buttonHeight, 52);
      expect(AppSizes.inputHeight, 52);
      // The visual rail item is 44; its row adds a 4px cushion → 48 total.
      expect(AppSizes.navItemHeight + AppSpacing.xs, AppSizes.touchTarget);
    });

    test('sidebar geometry is stable', () {
      expect(AppSizes.sidebarWidth, 264);
      expect(AppSizes.brandMark, 34);
      expect(AppSizes.avatar, 36);
    });
  });

  group('AppShadows elevation levels', () {
    test('none is empty, subtle/raised/floating are ordered', () {
      expect(AppShadows.none, isEmpty);
      expect(AppShadows.subtle, isNotEmpty);
      expect(AppShadows.raised, isNotEmpty);
      expect(AppShadows.floating, isNotEmpty);
      // Floating is the strongest plane.
      expect(
        AppShadows.floating.first.blurRadius,
        greaterThan(AppShadows.raised.first.blurRadius),
      );
    });

    test('soft alias points at the subtle level', () {
      expect(AppShadows.soft, same(AppShadows.subtle));
    });
  });

  group('AppColors', () {
    test('primary/ink/text roles share one dark ink', () {
      expect(AppColors.primary, AppColors.ink);
      expect(AppColors.textPrimary, AppColors.primary);
      expect(AppColors.onPrimary, AppColors.onInk);
    });

    test('muted shorthand matches the quiet text role', () {
      expect(AppColors.muted, AppColors.textMuted);
      expect(AppColors.accent, AppColors.secondary);
    });

    test('feedback semantics are defined', () {
      expect(AppColors.success, const Color(0xFF2E7D32));
      expect(AppColors.warning, const Color(0xFF9A6B00));
      expect(AppColors.danger, const Color(0xFFB3261E));
      expect(AppColors.info, const Color(0xFF37577E));
    });

    test('surfaces and borders are calm neutrals', () {
      expect(AppColors.background, const Color(0xFFF6F5F2));
      expect(AppColors.surface, Colors.white);
      expect(AppColors.surfaceElevated, isNot(AppColors.surface));
      expect(AppColors.border, const Color(0xFFEAE8E2));
    });
  });
}
