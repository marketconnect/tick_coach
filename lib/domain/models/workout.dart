class Workout {
  final String id;
  final String title;
  final List<String> previewLines;
  final Duration totalTime;
  final int intervalsCount;
  final bool hasSettings;
  final bool hasNotes;
  final String? notes;
  final int? repeats;

  const Workout({
    required this.id,
    required this.title,
    required this.previewLines,
    required this.totalTime,
    required this.intervalsCount,
    this.hasSettings = false,
    this.hasNotes = false,
    this.notes,
    this.repeats,
  });
}
