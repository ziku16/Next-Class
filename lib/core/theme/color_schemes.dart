import 'package:flutter/material.dart';

/// NextClass Material 3 Light Color Scheme
/// Revo-Brutalist design language:
/// Warm textured paper background (#FAF6EE), stark black (#000000) outlines,
/// electric saturated orange (#FF5500), safety yellow (#FFE500), electric green (#00E676).
const lightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFFFF5500), // Vivid orange
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFFFD180), // Orange tint
  onPrimaryContainer: Color(0xFF000000),
  secondary: Color(0xFFFFE500), // Safety yellow
  onSecondary: Color(0xFF000000),
  secondaryContainer: Color(0xFFFFF59D), // Yellow tint
  onSecondaryContainer: Color(0xFF000000),
  tertiary: Color(0xFF00E676), // Electric green
  onTertiary: Color(0xFF000000),
  tertiaryContainer: Color(0xFFB9F6CA),
  onTertiaryContainer: Color(0xFF000000),
  error: Color(0xFFFF1744), // Vivid red
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFFCDD2),
  onErrorContainer: Color(0xFF000000),
  surface: Color(0xFFFAF6EE), // Warm off-white paper
  onSurface: Color(0xFF000000), // Stark solid black
  onSurfaceVariant: Color(0xFF262626), // Dark neutral
  outline: Color(0xFF000000), // Heavy black outline
  outlineVariant: Color(0xFF000000),
  surfaceContainerLow: Color(0xFFFFFFFF), // Crisp card white
  surfaceContainer: Color(0xFFF3ECE0),
  surfaceContainerHigh: Color(0xFFEBE3D3),
  inverseSurface: Color(0xFF000000),
  onInverseSurface: Color(0xFFFAF6EE),
);

/// NextClass Material 3 Dark Color Scheme (high contrast fallback)
const darkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFFF7043),
  onPrimary: Color(0xFF000000),
  primaryContainer: Color(0xFFD84315),
  onPrimaryContainer: Color(0xFFFFFFFF),
  secondary: Color(0xFFFFEE58),
  onSecondary: Color(0xFF000000),
  secondaryContainer: Color(0xFFFBC02D),
  onSecondaryContainer: Color(0xFF000000),
  tertiary: Color(0xFF69F0AE),
  onTertiary: Color(0xFF000000),
  tertiaryContainer: Color(0xFF00C853),
  onTertiaryContainer: Color(0xFF000000),
  error: Color(0xFFFF5252),
  onError: Color(0xFF000000),
  errorContainer: Color(0xFFD50000),
  onErrorContainer: Color(0xFFFFFFFF),
  surface: Color(0xFF1E1E1E),
  onSurface: Color(0xFFFAF6EE),
  onSurfaceVariant: Color(0xFFE0E0E0),
  outline: Color(0xFFFFFFFF),
  outlineVariant: Color(0xFFCCCCCC),
  surfaceContainerLow: Color(0xFF2A2A2A),
  surfaceContainer: Color(0xFF333333),
  surfaceContainerHigh: Color(0xFF3D3D3D),
  inverseSurface: Color(0xFFFAF6EE),
  onInverseSurface: Color(0xFF1E1E1E),
);
