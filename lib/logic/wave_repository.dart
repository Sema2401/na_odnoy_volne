import 'package:cloud_firestore/cloud_firestore.dart';
import 'wave.dart';

class WaveRepository {
  /// Поток всех активных трансляций. Фильтрация и сортировка — в [WaveFilter].
  static Stream<List<Wave>> watchWaves() {
    return FirebaseFirestore.instance.collection('waves').snapshots().map(
          (snap) => snap.docs.map((doc) {
            final data = doc.data();
            final ts = data['started_at'];
            return Wave.fromMap(
              doc.id,
              data,
              startedAt: ts is Timestamp ? ts.toDate() : null,
            );
          }).toList(),
        );
  }
}
