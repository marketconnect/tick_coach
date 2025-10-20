import 'dart:convert';

class RoundsConfig {
  int roundCount;
  int roundTimeSec;
  int restTimeSec;
  int prepareTimeSec;
  int endOfRoundSignalSec;
  int inRoundSignalPeriodSec;

  RoundsConfig({
    this.roundCount = 3,
    this.roundTimeSec = 180, // 3 minutes
    this.restTimeSec = 60, // 1 minute
    this.prepareTimeSec = 10,
    this.endOfRoundSignalSec = 10,
    this.inRoundSignalPeriodSec = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'roundCount': roundCount,
      'roundTimeSec': roundTimeSec,
      'restTimeSec': restTimeSec,
      'prepareTimeSec': prepareTimeSec,
      'endOfRoundSignalSec': endOfRoundSignalSec,
      'inRoundSignalPeriodSec': inRoundSignalPeriodSec,
    };
  }

  factory RoundsConfig.fromJson(Map<String, dynamic> json) {
    return RoundsConfig(
      roundCount: json['roundCount'] ?? 3,
      roundTimeSec: json['roundTimeSec'] ?? 180,
      restTimeSec: json['restTimeSec'] ?? 60,
      prepareTimeSec: json['prepareTimeSec'] ?? 10,
      endOfRoundSignalSec: json['endOfRoundSignalSec'] ?? 10,
      inRoundSignalPeriodSec: json['inRoundSignalPeriodSec'] ?? 0,
    );
  }

  factory RoundsConfig.fromJsonString(String jsonString) {
    if (jsonString.isEmpty) {
      return RoundsConfig();
    }
    return RoundsConfig.fromJson(jsonDecode(jsonString));
  }
}