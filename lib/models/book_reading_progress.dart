class BookReadingProgress {
  const BookReadingProgress({
    required this.currentPage,
    required this.totalPages,
  });

  final int currentPage;
  final int totalPages;

  int get percentRead =>
      totalPages == 0 ? 0 : (currentPage * 100 / totalPages).round();
}
