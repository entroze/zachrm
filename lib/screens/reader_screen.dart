import 'package:flutter/material.dart';

import '../models/library_item.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.item});

  final LibraryItem item;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late int _page = widget.item.currentPage;
  double _fontSize = 20;

  void _changePage(int offset) {
    setState(() => _page = (_page + offset).clamp(1, widget.item.pageCount));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isComic = widget.item.type == LibraryItemType.comic;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Назад в библиотеку',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
            Text(
              isComic
                  ? 'Страница $_page из ${widget.item.pageCount}'
                  : 'Глава 03 · Пробуждение',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Настройки текста',
            onPressed: _showTextSettings,
            icon: const Icon(Icons.text_fields_rounded),
          ),
          IconButton(
            tooltip: 'Закладка',
            onPressed: () {},
            icon: const Icon(Icons.bookmark_border_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity < -100) _changePage(1);
                  if (velocity > 100) _changePage(-1);
                },
                child: isComic
                    ? _ComicPage(item: widget.item, page: _page)
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(30, 34, 30, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ГЛАВА 03',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Пробуждение',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontFamily: 'serif',
                                fontWeight: FontWeight.w500,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 26),
                            Text(
                              widget.item.readingSample,
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: _fontSize,
                                height: 1.75,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 22),
                            Text(
                              widget.item.description,
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: _fontSize,
                                height: 1.75,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('${(_page / widget.item.pageCount * 100).round()}%'),
                      Expanded(
                        child: Slider(
                          value: _page.toDouble(),
                          min: 1,
                          max: widget.item.pageCount.toDouble(),
                          onChanged: (value) =>
                              setState(() => _page = value.round()),
                        ),
                      ),
                      Text('$_page/${widget.item.pageCount}'),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: 'Предыдущая страница',
                        onPressed: _page > 1 ? () => _changePage(-1) : null,
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Text(
                        isComic ? 'Страница $_page' : 'Продолжить чтение',
                        style: theme.textTheme.labelLarge,
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Следующая страница',
                        onPressed: _page < widget.item.pageCount
                            ? () => _changePage(1)
                            : null,
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTextSettings() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
          child: StatefulBuilder(
            builder: (context, setSheetState) => Row(
              children: [
                const Icon(Icons.text_fields_rounded),
                const SizedBox(width: 15),
                const Expanded(child: Text('Размер текста')),
                IconButton(
                  tooltip: 'Уменьшить текст',
                  onPressed: _fontSize > 16
                      ? () {
                          setState(() => _fontSize -= 1);
                          setSheetState(() {});
                        }
                      : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                Text('${_fontSize.round()}'),
                IconButton(
                  tooltip: 'Увеличить текст',
                  onPressed: _fontSize < 28
                      ? () {
                          setState(() => _fontSize += 1);
                          setSheetState(() {});
                        }
                      : null,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComicPage extends StatelessWidget {
  const _ComicPage({required this.item, required this.page});

  final LibraryItem item;
  final int page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(22),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: item.coverColors,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SizedBox.expand(
          child: Stack(
            children: [
              Positioned(
                right: -25,
                top: 5,
                child: Icon(
                  item.coverIcon,
                  size: 230,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 26,
                child: Text(
                  item.readingSample,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 8),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 18,
                left: 18,
                child: Text(
                  '${page.toString().padLeft(2, '0')} / ${item.pageCount}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
