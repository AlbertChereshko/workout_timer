import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workout_timer/core/theme.dart';
import 'package:workout_timer/data/models/workout.dart';
import 'package:workout_timer/features/workout_list/widgets/workout_search_dialog.dart';

void main() {
  testWidgets('WorkoutSearchDialog filters by workout name and exercise name', (tester) async {
    final workout1 = Workout()
      ..name = 'Здоровая Поясница'
      ..type = WorkoutType.tabata
      ..exercises = [
        Exercise()..name = 'Наклоны коленей',
        Exercise()..name = 'Кошка с уходом в позу ребенка',
      ];

    final workout2 = Workout()
      ..name = 'Силовой Верх'
      ..type = WorkoutType.emom
      ..exercises = [
        Exercise()..name = 'Отжимания с паузой',
        Exercise()..name = 'Подтягивания',
      ];

    Workout? selectedWorkout;
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkoutSearchDialog(
            workouts: [workout1, workout2],
            theme: AppThemes.neonDark,
            onSelectWorkout: (w) => selectedWorkout = w,
            onEditWorkout: (w) {},
          ),
        ),
      ),
    );

    // Initial state: both workouts visible
    expect(find.text('Здоровая Поясница'), findsOneWidget);
    expect(find.text('Силовой Верх'), findsOneWidget);

    // Search by workout name
    await tester.enterText(find.byType(TextField), 'Поясница');
    await tester.pumpAndSettle();

    expect(find.text('Здоровая Поясница'), findsOneWidget);
    expect(find.text('Силовой Верх'), findsNothing);

    // Search by exercise name
    await tester.enterText(find.byType(TextField), 'Подтягивания');
    await tester.pumpAndSettle();

    expect(find.text('Здоровая Поясница'), findsNothing);
    expect(find.text('Силовой Верх'), findsOneWidget);
    expect(find.textContaining('Подтягивания'), findsWidgets);

    // Tap to select
    await tester.tap(find.text('Силовой Верх'));
    await tester.pump();
    expect(selectedWorkout?.name, 'Силовой Верх');
  });
}
