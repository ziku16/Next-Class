import 'package:flutter/material.dart';

/// NextClass custom color roles and centralized semantic REVO Brutalism tokens.
/// Extends Flutter's ThemeData via ThemeExtension.
@immutable
class NextClassColors extends ThemeExtension<NextClassColors> {
  // Centralized Semantic Tokens (Part 28)
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color shadow;
  final Color accent;
  final Color buttonText;
  final Color cardText;
  final Color inputBackground;
  final Color inputText;
  final Color icon;

  // Functional & State Tokens
  final Color classCurrent;
  final Color classCurrentBorder;
  final Color classNext;
  final Color classPastBorder;
  final Color quiz;
  final Color onQuiz;
  final Color quizContainer;
  final Color onQuizContainer;
  final Color quizUrgent;
  final Color onQuizUrgent;
  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color info;
  final Color infoContainer;
  final Color onInfoContainer;
  final List<Color> subjects;

  const NextClassColors({
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.shadow,
    required this.accent,
    required this.buttonText,
    required this.cardText,
    required this.inputBackground,
    required this.inputText,
    required this.icon,
    required this.classCurrent,
    required this.classCurrentBorder,
    required this.classNext,
    required this.classPastBorder,
    required this.quiz,
    required this.onQuiz,
    required this.quizContainer,
    required this.onQuizContainer,
    required this.quizUrgent,
    required this.onQuizUrgent,
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.subjects,
  });

  /// 8 Subject colors assigned modulo 8 (high-energy brutalist palette)
  static const List<Color> defaultSubjects = [
    Color(0xFFFFE500), // 0: Safety Yellow
    Color(0xFFFF5500), // 1: Vivid Orange
    Color(0xFF00E676), // 2: Electric Green
    Color(0xFF2979FF), // 3: Bright Blue
    Color(0xFFFF4081), // 4: Hot Pink
    Color(0xFF00E5FF), // 5: Electric Cyan
    Color(0xFFFF9100), // 6: Deep Amber
    Color(0xFF7C4DFF), // 7: Vivid Purple
  ];

  /// Whether this theme is dark mode.
  bool get isDark => background.computeLuminance() < 0.5;

  /// Returns the subject color corresponding to the given index (index % 8).
  Color getSubjectColor(int index) {
    if (subjects.isEmpty) return defaultSubjects[index % defaultSubjects.length];
    return subjects[index % subjects.length];
  }

  /// Light theme extension instance
  static const light = NextClassColors(
    background: Color(0xFFFAF6EE), // Warm off-white paper
    surface: Color(0xFFFAF6EE),
    textPrimary: Color(0xFF000000), // Stark solid black
    textSecondary: Color(0xFF262626), // Dark neutral
    border: Color(0xFF000000), // Solid black border
    shadow: Color(0xFF000000), // Solid black hard shadow
    accent: Color(0xFFFF5500), // Vivid orange
    buttonText: Color(0xFFFFFFFF),
    cardText: Color(0xFF000000),
    inputBackground: Color(0xFFFFFFFF),
    inputText: Color(0xFF000000),
    icon: Color(0xFF000000),

    classCurrent: Color(0xFFFFE500), // Safety yellow active
    classCurrentBorder: Color(0xFF000000),
    classNext: Color(0xFFFF5500), // Vivid orange next
    classPastBorder: Color(0xFF000000),
    quiz: Color(0xFFFF5500),
    onQuiz: Color(0xFF000000),
    quizContainer: Color(0xFFFFD180),
    onQuizContainer: Color(0xFF000000),
    quizUrgent: Color(0xFFD50000),
    onQuizUrgent: Color(0xFFFFFFFF),
    success: Color(0xFF00C853),
    successContainer: Color(0xFFB9F6CA),
    onSuccessContainer: Color(0xFF000000),
    warning: Color(0xFFFFE500),
    warningContainer: Color(0xFFFFF59D),
    onWarningContainer: Color(0xFF000000),
    info: Color(0xFF2979FF),
    infoContainer: Color(0xFFBBDEFB),
    onInfoContainer: Color(0xFF000000),
    subjects: defaultSubjects,
  );

  /// Dark theme extension instance (REVO Brutalism in Dark Mode)
  static const dark = NextClassColors(
    background: Color(0xFF141414), // Deep matte brutalist charcoal
    surface: Color(0xFF202020), // Dark card surface
    textPrimary: Color(0xFFFAF6EE), // Crisp stark off-white
    textSecondary: Color(0xFFCCCCCC), // Light neutral
    border: Color(0xFFFFFFFF), // Crisp solid white border
    shadow: Color(0xFF000000), // Solid black hard shadow
    accent: Color(0xFFFF7043), // Vivid warm orange
    buttonText: Color(0xFF000000),
    cardText: Color(0xFFFAF6EE),
    inputBackground: Color(0xFF2A2A2A),
    inputText: Color(0xFFFFFFFF),
    icon: Color(0xFFFFFFFF),

    classCurrent: Color(0xFFFFEE58),
    classCurrentBorder: Color(0xFFFFFFFF),
    classNext: Color(0xFFFF7043),
    classPastBorder: Color(0xFFFFFFFF),
    quiz: Color(0xFFFF7043),
    onQuiz: Color(0xFF000000),
    quizContainer: Color(0xFFD84315),
    onQuizContainer: Color(0xFFFFFFFF),
    quizUrgent: Color(0xFFFF5252),
    onQuizUrgent: Color(0xFF000000),
    success: Color(0xFF69F0AE),
    successContainer: Color(0xFF00C853),
    onSuccessContainer: Color(0xFF000000),
    warning: Color(0xFFFFEE58),
    warningContainer: Color(0xFFFBC02D),
    onWarningContainer: Color(0xFF000000),
    info: Color(0xFF448AFF),
    infoContainer: Color(0xFF1565C0),
    onInfoContainer: Color(0xFFFFFFFF),
    subjects: defaultSubjects,
  );

  @override
  NextClassColors copyWith({
    Color? background,
    Color? surface,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? shadow,
    Color? accent,
    Color? buttonText,
    Color? cardText,
    Color? inputBackground,
    Color? inputText,
    Color? icon,
    Color? classCurrent,
    Color? classCurrentBorder,
    Color? classNext,
    Color? classPastBorder,
    Color? quiz,
    Color? onQuiz,
    Color? quizContainer,
    Color? onQuizContainer,
    Color? quizUrgent,
    Color? onQuizUrgent,
    Color? success,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? info,
    Color? infoContainer,
    Color? onInfoContainer,
    List<Color>? subjects,
  }) {
    return NextClassColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      shadow: shadow ?? this.shadow,
      accent: accent ?? this.accent,
      buttonText: buttonText ?? this.buttonText,
      cardText: cardText ?? this.cardText,
      inputBackground: inputBackground ?? this.inputBackground,
      inputText: inputText ?? this.inputText,
      icon: icon ?? this.icon,
      classCurrent: classCurrent ?? this.classCurrent,
      classCurrentBorder: classCurrentBorder ?? this.classCurrentBorder,
      classNext: classNext ?? this.classNext,
      classPastBorder: classPastBorder ?? this.classPastBorder,
      quiz: quiz ?? this.quiz,
      onQuiz: onQuiz ?? this.onQuiz,
      quizContainer: quizContainer ?? this.quizContainer,
      onQuizContainer: onQuizContainer ?? this.onQuizContainer,
      quizUrgent: quizUrgent ?? this.quizUrgent,
      onQuizUrgent: onQuizUrgent ?? this.onQuizUrgent,
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
      subjects: subjects ?? this.subjects,
    );
  }

  @override
  NextClassColors lerp(ThemeExtension<NextClassColors>? other, double t) {
    if (other is! NextClassColors) {
      return this;
    }
    return NextClassColors(
      background: Color.lerp(background, other.background, t) ?? background,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      border: Color.lerp(border, other.border, t) ?? border,
      shadow: Color.lerp(shadow, other.shadow, t) ?? shadow,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      buttonText: Color.lerp(buttonText, other.buttonText, t) ?? buttonText,
      cardText: Color.lerp(cardText, other.cardText, t) ?? cardText,
      inputBackground: Color.lerp(inputBackground, other.inputBackground, t) ?? inputBackground,
      inputText: Color.lerp(inputText, other.inputText, t) ?? inputText,
      icon: Color.lerp(icon, other.icon, t) ?? icon,
      classCurrent: Color.lerp(classCurrent, other.classCurrent, t) ?? classCurrent,
      classCurrentBorder: Color.lerp(classCurrentBorder, other.classCurrentBorder, t) ?? classCurrentBorder,
      classNext: Color.lerp(classNext, other.classNext, t) ?? classNext,
      classPastBorder: Color.lerp(classPastBorder, other.classPastBorder, t) ?? classPastBorder,
      quiz: Color.lerp(quiz, other.quiz, t) ?? quiz,
      onQuiz: Color.lerp(onQuiz, other.onQuiz, t) ?? onQuiz,
      quizContainer: Color.lerp(quizContainer, other.quizContainer, t) ?? quizContainer,
      onQuizContainer: Color.lerp(onQuizContainer, other.onQuizContainer, t) ?? onQuizContainer,
      quizUrgent: Color.lerp(quizUrgent, other.quizUrgent, t) ?? quizUrgent,
      onQuizUrgent: Color.lerp(onQuizUrgent, other.onQuizUrgent, t) ?? onQuizUrgent,
      success: Color.lerp(success, other.success, t) ?? success,
      successContainer: Color.lerp(successContainer, other.successContainer, t) ?? successContainer,
      onSuccessContainer: Color.lerp(onSuccessContainer, other.onSuccessContainer, t) ?? onSuccessContainer,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t) ?? warningContainer,
      onWarningContainer: Color.lerp(onWarningContainer, other.onWarningContainer, t) ?? onWarningContainer,
      info: Color.lerp(info, other.info, t) ?? info,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t) ?? infoContainer,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t) ?? onInfoContainer,
      subjects: t < 0.5 ? subjects : other.subjects,
    );
  }
}

/// Helper extension on BuildContext for quick access to NextClassColors
extension NextClassColorsX on BuildContext {
  NextClassColors get ncColors =>
      Theme.of(this).extension<NextClassColors>() ?? NextClassColors.light;

  bool get isDark => ncColors.isDark;
}
