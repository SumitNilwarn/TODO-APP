import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'theme_extensions.dart';

/// Command-center design extras carried out-of-band from the semantic
/// [AppThemeTokens] palette.
///
/// These tokens feed the cinematic chrome of the redesign — the architectural
/// grid, ambient glows, technical framing and monospaced data labels — without
/// touching the contract-stable `AppAppColors`/`AppThemeTokens` surface. Two
/// presets ship with the product:
///
/// - [CommandDesignTokens.white] — cool daylight chrome for the WHITE theme.
/// - [CommandDesignTokens.graphite] — cool electric glow on steel for GRAPHITE.
///
/// Components resolve these through `context.commandTokens` and only render
/// chrome when the tokens are present (they always are under the app root).
@immutable
class CommandDesignTokens extends ThemeExtension<CommandDesignTokens> {
  const CommandDesignTokens({
    required this.gridLine,
    required this.gridMajor,
    required this.frame,
    required this.glow,
    required this.glowStrong,
    required this.heroSecondary,
    required this.monoFamily,
    required this.panelShadow,
  });

  /// Chrome presets for the WHITE ("paper") theme.
  const CommandDesignTokens.white()
    : gridLine = const Color(0x0C17171B),
      gridMajor = const Color(0x1F17171B),
      frame = const Color(0x2617171B),
      glow = const Color(0x0F5F5F6A),
      glowStrong = const Color(0x1F5F5F6A),
      heroSecondary = AppColors.textSecondary,
      monoFamily = 'monospace',
      panelShadow = const [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 48,
          offset: Offset(0, 28),
          spreadRadius: -12,
        ),
        BoxShadow(
          color: Color(0x0D000000),
          blurRadius: 14,
          offset: Offset(0, 6),
          spreadRadius: -4,
        ),
      ];

  /// Chrome presets for the GRAPHITE ("command center") theme.
  const CommandDesignTokens.graphite()
    : gridLine = const Color(0x12FFFFFF),
      gridMajor = const Color(0x22FFFFFF),
      frame = const Color(0x3DE9F0FF),
      glow = const Color(0x1F6FA8FF),
      glowStrong = const Color(0x3D6FA8FF),
      heroSecondary = AppColorsDark.textSecondary,
      monoFamily = 'monospace',
      panelShadow = const [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 60,
          offset: Offset(0, 32),
          spreadRadius: -16,
        ),
        BoxShadow(
          color: Color(0x2E6FA8FF),
          blurRadius: 24,
          offset: Offset(0, 0),
          spreadRadius: -6,
        ),
      ];

  /// Faint architectural grid line (per-major-step rhythm set by widgets).
  final Color gridLine;

  /// Brighter accent step of the architectural grid.
  final Color gridMajor;

  /// Technical chrome frame (sidebar divider, panel corners, hero brackets).
  final Color frame;

  /// Ambient glow used behind hero panels and floating surfaces.
  final Color glow;

  /// Stronger glow for hover/active floating surfaces.
  final Color glowStrong;

  /// Secondary tint for hero overline/meta copy.
  final Color heroSecondary;

  /// Monospace family for data labels and readouts.
  final String monoFamily;

  /// The deep chrome shadow carried by floating panels.
  final List<BoxShadow> panelShadow;

  @override
  CommandDesignTokens copyWith({
    Color? gridLine,
    Color? gridMajor,
    Color? frame,
    Color? glow,
    Color? glowStrong,
    Color? heroSecondary,
    String? monoFamily,
    List<BoxShadow>? panelShadow,
  }) {
    return CommandDesignTokens(
      gridLine: gridLine ?? this.gridLine,
      gridMajor: gridMajor ?? this.gridMajor,
      frame: frame ?? this.frame,
      glow: glow ?? this.glow,
      glowStrong: glowStrong ?? this.glowStrong,
      heroSecondary: heroSecondary ?? this.heroSecondary,
      monoFamily: monoFamily ?? this.monoFamily,
      panelShadow: panelShadow ?? this.panelShadow,
    );
  }

  @override
  CommandDesignTokens lerp(covariant CommandDesignTokens? other, double t) {
    if (other == null) return this;
    return CommandDesignTokens(
      gridLine: Color.lerp(gridLine, other.gridLine, t)!,
      gridMajor: Color.lerp(gridMajor, other.gridMajor, t)!,
      frame: Color.lerp(frame, other.frame, t)!,
      glow: Color.lerp(glow, other.glow, t)!,
      glowStrong: Color.lerp(glowStrong, other.glowStrong, t)!,
      heroSecondary: Color.lerp(heroSecondary, other.heroSecondary, t)!,
      monoFamily: t < 0.5 ? monoFamily : other.monoFamily,
      panelShadow: _lerpShadows(panelShadow, other.panelShadow, t),
    );
  }

  static List<BoxShadow> _lerpShadows(
    List<BoxShadow> a,
    List<BoxShadow> b,
    double t,
  ) {
    final length = a.length > b.length ? a.length : b.length;
    return [
      for (var i = 0; i < length; i++)
        BoxShadow.lerp(
          i < a.length ? a[i] : null,
          i < b.length ? b[i] : null,
          t,
        )!,
    ];
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CommandDesignTokens &&
            gridLine == other.gridLine &&
            gridMajor == other.gridMajor &&
            frame == other.frame &&
            glow == other.glow &&
            glowStrong == other.glowStrong &&
            heroSecondary == other.heroSecondary &&
            monoFamily == other.monoFamily &&
            panelShadow == other.panelShadow;
  }

  @override
  int get hashCode {
    return Object.hashAll([
      gridLine,
      gridMajor,
      frame,
      glow,
      glowStrong,
      heroSecondary,
      monoFamily,
    ]);
  }
}

/// Convenience accessor for the command-center chrome tokens.
extension CommandTokensContext on BuildContext {
  CommandDesignTokens get commandTokens =>
      Theme.of(this).extension<CommandDesignTokens>() ??
      const CommandDesignTokens.white();
}

/// Mono data readout style shared by data labels and readouts.
abstract final class CommandText {
  static TextStyle label(BuildContext context, {Color? color}) {
    final tokens = context.commandTokens;
    final base = Theme.of(context).textTheme.labelSmall;
    return (base ?? const TextStyle()).copyWith(
      fontFamily: tokens.monoFamily,
      fontFamilyFallback: const ['Consolas', 'Menlo', 'Courier New'],
      letterSpacing: 1.4,
      fontWeight: FontWeight.w500,
      color: color ?? context.appColors.textMuted,
    );
  }

  static TextStyle value(BuildContext context, {Color? color}) {
    final tokens = context.commandTokens;
    final base = Theme.of(context).textTheme.bodyMedium;
    return (base ?? const TextStyle()).copyWith(
      fontFamily: tokens.monoFamily,
      fontFamilyFallback: const ['Consolas', 'Menlo', 'Courier New'],
      letterSpacing: 0.4,
      fontWeight: FontWeight.w600,
      color: color ?? context.appColors.textPrimary,
    );
  }
}

/// Shared chrome decoration — the architectural grid must reference the same
/// geometry everywhere, so the widget and backgrounds stay in lock-step.
abstract final class CommandGrid {
  static const double step = 96;
  static const int majorEvery = 4;
}
