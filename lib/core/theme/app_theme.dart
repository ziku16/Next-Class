import 'package:flutter/material.dart';
import '../../ui/shared/fluid_page_route.dart';
import 'color_schemes.dart';
import 'next_class_colors.dart';
import 'typography.dart';

/// NextClass Material 3 ThemeData assembly.
class AppTheme {
  AppTheme._();

  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static Future<void> initThemeMode() async {
    themeModeNotifier.value = ThemeMode.light;
  }

  static Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = ThemeMode.light;
  }

  /// Light theme definition
  static ThemeData get light {
    final colorScheme = lightColorScheme;
    final textTheme = NextClassTypography.buildTextTheme(colorScheme.onSurface);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFFFFDF0),
      textTheme: textTheme,
      extensions: const [NextClassColors.light],
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLow,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: Colors.black, width: 3.0),
        ),
        margin: EdgeInsets.zero,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFFFAF6EE),
        elevation: 0,
        modalElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          side: BorderSide(color: Colors.black, width: 3.5),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFFFAF6EE),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Colors.black, width: 3.5),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w900,
          color: Colors.black,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.black,
          fontWeight: FontWeight.w600,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: Colors.black, width: 3.0),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: Colors.black,
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: Colors.black, width: 3.0),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: Colors.black,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Colors.black, width: 3.0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: textTheme.bodyMedium?.copyWith(color: const Color(0xFF666666)),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.black,
          fontWeight: FontWeight.w700,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Colors.black, width: 3.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Colors.black, width: 3.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Colors.black, width: 3.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFFF1744), width: 3.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFFF1744), width: 3.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: colorScheme.secondary,
        disabledColor: const Color(0xFFE0E0E0),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: Colors.black,
          fontWeight: FontWeight.w800,
        ) ?? const TextStyle(),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: Colors.black,
          fontWeight: FontWeight.w800,
        ) ?? const TextStyle(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: Colors.black, width: 2.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          fontFamily: 'SpaceGrotesk',
          color: Colors.white,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Colors.black, width: 2.5),
        ),
        actionTextColor: const Color(0xFFFFDE59),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FluidPageTransitionsBuilder(),
          TargetPlatform.iOS: FluidPageTransitionsBuilder(),
          TargetPlatform.linux: FluidPageTransitionsBuilder(),
          TargetPlatform.macOS: FluidPageTransitionsBuilder(),
          TargetPlatform.windows: FluidPageTransitionsBuilder(),
        },
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFFFAF6EE),
        indicatorColor: colorScheme.secondary,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelSmall?.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w900,
            );
          }
          return textTheme.labelSmall?.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          );
        }),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: Colors.black,
        textColor: Colors.black,
        titleTextStyle: textTheme.bodyLarge?.copyWith(
          fontFamily: 'SpaceGrotesk',
          fontWeight: FontWeight.w900,
          color: Colors.black,
          fontSize: 15,
        ),
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          fontFamily: 'SpaceGrotesk',
          fontWeight: FontWeight.w700,
          color: const Color(0xFF222222),
          fontSize: 13,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.black;
          }
          return const Color(0xFF555555);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFFFFE500);
          }
          return const Color(0xFFE0E0E0);
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.black),
        trackOutlineWidth: WidgetStateProperty.all(2.0),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStateProperty.all(
            const BorderSide(color: Colors.black, width: 2.0),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFFFFE500);
            }
            return Colors.white;
          }),
          foregroundColor: WidgetStateProperty.all(Colors.black),
          textStyle: WidgetStateProperty.all(
            const TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              color: Colors.black,
            ),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Colors.black,
        thickness: 2,
        space: 2,
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: darkColorScheme,
      scaffoldBackgroundColor: const Color(0xFF121212),
      extensions: const [NextClassColors.dark],
    );
  }
}
