import 'package:firebased/models/machine_history.dart';
import 'package:firebased/models/workout.dart';
import 'package:firebased/screens/workout_execution_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('execution starts with warmup only', (tester) async {
    final workout = Workout(
      id: 'workout-1',
      name: 'Treino A',
      ownerUid: 'user-1',
      machineIds: const ['supino', 'remada'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutExecutionScreen(
          workout: workout,
          machines: [
            _machine('supino', 'Supino reto'),
            _machine('remada', 'Remada baixa')
          ],
        ),
      ),
    );

    expect(find.text('Aquecimento'), findsOneWidget);
    expect(find.text('Maquinas pendentes'), findsNothing);
    expect(find.text('Remada baixa'), findsNothing);
  });

  testWidgets('completed warmup releases only the target machine',
      (tester) async {
    final workout = Workout(
      id: 'workout-1',
      name: 'Treino A',
      ownerUid: 'user-1',
      machineIds: const ['supino'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutExecutionScreen(
          workout: workout,
          machines: [_machine('supino', 'Supino reto')],
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Concluir aquecimento'));
    await tester.pumpAndSettle();

    expect(find.text('Aquecimento concluido'), findsOneWidget);
    expect(find.text('Maquinas pendentes'), findsOneWidget);
    expect(find.text('Supino reto'), findsOneWidget);
    expect(find.text('Percepcao de esforco'), findsNothing);
  });
}

MachineProfile _machine(String id, String name) {
  return MachineProfile(
    exerciseId: id,
    exerciseName: name,
    category: 'Peito',
    ownerUid: 'user-1',
    currentSets: 3,
    currentRepetitions: 12,
    currentWeightKg: 40,
  );
}
