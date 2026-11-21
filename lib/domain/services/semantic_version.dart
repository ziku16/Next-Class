/// A semantic version used to compare installed and published app versions.
final class SemanticVersion implements Comparable<SemanticVersion> {
  const SemanticVersion._({
    required this.major,
    required this.minor,
    required this.patch,
    this.prerelease,
    this.buildMetadata,
  });

  static final RegExp _pattern = RegExp(
    r'^[vV]?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)'
    r'(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?'
    r'(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$',
  );

  final int major;
  final int minor;
  final int patch;
  final String? prerelease;
  final String? buildMetadata;

  static SemanticVersion parse(String value) {
    final version = tryParse(value);
    if (version == null) {
      throw FormatException('Invalid semantic version', value);
    }
    return version;
  }

  static SemanticVersion? tryParse(String value) {
    final match = _pattern.firstMatch(value.trim());
    if (match == null) return null;

    final prerelease = match.group(4);
    if (prerelease != null) {
      for (final identifier in prerelease.split('.')) {
        if (identifier.length > 1 &&
            identifier.startsWith('0') &&
            RegExp(r'^\d+$').hasMatch(identifier)) {
          return null;
        }
      }
    }

    return SemanticVersion._(
      major: int.parse(match.group(1)!),
      minor: int.parse(match.group(2)!),
      patch: int.parse(match.group(3)!),
      prerelease: prerelease,
      buildMetadata: match.group(5),
    );
  }

  @override
  int compareTo(SemanticVersion other) {
    final core = major.compareTo(other.major);
    if (core != 0) return core;
    final minorOrder = minor.compareTo(other.minor);
    if (minorOrder != 0) return minorOrder;
    final patchOrder = patch.compareTo(other.patch);
    if (patchOrder != 0) return patchOrder;

    if (prerelease == null && other.prerelease == null) return 0;
    if (prerelease == null) return 1;
    if (other.prerelease == null) return -1;

    final left = prerelease!.split('.');
    final right = other.prerelease!.split('.');
    for (var index = 0; index < left.length && index < right.length; index++) {
      final leftIdentifier = left[index];
      final rightIdentifier = right[index];
      final leftNumeric = RegExp(r'^\d+$').hasMatch(leftIdentifier);
      final rightNumeric = RegExp(r'^\d+$').hasMatch(rightIdentifier);

      if (leftNumeric && rightNumeric) {
        final numberOrder = int.parse(leftIdentifier)
            .compareTo(int.parse(rightIdentifier));
        if (numberOrder != 0) return numberOrder;
      } else if (leftNumeric != rightNumeric) {
        return leftNumeric ? -1 : 1;
      } else {
        final textOrder = leftIdentifier.compareTo(rightIdentifier);
        if (textOrder != 0) return textOrder;
      }
    }
    return left.length.compareTo(right.length);
  }

  bool operator <(SemanticVersion other) => compareTo(other) < 0;

  bool operator <=(SemanticVersion other) => compareTo(other) <= 0;

  bool operator >(SemanticVersion other) => compareTo(other) > 0;

  bool operator >=(SemanticVersion other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is SemanticVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, prerelease);

  @override
  String toString() =>
      '$major.$minor.$patch'
      '${prerelease == null ? '' : '-$prerelease'}'
      '${buildMetadata == null ? '' : '+$buildMetadata'}';
}
