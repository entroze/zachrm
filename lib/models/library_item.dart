import 'package:flutter/material.dart';

enum LibraryItemType { book, comic }

class LibraryItem {
  const LibraryItem({
    required this.title,
    required this.creator,
    required this.type,
    required this.description,
    required this.readingSample,
    required this.coverColors,
    required this.coverIcon,
    required this.pageCount,
    this.currentPage = 1,
    this.isCurrentlyReading = false,
  });

  final String title;
  final String creator;
  final LibraryItemType type;
  final String description;
  final String readingSample;
  final List<Color> coverColors;
  final IconData coverIcon;
  final int pageCount;
  final int currentPage;
  final bool isCurrentlyReading;

  double get progress => currentPage / pageCount;
}
