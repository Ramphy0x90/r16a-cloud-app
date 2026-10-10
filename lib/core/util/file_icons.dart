/// Port of the web client's `IconFromExtensionPipe`.
const _imageExtensions = {
  'jpg',
  'jpeg',
  'png',
  'gif',
  'webp',
  'svg',
  'avif',
  'tiff',
  'heic',
  'heif',
  'bmp',
};
const _videoExtensions = {'mp4', 'mov', 'avi', 'wmv', 'mkv', 'webm', 'm4v'};
const _audioExtensions = {'mp3', 'aac', 'ogg', 'wma', 'm4a', 'ra', 'opus'};

String iconForFileName(String fileName) {
  final dot = fileName.lastIndexOf('.');
  final extension = dot == -1 ? '' : fileName.substring(dot + 1).toLowerCase();

  if (_imageExtensions.contains(extension)) {
    return 'assets/icons/photo.svg';
  }

  if (_videoExtensions.contains(extension)) {
    return 'assets/icons/movie.svg';
  }

  if (_audioExtensions.contains(extension)) {
    return 'assets/icons/headphones.svg';
  }

  return 'assets/icons/file.svg';
}
