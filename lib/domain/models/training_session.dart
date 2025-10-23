class TrainingSession {
  String id;
  String name;
  String? notes;
  String? workoutType; // 'standard' or 'rounds'
  String? roundsConfigJson;
  List<Block> blocks;

  TrainingSession({
    required this.id,
    required this.name,
    this.notes,
    this.workoutType,
    this.roundsConfigJson,
    List<Block>? blocks,
  }) : blocks = blocks ?? [];

  // copyWith
  TrainingSession copyWith({
    String? id,
    String? name,
    String? notes,
    List<Block>? blocks,
    String? workoutType,
    String? roundsConfigJson,
  }) {
    return TrainingSession(
      id: id ?? this.id,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      blocks: blocks ?? List.from(this.blocks),
      workoutType: workoutType ?? this.workoutType,
      roundsConfigJson: roundsConfigJson ?? this.roundsConfigJson,
    );
  }
}

class Block {
  String id;
  String type;
  String? label;
  List<Set> sets;
  Block({required this.id, required this.type, this.label, List<Set>? sets})
    : sets = sets ?? [];
}

class Set {
  String id;
  int repeat;
  String? label;
  List<SetItem> items;

  Set({required this.id, this.repeat = 1, this.label, List<SetItem>? items})
    : items = items ?? [];
}

abstract class SetItem {
  String id;
  SetItem({required this.id});
  SetItem copyWith({String? id});
}

class Exercise extends SetItem {
  String name;
  String? modality;
  String? equipment;
  int reps;
  double? loadKg;
  String? tempo;
  List<Repetition> repetitions;
  List<Hold> holds;
  bool isRepsBased;
  int durationSec;
  String? imageUri;

  Exercise({
    required super.id,
    required this.name,
    this.reps = 10,
    this.isRepsBased = true,
    this.durationSec = 30,
    this.modality,
    this.equipment,
    this.loadKg,
    this.tempo,
    this.repetitions = const [],
    this.holds = const [],
    this.imageUri,
  });

  @override
  Exercise copyWith({
    String? id,
    String? name,
    int? reps,
    bool? isRepsBased,
    int? durationSec,
    String? modality,
    String? equipment,
    double? loadKg,
    String? tempo,
    String? imageUri,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      reps: reps ?? this.reps,
      isRepsBased: isRepsBased ?? this.isRepsBased,
      durationSec: durationSec ?? this.durationSec,
      modality: modality ?? this.modality,
      equipment: equipment ?? this.equipment,
      loadKg: loadKg ?? this.loadKg,
      tempo: tempo ?? this.tempo,
      repetitions: List.from(repetitions),
      holds: List.from(holds),
      imageUri: imageUri ?? this.imageUri,
    );
  }
}

class Rest extends SetItem {
  int durationSec;
  String? reason;

  Rest({required super.id, required this.durationSec, this.reason});

  @override
  Rest copyWith({String? id, int? durationSec, String? reason}) {
    return Rest(
      id: id ?? this.id,
      durationSec: durationSec ?? this.durationSec,
      reason: reason ?? this.reason,
    );
  }
}

class Repetition {
  int? index;
  Repetition({this.index});
  Map<String, dynamic> toJson() => {'index': index};
}

class Hold {
  int durationSec;
  Hold({required this.durationSec});
  Map<String, dynamic> toJson() => {'duration_sec': durationSec};
}

extension SetItemExtension on SetItem {
  SetItem copyWith({String? id}) {
    if (this is Exercise) {
      return (this as Exercise).copyWith(id: id);
    } else if (this is Rest) {
      return (this as Rest).copyWith(id: id);
    }
    throw UnsupportedError('Unknown SetItem type');
  }
}

extension SetExtension on Set {
  Set copyWith({String? id, int? repeat, String? label, List<SetItem>? items}) {
    return Set(
      id: id ?? this.id,
      repeat: repeat ?? this.repeat,
      label: label ?? this.label,
      items: items ?? List.from(this.items),
    );
  }
}

extension BlockExtension on Block {
  Block copyWith({String? id, String? type, String? label, List<Set>? sets}) {
    return Block(
      id: id ?? this.id,
      type: type ?? this.type,
      label: label ?? this.label,
      sets: sets ?? List.from(this.sets),
    );
  }
}
