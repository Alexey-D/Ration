import 'package:flutter_test/flutter_test.dart';
import 'package:ration_planner/data/repository.dart';
import 'package:ration_planner/domain/models.dart';

void main() {
  test('тренировки: запись и чтение столбца profile.trainings', () {
    const list = [
      TrainingSession(activityCode: '02074', minutes: 30),
      TrainingSession(activityCode: '17200', minutes: 45),
    ];
    expect(encodeTrainings(list), '02074:30;17200:45');
    expect(decodeTrainings('02074:30;17200:45'), list);
  });

  test('пустое или испорченное значение — null (берутся старые столбцы)', () {
    expect(decodeTrainings(null), isNull);
    expect(decodeTrainings(''), isNull);
    expect(decodeTrainings('02074'), isNull);
    expect(decodeTrainings('02074:abc'), isNull);
  });
}
