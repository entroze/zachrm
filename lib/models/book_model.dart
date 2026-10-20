class BookModel {
  const BookModel({
    required this.path,
    required this.title,
    required this.extension,
    required this.size,
  });

  final String path;
  final String title;
  final String extension;
  final int size;
}
