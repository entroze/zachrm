import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/book_model.dart';
import '../services/book_scanner_service.dart';

enum _LibraryFilter { all, books, comics }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, this.scannerService});

  final BookScannerService? scannerService;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late final BookScannerService _scannerService;
  List<BookModel> _books = [];
  _LibraryFilter _filter = _LibraryFilter.all;
  String _query = '';
  String? _errorMessage;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _scannerService = widget.scannerService ?? BookScannerService();
  }

  List<BookModel> get _visibleBooks {
    final normalizedQuery = _query.trim().toLowerCase();
    return _books.where((book) {
      final isComic = book.extension == '.cbz' || book.extension == '.cbr';
      final matchesFilter = switch (_filter) {
        _LibraryFilter.all => true,
        _LibraryFilter.books => !isComic,
        _LibraryFilter.comics => isComic,
      };
      final matchesQuery =
          normalizedQuery.isEmpty ||
          book.title.toLowerCase().contains(normalizedQuery) ||
          book.path.toLowerCase().contains(normalizedQuery);
      return matchesFilter && matchesQuery;
    }).toList();
  }

  Future<void> _scan(Future<List<BookModel>?> Function() scan) async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    try {
      final books = await scan();
      if (!mounted) return;
      if (books != null) setState(() => _books = books);
    } on BookScannerException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } on FileSystemException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Ошибка чтения файлов: ${error.message}');
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(
        () => _errorMessage =
            'Ошибка доступа к файлам: ${error.message ?? error.code}',
      );
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _showSearch() async {
    final query = await showSearch<String>(
      context: context,
      delegate: _LibrarySearchDelegate(_query),
    );
    if (query == null || !mounted) return;
    setState(() => _query = query);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleBooks = _visibleBooks;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.auto_stories_rounded,
                            color: theme.colorScheme.onPrimary,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Text(
                          'Lumen',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Поиск',
                          onPressed: _showSearch,
                          icon: const Icon(Icons.search_rounded),
                        ),
                        IconButton(
                          tooltip: 'Сканировать стандартные папки',
                          onPressed: _isScanning
                              ? null
                              : () => _scan(
                                  _scannerService.scanDefaultDirectories,
                                ),
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Ваша библиотека',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'PDF, EPUB, FB2, CBZ и CBR на вашем устройстве',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _isScanning
                                ? null
                                : () => _scan(
                                    _scannerService.scanDefaultDirectories,
                                  ),
                            icon: const Icon(Icons.folder_open_rounded),
                            label: const Text('Сканировать'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isScanning
                                ? null
                                : () => _scan(
                                    _scannerService.scanSelectedDirectory,
                                  ),
                            icon: const Icon(Icons.create_new_folder_outlined),
                            label: const Text('Выбрать папку'),
                          ),
                        ),
                      ],
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _errorMessage!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 26),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            'Мои издания',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${visibleBooks.length} найдено',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SegmentedButton<_LibraryFilter>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: _LibraryFilter.all,
                          label: Text('Все'),
                        ),
                        ButtonSegment(
                          value: _LibraryFilter.books,
                          label: Text('Книги'),
                        ),
                        ButtonSegment(
                          value: _LibraryFilter.comics,
                          label: Text('Комиксы'),
                        ),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (selection) =>
                          setState(() => _filter = selection.first),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            if (_isScanning)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(36),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (visibleBooks.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 42,
                  ),
                  child: Center(
                    child: Text(
                      _errorMessage == null
                          ? 'Пока ничего не найдено. Просканируйте папки или выберите свою.'
                          : 'Не удалось выполнить сканирование. Проверьте разрешение и повторите попытку.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              )
            else if (_filter == _LibraryFilter.books)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                sliver: SliverList.separated(
                  itemCount: visibleBooks.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, indent: 72),
                  itemBuilder: (context, index) =>
                      _BookTile(book: visibleBooks[index]),
                ),
              )
            else
              ..._buildLibrarySections(visibleBooks),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLibrarySections(List<BookModel> books) {
    final regularBooks = books.where((book) => !_isComic(book)).toList();
    final comicsByDirectory = <String, List<BookModel>>{};
    for (final book in books.where(_isComic)) {
      comicsByDirectory.putIfAbsent(
        File(book.path).parent.path,
        () => [],
      ).add(book);
    }

    final sections = <Widget>[];
    if (regularBooks.isNotEmpty) {
      sections.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          sliver: SliverList.separated(
            itemCount: regularBooks.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) =>
                _BookTile(book: regularBooks[index]),
          ),
        ),
      );
    }

    final directories = comicsByDirectory.keys.toList()
      ..sort((first, second) =>
          _directoryName(first).toLowerCase().compareTo(
            _directoryName(second).toLowerCase(),
          ));
    if (directories.isNotEmpty) {
      sections.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          sliver: SliverList.separated(
            itemCount: directories.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final directory = directories[index];
              final chapters = comicsByDirectory[directory]!
                ..sort(_compareChapterNames);
              return _MangaFolderTile(
                name: _directoryName(directory),
                path: directory,
                chapterCount: chapters.length,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _MangaFolderScreen(
                      name: _directoryName(directory),
                      path: directory,
                      chapters: chapters,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return sections;
  }

  static bool _isComic(BookModel book) =>
      book.extension == '.cbz' || book.extension == '.cbr';

  static String _directoryName(String path) {
    final segments = path
        .split(RegExp(r'[/\\]'))
        .where((segment) => segment.isNotEmpty);
    return segments.isEmpty ? path : segments.last;
  }

  static int _compareChapterNames(BookModel first, BookModel second) {
    final firstName = first.title.toLowerCase();
    final secondName = second.title.toLowerCase();
    final chunks = RegExp(r'\d+|\D+');
    final firstParts = chunks
        .allMatches(firstName)
        .map((match) => match.group(0)!)
        .toList();
    final secondParts = chunks
        .allMatches(secondName)
        .map((match) => match.group(0)!)
        .toList();

    for (var index = 0; index < firstParts.length && index < secondParts.length;
        index++) {
      final firstPart = firstParts[index];
      final secondPart = secondParts[index];
      final firstIsNumber = RegExp(r'^\d+$').hasMatch(firstPart);
      final secondIsNumber = RegExp(r'^\d+$').hasMatch(secondPart);
      final comparison = firstIsNumber && secondIsNumber
          ? int.parse(firstPart).compareTo(int.parse(secondPart))
          : firstPart.compareTo(secondPart);
      if (comparison != 0) return comparison;
    }
    return firstParts.length.compareTo(secondParts.length);
  }
}

class _MangaFolderTile extends StatelessWidget {
  const _MangaFolderTile({
    required this.name,
    required this.path,
    required this.chapterCount,
    required this.onTap,
  });

  final String name;
  final String path;
  final int chapterCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      leading: const SizedBox(
        width: 48,
        height: 56,
        child: Icon(Icons.folder_rounded, size: 34),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '$chapterCount глав · $path',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      isThreeLine: true,
    );
  }
}

class _MangaFolderScreen extends StatelessWidget {
  const _MangaFolderScreen({
    required this.name,
    required this.path,
    required this.chapters,
  });

  final String name;
  final String path;
  final List<BookModel> chapters;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
              child: Text(
                path,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: chapters.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, indent: 72),
                itemBuilder: (context, index) {
                  final chapter = chapters[index];
                  return _BookTile(
                    book: chapter,
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Просмотр содержимого главы пока не реализован.',
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  const _BookTile({required this.book, this.onTap});

  final BookModel book;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isComic = book.extension == '.cbz' || book.extension == '.cbr';
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      leading: Container(
        width: 48,
        height: 56,
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(
          isComic ? Icons.auto_awesome_mosaic_rounded : Icons.menu_book_rounded,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        book.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${book.extension.substring(1).toUpperCase()} · ${_formatSize(book.size)}\n${book.path}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} ГБ';
  }
}

class _LibrarySearchDelegate extends SearchDelegate<String> {
  _LibrarySearchDelegate(String initialQuery) {
    query = initialQuery;
  }

  @override
  String get searchFieldLabel => 'Название или путь';

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(
      tooltip: 'Очистить',
      onPressed: () => query = '',
      icon: const Icon(Icons.close_rounded),
    ),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    tooltip: 'Назад',
    onPressed: () => close(context, query),
    icon: const Icon(Icons.arrow_back_rounded),
  );

  @override
  Widget buildResults(BuildContext context) => const SizedBox.shrink();

  @override
  Widget buildSuggestions(BuildContext context) => ListTile(
    leading: const Icon(Icons.search_rounded),
    title: Text(query.isEmpty ? 'Искать в библиотеке' : 'Показать результаты'),
    onTap: () => close(context, query),
  );
}
