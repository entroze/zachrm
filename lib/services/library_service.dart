import 'package:flutter/material.dart';

import '../models/library_item.dart';

class LibraryService {
  LibraryService({this.pageSize = 4});

  final int pageSize;

  static const _items = <LibraryItem>[
    LibraryItem(
      title: 'The Glass Orchard',
      creator: 'Mira Solen',
      type: LibraryItemType.book,
      description:
          'A botanist inherits a greenhouse where every tree holds a memory.',
      readingSample: 'The orchard was quiet in the way a room becomes quiet when someone is about to speak. Beyond the glass, the city carried on beneath a low silver sky. Inside, every branch held a small, impossible light.',
      coverColors: [Color(0xFF496348), Color(0xFFB6B47C)],
      coverIcon: Icons.local_florist_rounded,
      pageCount: 312,
      currentPage: 84,
      isCurrentlyReading: true,
    ),
    LibraryItem(
      title: 'After the Last Train',
      creator: 'N. Arda',
      type: LibraryItemType.book,
      description: 'Two strangers miss the final train and find a city that should not exist.',
      readingSample: 'At 00:17 the station clocks stopped together. Every departure board went dark, except for one line of amber lettering that neither of them had seen before.',
      coverColors: [Color(0xFF475B70), Color(0xFFB77958)],
      coverIcon: Icons.train_rounded,
      pageCount: 268,
    ),
    LibraryItem(
      title: 'Redshift, Issue 01',
      creator: 'L. Kwan',
      type: LibraryItemType.comic,
      description: 'A courier carries a message across the edge of a collapsing star system.',
      readingSample: 'The ship shuddered as the red giant filled the forward glass. “Package first,” Ivo said, reaching for the manual release. “Panic after.”',
      coverColors: [Color(0xFF9D4E40), Color(0xFFE2A45E)],
      coverIcon: Icons.auto_awesome_rounded,
      pageCount: 42,
    ),
    LibraryItem(
      title: 'Atlas of Quiet Places',
      creator: 'I. Moreno',
      type: LibraryItemType.book,
      description: 'An illustrated field guide to places that make room for a slower life.',
      readingSample: 'There is a footpath above the harbor that locals use only at dawn. It has no sign, no name, and a view that belongs to whoever arrives first.',
      coverColors: [Color(0xFF53716B), Color(0xFFD0B878)],
      coverIcon: Icons.explore_rounded,
      pageCount: 196,
    ),
    LibraryItem(
      title: 'Neon Saints, Issue 04',
      creator: 'K. Aoki',
      type: LibraryItemType.comic,
      description: 'The night shift at a city shrine is about to get stranger.',
      readingSample: 'Rain turned the alley signs into long ribbons of color. Mina counted the bells again. There were seven at the gate yesterday. Tonight, there were eight.',
      coverColors: [Color(0xFF784D75), Color(0xFFE27665)],
      coverIcon: Icons.bolt_rounded,
      pageCount: 38,
    ),
    LibraryItem(
      title: 'The Deep Archive',
      creator: 'Tomas Vale',
      type: LibraryItemType.book,
      description: 'A conservator discovers a collection of letters addressed to the future.',
      readingSample: 'The archive had been sealed for forty years. On the desk, a single envelope waited with tomorrow’s date written in a careful hand.',
      coverColors: [Color(0xFF4F5E70), Color(0xFFB59B72)],
      coverIcon: Icons.menu_book_rounded,
      pageCount: 344,
    ),
  ];

  Future<List<LibraryItem>> loadPage(int page) async {
    await Future<void>.delayed(const Duration(milliseconds: 320));
    final start = page * pageSize;
    if (start >= _items.length) return const [];
    final end = (start + pageSize).clamp(0, _items.length);
    return _items.sublist(start, end);
  }
}
