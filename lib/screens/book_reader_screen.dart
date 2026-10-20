import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:koni_archive/io.dart';
import 'package:pdfrx/pdfrx.dart';

import '../models/book_model.dart';
import '../models/book_reading_progress.dart';
import '../services/book_document_service.dart';
import '../services/reading_progress_service.dart';

class BookReaderScreen extends StatefulWidget {
  const BookReaderScreen({
    super.key,
    required this.book,
    this.progressStore,
    this.documentService,
  });

  final BookModel book;
  final ReadingProgressStore? progressStore;
  final BookDocumentService? documentService;

  @override
  State<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends State<BookReaderScreen> {
  late final ReadingProgressStore _progressStore;
  late final BookDocumentService _documentService;
  final PdfViewerController _pdfController = PdfViewerController();
  PageController? _comicPageController;
  PageController? _textPageController;
  Archive? _archive;
  List<ArchiveEntry> _imageEntries = [];
  Future<Uint8List>? _imageFuture;
  String? _text;
  String? _error;
  bool _loading = true;
  int _currentPage = 1;
  int _totalPages = 0;
  double _fontSize = 19;
  double? _lastTextWidth;
  double? _lastTextHeight;
  double? _lastPaginatedFontSize;
  List<String> _textPages = const [];

  String get _extension => widget.book.extension.toLowerCase();
  bool get _isPdf => _extension == '.pdf';
  bool get _isImageArchive => _extension == '.cbz' || _extension == '.cbr';
  bool _isComicImage(ArchiveEntry entry) {
    final path = entry.path.toLowerCase();
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp') ||
        path.endsWith('.gif') ||
        path.endsWith('.bmp');
  }

  @override
  void initState() {
    super.initState();
    _progressStore =
        widget.progressStore ?? SharedPreferencesReadingProgressStore();
    _documentService = widget.documentService ?? BookDocumentService();
    _openBook();
  }

  Future<void> _openBook() async {
    try {
      final progress = await _progressStore.load(widget.book.path);
      if (progress != null) _currentPage = progress.currentPage;
      _comicPageController = PageController(initialPage: _currentPage - 1);
      _textPageController = PageController(initialPage: _currentPage - 1);

      if (_isPdf) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      if (_isImageArchive) {
        final archive = await openArchiveFile(widget.book.path);
        final entries = archive.files.where(_isComicImage).toList()
          ..sort((first, second) => _naturalCompare(first.path, second.path));
        if (entries.isEmpty) {
          await archive.close();
          throw const BookDocumentException(
            'В архиве не найдено изображений страниц.',
          );
        }
        _archive = archive;
        _imageEntries = entries;
        _totalPages = entries.length;
        _currentPage = _currentPage.clamp(1, _totalPages).toInt();
        _imageFuture = archive.readBytes(
          entries[_currentPage - 1],
          maxSize: 80 << 20,
        );
      } else {
        _text = await _documentService.loadText(widget.book);
      }
      if (mounted) setState(() => _loading = false);
    } on BookDocumentException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } on FileSystemException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось открыть файл: ${error.message}';
        _loading = false;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка доступа к файлу: ${error.message ?? error.code}';
        _loading = false;
      });
    } on ArchiveException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось открыть архив: $error';
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось открыть файл: $error';
        _loading = false;
      });
    }
  }

  int _naturalCompare(String first, String second) {
    final partsPattern = RegExp(r'\d+|\D+');
    final firstParts = partsPattern
        .allMatches(first.toLowerCase())
        .map((match) => match.group(0)!)
        .toList();
    final secondParts = partsPattern
        .allMatches(second.toLowerCase())
        .map((match) => match.group(0)!)
        .toList();
    for (
      var index = 0;
      index < firstParts.length && index < secondParts.length;
      index++
    ) {
      final a = firstParts[index];
      final b = secondParts[index];
      final bothNumeric =
          RegExp(r'^\d+$').hasMatch(a) && RegExp(r'^\d+$').hasMatch(b);
      final order = bothNumeric
          ? int.parse(a).compareTo(int.parse(b))
          : a.compareTo(b);
      if (order != 0) return order;
    }
    return firstParts.length.compareTo(secondParts.length);
  }

  void _paginateText(double width, double height) {
    if (_text == null || width <= 0 || height <= 0) return;
    if (_lastTextWidth == width &&
        _lastTextHeight == height &&
        _lastPaginatedFontSize == _fontSize) {
      return;
    }

    final contentWidth = (width - 44).clamp(1.0, width).toDouble();
    final contentHeight = (height - 40).clamp(1.0, height).toDouble();
    final style = TextStyle(
      fontFamily: 'serif',
      fontSize: _fontSize,
      height: 1.7,
      color: Theme.of(context).colorScheme.onSurface,
    );
    final pages = <String>[];
    var remainder = _text!.trim();

    while (remainder.isNotEmpty) {
      final painter = TextPainter(
        text: TextSpan(text: remainder, style: style),
        textDirection: Directionality.of(context),
      )..layout(maxWidth: contentWidth);
      final lines = painter.computeLineMetrics();
      if (painter.height <= contentHeight || lines.length <= 1) {
        pages.add(remainder);
        break;
      }

      var end = painter
          .getPositionForOffset(Offset(contentWidth, contentHeight))
          .offset;
      if (end <= 0 || end >= remainder.length) {
        pages.add(remainder);
        break;
      }
      final whitespace = remainder.lastIndexOf(RegExp(r'\s'), end - 1);
      if (whitespace > end * 0.65) end = whitespace + 1;
      final page = remainder.substring(0, end).trimRight();
      if (page.isEmpty) {
        pages.add(remainder);
        break;
      }
      pages.add(page);
      remainder = remainder.substring(end).trimLeft();
    }

    _textPages = pages.isEmpty ? [''] : pages;
    _lastTextWidth = width;
    _lastTextHeight = height;
    _lastPaginatedFontSize = _fontSize;
    final totalChanged = _totalPages != _textPages.length;
    _totalPages = _textPages.length;
    if (totalChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
    final restoredPage = _currentPage.clamp(1, _totalPages).toInt();
    if (restoredPage != _currentPage) {
      _currentPage = restoredPage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_textPageController?.hasClients ?? false) {
          _textPageController!.jumpToPage(_currentPage - 1);
        }
      });
    }
  }

  Future<void> _saveProgress(int page, int total) async {
    if (total < 1) return;
    final currentPage = page.clamp(1, total).toInt();
    if (mounted) {
      setState(() {
        _currentPage = currentPage;
        _totalPages = total;
      });
    }
    try {
      await _progressStore.save(
        widget.book.path,
        BookReadingProgress(currentPage: currentPage, totalPages: total),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось сохранить прогресс: $error')),
        );
      }
    }
  }

  void _setImagePage(int page) {
    if (_archive == null || _imageEntries.isEmpty) return;
    final safePage = page.clamp(1, _imageEntries.length).toInt();
    setState(() {
      _currentPage = safePage;
      _imageFuture = _archive!.readBytes(
        _imageEntries[safePage - 1],
        maxSize: 80 << 20,
      );
    });
    unawaited(_saveProgress(safePage, _imageEntries.length));
  }

  void _setTextPage(int page, int total) {
    unawaited(_saveProgress(page + 1, total));
  }

  void _goToTextPage(int page) {
    if (_textPageController?.hasClients ?? false) {
      _textPageController!.jumpToPage(page - 1);
    }
  }

  @override
  void dispose() {
    _comicPageController?.dispose();
    _textPageController?.dispose();
    unawaited(_archive?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayedTotalPages = _isPdf || _isImageArchive
        ? _totalPages
        : _textPages.length;
    final progressText = displayedTotalPages > 0
        ? '$_currentPage из $displayedTotalPages стр. · ${(_currentPage * 100 / displayedTotalPages).round()}%'
        : 'Загрузка страниц…';
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
            Text(progressText, style: theme.textTheme.labelSmall),
          ],
        ),
        actions: [
          if (!_isPdf && !_isImageArchive)
            IconButton(
              tooltip: 'Уменьшить текст',
              onPressed: _fontSize > 12
                  ? () => setState(() => _fontSize -= 1)
                  : null,
              icon: const Icon(Icons.text_decrease_rounded),
            ),
          if (!_isPdf && !_isImageArchive)
            IconButton(
              tooltip: 'Увеличить текст',
              onPressed: _fontSize < 32
                  ? () => setState(() => _fontSize += 1)
                  : null,
              icon: const Icon(Icons.text_increase_rounded),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : _isPdf
          ? _buildPdfReader()
          : _isImageArchive
          ? _buildComicReader()
          : _buildTextReader(),
    );
  }

  Widget _buildPdfReader() {
    return Column(
      children: [
        Expanded(
          child: PdfViewer.file(
            widget.book.path,
            controller: _pdfController,
            initialPageNumber: _currentPage,
            params: PdfViewerParams(
              onViewerReady: (document, controller) {
                final total = document.pages.length;
                if (mounted) {
                  setState(() {
                    _totalPages = total;
                    _currentPage = _currentPage.clamp(1, total).toInt();
                  });
                }
                unawaited(_saveProgress(_currentPage, total));
              },
              onDocumentLoadFinished: (documentRef, succeeded) {
                if (!succeeded && mounted) {
                  setState(() => _error = 'Не удалось открыть этот PDF-файл.');
                }
              },
              onPageChanged: (page) {
                final pageCount = _totalPages;
                if (page != null && pageCount > 0) {
                  unawaited(_saveProgress(page, pageCount));
                }
              },
            ),
          ),
        ),
        _pageControls(
          _currentPage,
          _totalPages,
          (page) => _pdfController.goToPage(pageNumber: page),
        ),
      ],
    );
  }

  Widget _buildComicReader() {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _comicPageController,
            itemCount: _imageEntries.length,
            onPageChanged: (index) => _setImagePage(index + 1),
            itemBuilder: (context, index) => FutureBuilder<Uint8List>(
              future: index == _currentPage - 1
                  ? _imageFuture
                  : _archive!.readBytes(
                      _imageEntries[index],
                      maxSize: 80 << 20,
                    ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Не удалось загрузить страницу: ${snapshot.error}',
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(
                    child: Image.memory(
                      snapshot.data!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Text('Не удалось показать изображение: $error'),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        _pageControls(_currentPage, _totalPages, _setImagePage),
      ],
    );
  }

  Widget _buildTextReader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        _paginateText(constraints.maxWidth, constraints.maxHeight);
        final pages = _textPages;
        return Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _textPageController,
                itemCount: pages.length,
                onPageChanged: (index) => _setTextPage(index, pages.length),
                itemBuilder: (context, index) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                  child: Text(
                    pages[index],
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: _fontSize,
                      height: 1.7,
                    ),
                  ),
                ),
              ),
            ),
            _pageControls(_currentPage, pages.length, _goToTextPage),
          ],
        );
      },
    );
  }

  Widget _pageControls(
    int currentPage,
    int totalPages,
    void Function(int page) goToPage,
  ) {
    if (totalPages < 1) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Предыдущая страница',
            onPressed: currentPage > 1 ? () => goToPage(currentPage - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Slider(
              min: 1,
              max: totalPages.toDouble(),
              divisions: totalPages > 1 ? totalPages - 1 : null,
              value: currentPage
                  .toDouble()
                  .clamp(1, totalPages.toDouble())
                  .toDouble(),
              onChanged: (value) => goToPage(value.round()),
            ),
          ),
          IconButton(
            tooltip: 'Следующая страница',
            onPressed: currentPage < totalPages
                ? () => goToPage(currentPage + 1)
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}
