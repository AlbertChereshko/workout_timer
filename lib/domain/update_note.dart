import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'emom_timer_notifier.dart';

Future<void> saveWorkoutNote(Ref ref, String note) async {
  final notifier = ref.read(activeTimerProvider.notifier);
  if (notifier.lastSession != null) {
    notifier.lastSession!.note = note;
    notifier.lastSession!.save(); // HiveObject save
  }
}
