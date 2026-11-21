import 'package:flutter_test/flutter_test.dart';
import 'package:nextclass/domain/services/semantic_version.dart';

void main() {
  test('parses a v-prefixed release tag and keeps its display version', () {
    final version = SemanticVersion.tryParse('v1.0.2+3');

    expect(version, isNotNull);
    expect(version.toString(), '1.0.2+3');
  });

  test('compares core versions and treats build metadata as non-ordering', () {
    expect(
      SemanticVersion.parse('1.0.2'),
      greaterThan(SemanticVersion.parse('1.0.1')),
    );
    expect(
      SemanticVersion.parse('1.1.0'),
      greaterThan(SemanticVersion.parse('1.0.99')),
    );
    expect(
      SemanticVersion.parse('2.0.0'),
      greaterThan(SemanticVersion.parse('1.99.99')),
    );
    expect(SemanticVersion.parse('1.0.2+3'), SemanticVersion.parse('1.0.2+9'));
  });

  test('orders prereleases below stable releases using semver identifiers', () {
    final alpha = SemanticVersion.parse('1.0.0-alpha');
    final alphaOne = SemanticVersion.parse('1.0.0-alpha.1');
    final beta = SemanticVersion.parse('1.0.0-beta');
    final stable = SemanticVersion.parse('1.0.0');

    expect(alpha, lessThan(alphaOne));
    expect(alphaOne, lessThan(beta));
    expect(beta, lessThan(stable));
  });

  test('rejects malformed versions and numeric prerelease identifiers with leading zeroes', () {
    expect(SemanticVersion.tryParse('1.0'), isNull);
    expect(SemanticVersion.tryParse('01.0.0'), isNull);
    expect(SemanticVersion.tryParse('1.0.0-01'), isNull);
    expect(
      () => SemanticVersion.parse('release-latest'),
      throwsFormatException,
    );
  });
}
