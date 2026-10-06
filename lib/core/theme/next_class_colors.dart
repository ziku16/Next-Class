import 'package:flutter/material.dart';

/// NextClass custom color roles and functional tokens.
/// Extends Flutter's ThemeData via ThemeExtension.
@immutable
class NextClassColors extends ThemeExtension<NextClassColors> {
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

  /// Returns the subject color corresponding to the given index (index % 8).
  Color getSubjectColor(int index) {
    if (subjects.isEmpty) return defaultSubjects[index % defaultSubjects.length];
    return subjects[index % subjects.length];
  }

  /// Light theme extension instance
  static const light = NextClassColors(
    classCurrent: Color(0xFFFFE500), // Safety yellow active
    classCurrentBorder: Color(0xFF000000), // Solid black border
    classNext: Color(0xFFFF5500), // Vivid orange next
    classPastBorder: Color(0xFF000000),
    quiz: Color(0xFFFF5500),
    onQuiz: Color(0xFF000000),
    quizContainer: Color(0xFFFFD180),
    onQuizContainer: Color(0xFF000000),
    quizUrgent: Color(0xFFFF1744),
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

  /// Dark theme extension instance
  static const dark = NextClassColors(
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
}
