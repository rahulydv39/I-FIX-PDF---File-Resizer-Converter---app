// This is a basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';

import 'package:file_converter/app.dart';

void main() {
  testWidgets('File Converter app launches', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FileConverterApp());

    // Verify that the app title is displayed
    expect(find.text('File Converter'), findsOneWidget);
  });
}
