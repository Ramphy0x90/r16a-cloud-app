/// Mirrors `PhotoYearSummary` (`types/file.ts`; backend
/// `photo/dto/PhotoYearSummary.java`): how many of the user's own photos
/// and videos fall in a year (`takenAt`, else `createdAt`).
class PhotoYear {
  const PhotoYear({required this.year, required this.count});

  final int year;
  final int count;

  factory PhotoYear.fromJson(Map<String, dynamic> json) => PhotoYear(
    year: (json['year'] as num).toInt(),
    count: (json['count'] as num).toInt(),
  );
}
