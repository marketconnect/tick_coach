import 'package:tick_coach/data/datasources/database_helper.dart';
import 'package:tick_coach/domain/models/training_session.dart';
import 'package:tick_coach/domain/repositories/workout_repository.dart';

class WorkoutRepositoryImpl implements WorkoutRepository {
  final DatabaseHelper _databaseHelper;

  WorkoutRepositoryImpl(this._databaseHelper);

  @override
  Future<void> deleteTrainingSession(String sessionId) {
    return _databaseHelper.deleteTrainingSession(sessionId);
  }

  @override
  Future<List<Map<String, dynamic>>> getAllTrainingSessions() {
    return _databaseHelper.getAllTrainingSessions();
  }

  @override
  Future<TrainingSession?> getTrainingSession(String sessionId) {
    return _databaseHelper.getTrainingSession(sessionId);
  }

  @override
  Future<void> saveTrainingSession(TrainingSession session) {
    return _databaseHelper.saveTrainingSession(session);
  }

  @override
  Future<void> updateTrainingSessionNotes(String sessionId, String notes) {
    return _databaseHelper.updateTrainingSessionNotes(sessionId, notes);
  }
}
