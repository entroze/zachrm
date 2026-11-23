class BookModel {
  const BookModel({
    required this.path,
    required this.title,
    required this.extension,
    required this.size,
    this.isContentUri = false,
    this.isImageFolder = false,
  });

  final String path;
  final String title;
  final String extension;
  final int size;
  final bool isContentUri;
  final bool isImageFolder;

  bool get isAndroidContentUri => isContentUri && path.startsWith('content://');
  bool get isComicArchive =>
      extension == '.cbz' || extension == '.cbr' || extension == '.zip';
  bool get isImageFile => isImageFolder;
}
