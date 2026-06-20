import 'package:dart_style/dart_style.dart';
import 'package:pub_semver/pub_semver.dart';

String formatDartSource(String source) {
  final formatter = DartFormatter(languageVersion: Version(3, 10, 0));
  try {
    return formatter.format(source);
  } on FormatterException {
    return source; // Return unformatted on error; tests should catch this
  }
}
