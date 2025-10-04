enum IntervalKind { prepare, work, rest, between_sets, work_and_rest, custom }

class Interval {
  String id;
  IntervalKind kind;
  String? title;
  String? description;
  int durationSec;
  int reps;
  bool isRepsBased;
  String? imageUri;

  Interval({
    required this.id,
    required this.kind,
    this.title,
    this.description,
    required this.durationSec,
    this.reps = 10,
    this.isRepsBased = false,
    this.imageUri,
  });
}
