import 'dart:convert';
import 'package:test/test.dart';
import 'package:protoc_gen_dart_unified/src/runtime/sse_parser.dart';

void main() {
  group('SseParser', () {
    test('parses single data event', () async {
      final input = utf8.encode('data: hello world\n\n');
      final stream = Stream.fromIterable([input]);
      final results = await SseParser.parse(stream).toList();
      expect(results, equals(['hello world']));
    });

    test('parses multiple data events', () async {
      final input = utf8.encode('data: first\n\ndata: second\n\ndata: third\n\n');
      final stream = Stream.fromIterable([input]);
      final results = await SseParser.parse(stream).toList();
      expect(results, equals(['first', 'second', 'third']));
    });

    test('parses multi-line data', () async {
      final input = utf8.encode('data: line1\ndata: line2\n\n');
      final stream = Stream.fromIterable([input]);
      final results = await SseParser.parse(stream).toList();
      expect(results, equals(['line1\nline2']));
    });

    test('ignores comments', () async {
      final input = utf8.encode(': this is a comment\ndata: actual data\n\n');
      final stream = Stream.fromIterable([input]);
      final results = await SseParser.parse(stream).toList();
      expect(results, equals(['actual data']));
    });

    test('ignores event field', () async {
      final input = utf8.encode('event: custom\ndata: payload\n\n');
      final stream = Stream.fromIterable([input]);
      final results = await SseParser.parse(stream).toList();
      expect(results, equals(['payload']));
    });

    test('handles chunked input', () async {
      final fullData = 'data: part1\n\ndata: part2\n\n';
      final bytes = utf8.encode(fullData);
      // Split into small chunks
      final chunks = <List<int>>[];
      for (var i = 0; i < bytes.length; i += 5) {
        final end = (i + 5 > bytes.length) ? bytes.length : i + 5;
        chunks.add(bytes.sublist(i, end));
      }
      final stream = Stream.fromIterable(chunks);
      final results = await SseParser.parse(stream).toList();
      expect(results, equals(['part1', 'part2']));
    });

    test('handles CRLF line endings', () async {
      final input = utf8.encode('data: hello\r\n\r\ndata: world\r\n\r\n');
      final stream = Stream.fromIterable([input]);
      final results = await SseParser.parse(stream).toList();
      expect(results, equals(['hello', 'world']));
    });

    test('handles empty stream', () async {
      final input = utf8.encode('');
      final stream = Stream.fromIterable([input]);
      final results = await SseParser.parse(stream).toList();
      expect(results, isEmpty);
    });

    test('handles data without trailing double newline', () async {
      final input = utf8.encode('data: incomplete');
      final stream = Stream.fromIterable([input]);
      final results = await SseParser.parse(stream).toList();
      expect(results, equals(['incomplete']));
    });
  });
}
