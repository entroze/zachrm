// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zachrm/models/book_model.dart';
import 'package:zachrm/models/book_reading_progress.dart';
import 'package:zachrm/main.dart';
import 'package:zachrm/screens/book_reader_screen.dart';
import 'package:zachrm/screens/library_screen.dart';
import 'package:zachrm/services/book_document_service.dart';
import 'package:zachrm/services/book_scanner_service.dart';
import 'package:zachrm/services/reading_progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'shared preferences progress store saves and reloads the legacy API',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final store = SharedPreferencesReadingProgressStore(
        preferences: preferences,
      );
      const progress = BookReadingProgress(currentPage: 12, totalPages: 80);

      await store.save('/books/novel.fb2', progress);

      final restored = await store.load('/books/novel.fb2');
      expect(restored?.currentPage, progress.currentPage);
      expect(restored?.totalPages, progress.totalPages);
    },
  );

  testWidgets('library shows controls for scanning local books', (
    tester,
  ) async {
    await tester.pumpWidget(
      LumenApp(progressStore: _MemoryReadingProgressStore()),
    );
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
        home: LibraryScreen(
          scannerService: _FakeBookScannerService(),
          progressStore: _MemoryReadingProgressStore(),
        ),
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
      MaterialApp(
        home: LibraryScreen(
          scannerService: _FakeMangaScannerService(),
          progressStore: _MemoryReadingProgressStore(),
        ),
      ),
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

  testWidgets('text reader paginates by font size and persists page progress', (
    tester,
  ) async {
    final progressStore = _MemoryReadingProgressStore();
    await tester.pumpWidget(
      MaterialApp(
        home: BookReaderScreen(
          book: const BookModel(
            path: '/books/novel.fb2',
            title: 'Novel',
            extension: '.fb2',
            size: 500,
          ),
          progressStore: progressStore,
          documentService: _LongTextBookDocumentService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('1 из '), findsOneWidget);
    await tester.tap(find.byTooltip('Следующая страница'));
    await tester.pumpAndSettle();

    expect(progressStore.saved?.currentPage, 2);
    expect(progressStore.saved?.totalPages, greaterThan(1));
    expect(find.textContaining('2 из '), findsOneWidget);
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

class _MemoryReadingProgressStore implements ReadingProgressStore {
  final values = <String, BookReadingProgress>{};

  BookReadingProgress? get saved => values['/books/novel.fb2'];

  @override
  Future<BookReadingProgress?> load(String bookPath) async => values[bookPath];

  @override
  Future<void> save(String bookPath, BookReadingProgress progress) async {
    values[bookPath] = progress;
  }
}

class _LongTextBookDocumentService extends BookDocumentService {
  @override
  Future<String> loadText(BookModel book) async => List.filled(
    240,
    'Это тестовая строка книги для проверки разбиения на страницы.',
  ).join('\n\n');
}
