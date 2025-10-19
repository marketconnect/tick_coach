import 'package:tick_coach/domain/models/training_session.dart';

abstract class WorkoutRepository {
  Future<void> saveTrainingSession(TrainingSession session);
  Future<TrainingSession?> getTrainingSession(String sessionId);
  Future<List<Map<String, dynamic>>> getAllTrainingSessions();
  Future<void> updateTrainingSessionNotes(String sessionId, String notes);
  Future<void> deleteTrainingSession(String sessionId);
}
