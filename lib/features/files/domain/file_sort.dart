/// Mirrors `SortField` (`types/file.ts`). [name] doubles as the `sort`
/// query value on the backend.
enum FileSortField {
  name,
  updatedAt;

  /// Labels from the web `file-options` menu.
  String get label => switch (this) {
    FileSortField.name => 'Name',
    FileSortField.updatedAt => 'Date',
  };
}

/// Mirrors `SortDirection` (`types/file.ts`). [name] doubles as the `dir`
/// query value on the backend.
enum FileSortDirection {
  asc,
  desc;

  FileSortDirection get flipped => this == FileSortDirection.asc
      ? FileSortDirection.desc
      : FileSortDirection.asc;
}
