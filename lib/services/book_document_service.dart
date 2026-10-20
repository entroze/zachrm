import 'dart:convert';
import 'dart:io';

import 'package:koni_archive/io.dart';
import 'package:xml/xml.dart';

import '../models/book_model.dart';

class BookDocumentException implements Exception {
  const BookDocumentException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BookDocumentService {
  Future<String> loadText(BookModel book) async {
    try {
      if (book.extension == '.fb2') {
        final xml = XmlDocument.parse(
          utf8.decode(await File(book.path).readAsBytes(), allowMalformed: true),
        );
        return _extractText(xml);
      }
      if (book.extension == '.epub') return await _loadEpub(book.path);
      throw BookDocumentException(
        'Текстовый просмотр не поддерживает ${book.extension}.',
      );
    } on FileSystemException catch (error) {
      throw BookDocumentException('Не удалось прочитать файл: ${error.message}');
    } on FormatException catch (error) {
      throw BookDocumentException('Файл книги повреждён или имеет неверный формат: $error');
    } on ArchiveException catch (error) {
      throw BookDocumentException('Не удалось прочитать архив книги: $error');
    }
  }

  Future<String> _loadEpub(String path) async {
    final archive = await openArchiveFile(path);
    try {
      final containerEntry = archive.entry('META-INF/container.xml');
      if (containerEntry == null) {
        throw const BookDocumentException(
          'В EPUB отсутствует META-INF/container.xml.',
        );
      }
      final container = XmlDocument.parse(
        utf8.decode(await archive.readBytes(containerEntry, maxSize: 2 << 20)),
      );
      final opfPath = container
          .findAllElements('rootfile')
          .map((element) => element.getAttribute('full-path'))
          .whereType<String>()
          .firstOrNull;
      if (opfPath == null) {
        throw const BookDocumentException(
          'В EPUB не найден путь к файлу книги.',
        );
      }

      final packageEntry = archive.entry(opfPath);
      if (packageEntry == null) {
        throw const BookDocumentException('Файл описания EPUB не найден.');
      }
      final packageDocument = XmlDocument.parse(
        utf8.decode(await archive.readBytes(packageEntry, maxSize: 8 << 20)),
      );

      final manifest = <String, String>{};
      for (final item in packageDocument.findAllElements('item')) {
        final id = item.getAttribute('id');
        final href = item.getAttribute('href');
        if (id != null && href != null) manifest[id] = href;
      }
      final packageDirectory = opfPath.contains('/')
          ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1)
          : '';
      final chapters = <String>[];
      for (final itemRef in packageDocument.findAllElements('itemref')) {
        final href = manifest[itemRef.getAttribute('idref')];
        if (href == null) continue;
        final decodedHref = Uri.decodeComponent(href.split('#').first);
        final chapterPath = _normalizeArchivePath(
          '$packageDirectory$decodedHref',
        );
        final chapterEntry = archive.entry(chapterPath);
        if (chapterEntry == null) continue;
        final chapter = XmlDocument.parse(
          utf8.decode(
            await archive.readBytes(chapterEntry, maxSize: 16 << 20),
            allowMalformed: true,
          ),
        );
        final body = chapter.findAllElements('body').firstOrNull;
        if (body != null) chapters.add(_extractText(body));
      }

      final text = chapters.where((chapter) => chapter.isNotEmpty).join('\n\n');
      if (text.isEmpty) {
        throw const BookDocumentException('В EPUB не найден текст глав.');
      }
      return text;
    } finally {
      await archive.close();
    }
  }

  String _extractText(XmlNode node) {
    final blocks = node
        .descendants
        .whereType<XmlElement>()
        .where(
          (element) => const {
            'p',
            'title',
            'subtitle',
            'h1',
            'h2',
            'h3',
            'blockquote',
            'v',
          }.contains(element.name.local),
        )
        .map((element) => _normalizeWhitespace(element.innerText))
        .where((text) => text.isNotEmpty)
        .toList();

    final text = blocks.isEmpty ? node.innerText : blocks.join('\n\n');
    return text
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  String _normalizeWhitespace(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();

  String _normalizeArchivePath(String path) {
    final parts = <String>[];
    for (final part in path.replaceAll('\\', '/').split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (parts.isNotEmpty) parts.removeLast();
      } else {
        parts.add(part);
      }
    }
    return parts.join('/');
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
