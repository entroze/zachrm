import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/book_model.dart';

class BookScannerException implements Exception {
  const BookScannerException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BookAccessDeniedException extends BookScannerException {
  const BookAccessDeniedException(super.message);
}

class BookScannerService {
  static const _supportedExtensions = {
    '.pdf',
    '.epub',
    '.fb2',
    '.cbz',
    '.cbr',
    '.zip',
  };

  static const _imageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
    '.bmp',
  };

  Future<List<BookModel>> scanDefaultDirectories() async {
    await _requestStorageAccess();

    try {
      if (Platform.isAndroid) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowMultiple: true,
          allowedExtensions: [
            'pdf',
            'epub',
            'fb2',
            'cbz',
            'cbr',
            'zip',
            'jpg',
            'jpeg',
            'png',
            'webp',
            'gif',
            'bmp',
          ],
        );

        if (result == null || result.files.isEmpty) {
          return [];
        }

        return result.files
            .map((file) {
              final ext = '.${file.extension?.toLowerCase() ?? 'unknown'}';
              return BookModel(
                path: file.path ?? file.identifier ?? '',
                title: file.name.replaceAll(RegExp(r'\.[^.]*$'), ''),
                extension: ext,
                size: file.size ?? 0,
                isContentUri: file.path?.startsWith('content://') ?? false,
                isImageFolder: _imageExtensions.contains(ext),
              );
            })
            .where(
              (book) =>
                  _supportedExtensions.contains(book.extension) ||
                  book.isImageFolder,
            )
            .toList();
      }

      final externalFiles = await getExternalStorageDirectory();
      if (externalFiles == null) {
        throw const BookScannerException(
          'Не удалось определить внешнее хранилище устройства.',
        );
      }

      // Android returns .../Android/data/<package>/files for this directory.
      var storageRoot = Directory(externalFiles.path);
      for (var level = 0; level < 4; level++) {
        storageRoot = storageRoot.parent;
      }
      return await _scanDirectories([
        Directory('${storageRoot.path}${Platform.pathSeparator}Download'),
        Directory('${storageRoot.path}${Platform.pathSeparator}Downloads'),
        Directory('${storageRoot.path}${Platform.pathSeparator}Documents'),
        Directory('${storageRoot.path}${Platform.pathSeparator}Books'),
      ]);
    } on FileSystemException catch (error) {
      throw BookScannerException(
        'Не удалось прочитать папки устройства: ${error.message}',
      );
    } on PlatformException catch (error) {
      throw BookScannerException(
        'Ошибка доступа к хранилищу: ${error.message ?? error.code}',
      );
    }
  }

  Future<List<BookModel>?> scanSelectedDirectory() async {
    await _requestStorageAccess();

    try {
      if (Platform.isAndroid) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowMultiple: true,
          allowedExtensions: [
            'pdf',
            'epub',
            'fb2',
            'cbz',
            'cbr',
            'zip',
            'jpg',
            'jpeg',
            'png',
            'webp',
            'gif',
            'bmp',
          ],
          dialogTitle: 'Выберите файлы книг',
        );

        if (result == null) return null;

        return result.files
            .map((file) {
              final ext = '.${file.extension?.toLowerCase() ?? 'unknown'}';
              return BookModel(
                path: file.path ?? file.identifier ?? '',
                title: file.name.replaceAll(RegExp(r'\.[^.]*$'), ''),
                extension: ext,
                size: file.size ?? 0,
                isContentUri: file.path?.startsWith('content://') ?? false,
                isImageFolder: _imageExtensions.contains(ext),
              );
            })
            .where(
              (book) =>
                  _supportedExtensions.contains(book.extension) ||
                  book.isImageFolder,
            )
            .toList();
      }

      final selectedPath = await FilePicker.getDirectoryPath(
        dialogTitle: 'Выберите папку с книгами',
      );
      if (selectedPath == null) return null;
      return await _scanDirectories([Directory(selectedPath)]);
    } on FileSystemException catch (error) {
      throw BookScannerException(
        'Не удалось прочитать выбранную папку: ${error.message}',
      );
    } on PlatformException catch (error) {
      throw BookScannerException(
        'Не удалось выбрать папку: ${error.message ?? error.code}',
      );
    }
  }

  Future<List<BookModel>> scanDirectory(Directory directory) async {
    await _requestStorageAccess();
    try {
      return await _scanDirectories([directory]);
    } on FileSystemException catch (error) {
      throw BookScannerException(
        'Не удалось прочитать папку ${directory.path}: ${error.message}',
      );
    }
  }

  Future<void> _requestStorageAccess() async {
    if (!Platform.isAndroid) return;

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;

      if (androidInfo.version.sdkInt >= 30) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          throw BookAccessDeniedException(
            'Необходимо разрешение на доступ к файлам. Включите его в настройках приложения.',
          );
        }
      } else {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          throw BookAccessDeniedException(
            'Необходимо разрешение на доступ к файлам.',
          );
        }
      }
    } on PlatformException catch (error) {
      throw BookScannerException(
        'Не удалось запросить разрешение на файлы: '
        '${error.message ?? error.code}',
      );
    }
  }

  Future<List<BookModel>> _scanDirectories(List<Directory> directories) async {
    final booksByPath = <String, BookModel>{};

    for (final directory in directories) {
      if (!await directory.exists()) continue;

      await for (final entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;

        final fileName = entity.uri.pathSegments.last;
        final extensionStart = fileName.lastIndexOf('.');
        if (extensionStart < 0) continue;
        final extension = fileName.substring(extensionStart).toLowerCase();
        if (!_supportedExtensions.contains(extension) &&
            !_imageExtensions.contains(extension))
          continue;

        final stat = await entity.stat();
        if (stat.type != FileSystemEntityType.file) continue;

        final normalizedPath = Platform.isWindows
            ? entity.path.toLowerCase()
            : entity.path;
        booksByPath[normalizedPath] = BookModel(
          path: entity.path,
          title: fileName.substring(0, extensionStart),
          extension: extension,
          size: stat.size,
          isContentUri: false,
          isImageFolder: _imageExtensions.contains(extension),
        );
      }
    }

    final books = booksByPath.values.toList()
      ..sort(
        (first, second) =>
            first.title.toLowerCase().compareTo(second.title.toLowerCase()),
      );
    return books;
  }
}
