// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zachrm/models/book_model.dart';
import 'package:zachrm/main.dart';
import 'package:zachrm/screens/library_screen.dart';
import 'package:zachrm/services/book_scanner_service.dart';

void main() {
  testWidgets('library shows controls for scanning local books', (
    tester,
  ) async {
    await tester.pumpWidget(const LumenApp());
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.text('Ваша библиотека'))).brightness,
      Brightness.dark,
    );
    expect(find.text('Сканировать'), findsOneWidget);
    expect(find.text('Выбрать папку'), findsOneWidget);
    expect(
      find.text(
        'Пока ничего не найдено. Просканируйте папки или выберите свою.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('library displays books returned by the scanner', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LibraryScreen(scannerService: _FakeBookScannerService()),
      ),
    );
    await tester.tap(find.text('Сканировать'));
    await tester.pumpAndSettle();

    expect(find.text('Example novel'), findsOneWidget);
    expect(find.text('EPUB · 1.0 КБ\n/books/book.epub'), findsOneWidget);
  });

  testWidgets('comic files are grouped by source folder and chapters sorted', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: LibraryScreen(scannerService: _FakeMangaScannerService())),
    );
    await tester.tap(find.text('Сканировать'));
    await tester.pumpAndSettle();

    expect(find.text('Series A'), findsOneWidget);
    expect(find.text('3 глав · /manga/Series A'), findsOneWidget);
    await tester.tap(find.text('Series A'));
    await tester.pumpAndSettle();

    final chapter2 = tester.getTopLeft(find.text('Chapter 2')).dy;
    final chapter10 = tester.getTopLeft(find.text('Chapter 10')).dy;
    expect(chapter2, lessThan(chapter10));
  });
}

class _FakeBookScannerService extends BookScannerService {
  @override
  Future<List<BookModel>> scanDefaultDirectories() async => const [
    BookModel(
      path: '/books/book.epub',
      title: 'Example novel',
      extension: '.epub',
      size: 1024,
    ),
  ];
}

class _FakeMangaScannerService extends BookScannerService {
  @override
  Future<List<BookModel>> scanDefaultDirectories() async => const [
    BookModel(
      path: '/manga/Series A/Chapter 10.cbz',
      title: 'Chapter 10',
      extension: '.cbz',
      size: 100,
    ),
    BookModel(
      path: '/manga/Series A/Chapter 2.cbz',
      title: 'Chapter 2',
      extension: '.cbz',
      size: 20,
    ),
    BookModel(
      path: '/manga/Series A/Chapter 1.cbz',
      title: 'Chapter 1',
      extension: '.cbz',
      size: 10,
    ),
  ];
}
