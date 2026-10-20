import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zachrm/services/book_scanner_service.dart';

void main() {
  late Directory temporaryDirectory;
  late BookScannerService scanner;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('lumen-books-');
    scanner = BookScannerService();
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'finds supported formats recursively and returns file metadata',
    () async {
      final nestedDirectory = Directory(
        '${temporaryDirectory.path}${Platform.pathSeparator}nested',
      );
      await nestedDirectory.create();
      final pdf = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}Novel.PDF',
      );
      final comic = File(
        '${nestedDirectory.path}${Platform.pathSeparator}issue.cbz',
      );
      final epub = File(
        '${nestedDirectory.path}${Platform.pathSeparator}stories.epub',
      );
      final fb2 = File(
        '${nestedDirectory.path}${Platform.pathSeparator}reference.FB2',
      );
      final cbr = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}archive.cbr',
      );
      final unsupported = File(
        '${temporaryDirectory.path}${Platform.pathSeparator}notes.txt',
      );
      await pdf.writeAsBytes([1, 2, 3]);
      await comic.writeAsBytes([4, 5]);
      await epub.writeAsBytes([6, 7, 8, 9]);
      await fb2.writeAsBytes([11, 12]);
      await cbr.writeAsBytes([10]);
      await unsupported.writeAsString('ignore');

      final books = await scanner.scanDirectory(temporaryDirectory);

      expect(books.map((book) => book.title), [
        'archive',
        'issue',
        'Novel',
        'reference',
        'stories',
      ]);
      expect(books.map((book) => book.extension), [
        '.cbr',
        '.cbz',
        '.pdf',
        '.fb2',
        '.epub',
      ]);
      expect(books.map((book) => book.size), [1, 2, 3, 2, 4]);
      expect(books.map((book) => book.path), [
        cbr.path,
        comic.path,
        pdf.path,
        fb2.path,
        epub.path,
      ]);
    },
  );
}
