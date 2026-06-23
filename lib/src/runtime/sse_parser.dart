import 'dart:async';
import 'dart:convert';

/// Parses a Server-Sent Events (SSE) stream.
///
/// SSE format (per https://html.spec.whatwg.org/multipage/server-sent-events.html):
///   - Each event is separated by double newline
///   - Fields: `data:`, `event:`, `id:`, `retry:`
///   - Lines starting with `:` are comments (ignored)
///
/// This parser extracts `data` fields and yields them as strings.
class SseParser {
  /// Parses an SSE byte stream and yields decoded data strings.
  static Stream<String> parse(Stream<List<int>> byteStream) async* {
    final buffer = StringBuffer();
    await for (final chunk in byteStream) {
      buffer.write(utf8.decode(chunk));
      final content = buffer.toString();
      final events = _splitEvents(content);
      // Keep the last (potentially incomplete) event in the buffer
      buffer.clear();
      if (events.remainder.isNotEmpty) {
        buffer.write(events.remainder);
      }
      for (final data in events.dataLines) {
        if (data.isNotEmpty) yield data;
      }
    }
    // Process any remaining data
    final remaining = buffer.toString();
    if (remaining.isNotEmpty) {
      final data = _extractData(remaining);
      if (data != null && data.isNotEmpty) yield data;
    }
  }

  /// Splits the buffer into complete events and a remainder.
  static _SplitResult _splitEvents(String content) {
    // Events are separated by double newlines (\n\n, \r\n\r\n, or \r\r)
    final dataLines = <String>[];
    var remainder = content;

    // Normalize line endings
    normalized() => content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    final normalizedContent = normalized();
    final parts = normalizedContent.split('\n\n');

    for (var i = 0; i < parts.length - 1; i++) {
      final data = _extractData(parts[i]);
      if (data != null) dataLines.add(data);
    }

    // The last part might be incomplete
    remainder = parts.last;

    return _SplitResult(dataLines, remainder);
  }

  /// Extracts the `data` field from an event block.
  static String? _extractData(String eventBlock) {
    final lines = eventBlock.split('\n');
    final dataLines = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('data:')) {
        final value = trimmed.substring(5).trim();
        dataLines.add(value);
      }
      // Ignore comments (lines starting with ':')
      // Ignore other fields (event:, id:, retry:)
    }
    if (dataLines.isEmpty) return null;
    return dataLines.join('\n');
  }
}

class _SplitResult {
  final List<String> dataLines;
  final String remainder;
  _SplitResult(this.dataLines, this.remainder);
}
