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

  /// 8 Subject colors assigned modulo 8 (all hold >= 3:1 contrast on cards)
  static const List<Color> defaultSubjects = [
    Color(0xFF0E8A7D), // 0: Teal
    Color(0xFF5B6BD6), // 1: Indigo
    Color(0xFF9A5BC8), // 2: Violet
    Color(0xFFD0478A), // 3: Rose
    Color(0xFF6E8B1E), // 4: Olive
    Color(0xFF2F80D8), // 5: Blue
    Color(0xFF2E9A4F), // 6: Green
    Color(0xFFA0703A), // 7: Sand
  ];

  /// Returns the subject color corresponding to the given index (index % 8).
  Color getSubjectColor(int index) {
    if (subjects.isEmpty) return defaultSubjects[index % defaultSubjects.length];
    return subjects[index % subjects.length];
  }

  /// Light theme extension instance
  static const light = NextClassColors(
    classCurrent: Color(0xFF0B6E85),
    classCurrentBorder: Color(0xFF0B6E85),
    classNext: Color(0xFF70797C),
    classPastBorder: Color(0xFFC0C8CB),
    quiz: Color(0xFFB5451B),
    onQuiz: Color(0xFFFFFFFF),
    quizContainer: Color(0xFFFFE0D3),
    onQuizContainer: Color(0xFF3B0D00),
    quizUrgent: Color(0xFFA63A12),
    onQuizUrgent: Color(0xFFFFFFFF),
    success: Color(0xFF1B6C3A),
    successContainer: Color(0xFFBDF0CB),
    onSuccessContainer: Color(0xFF0B3A1D),
    warning: Color(0xFF7A4A00),
    warningContainer: Color(0xFFFFDDB0),
    onWarningContainer: Color(0xFF4A2D00),
    info: Color(0xFF2F5FA8),
    infoContainer: Color(0xFFD7E3FF),
    onInfoContainer: Color(0xFF1B3A6E),
    subjects: defaultSubjects,
  );

  /// Dark theme extension instance
  static const dark = NextClassColors(
    classCurrent: Color(0xFF7DD3E8),
    classCurrentBorder: Color(0xFF7DD3E8),
    classNext: Color(0xFF899295),
    classPastBorder: Color(0xFF40484B),
    quiz: Color(0xFFFFB59B),
    onQuiz: Color(0xFF5A1A00),
    quizContainer: Color(0xFF5C2410),
    onQuizContainer: Color(0xFFFFDBCF),
    quizUrgent: Color(0xFFFF8A65),
    onQuizUrgent: Color(0xFF3B0D00),
    success: Color(0xFF7EDB9B),
    successContainer: Color(0xFF0B3A1D),
    onSuccessContainer: Color(0xFFBDF0CB),
    warning: Color(0xFFFFB95A),
    warningContainer: Color(0xFF4A2D00),
    onWarningContainer: Color(0xFFFFDDB0),
    info: Color(0xFFAAC7FF),
    infoContainer: Color(0xFF1B3A6E),
    onInfoContainer: Color(0xFFD7E3FF),
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
