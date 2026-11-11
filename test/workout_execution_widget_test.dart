import 'package:firebased/app/appearance/app_appearance_controller.dart';
import 'package:firebased/app/appearance/app_appearance_mode.dart';
import 'package:firebased/app/appearance/app_appearance_overlay.dart';
import 'package:firebased/app/appearance/app_appearance_scope.dart';
import 'package:firebased/app/appearance/app_theme_factory.dart';
import 'package:firebased/app/appearance/retro/retro_colors.dart';
import 'package:firebased/app/appearance/retro/retro_crt_overlay.dart';
import 'package:firebased/app/appearance/standard_app_theme.dart';
import 'package:firebased/models/machine_history.dart';
import 'package:firebased/models/workout.dart';
import 'package:firebased/models/workout_execution_flow.dart';
import 'package:firebased/models/workout_session.dart';
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
      _executionApp(
        workout: workout,
        machines: [
          _machine('supino', 'Supino reto'),
          _machine('remada', 'Remada baixa')
        ],
      ),
    );

    expect(find.text('Aquecimento'), findsOneWidget);
    expect(find.text('Maquinas pendentes'), findsNothing);
    expect(find.text('Remada baixa'), findsNothing);
  });

  testWidgets('completed warmup focuses only the first pending exercise',
      (tester) async {
    final workout = Workout(
      id: 'workout-1',
      name: 'Treino A',
      ownerUid: 'user-1',
      machineIds: const ['supino'],
    );

    await tester.pumpWidget(
      _executionApp(
        workout: workout,
        machines: [_machine('supino', 'Supino reto')],
      ),
    );

    await _completeWarmup(tester);

    expect(find.text('Aquecimento concluido'), findsNothing);
    expect(find.text('Escolha o proximo exercicio'), findsNothing);
    expect(find.text('Supino reto'), findsOneWidget);
    expect(find.text('Concluir exercicio'), findsOneWidget);
    expect(find.text('PROGRESSO DO TREINO'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.textContaining('Configuracao atual'), findsNothing);
    expect(find.text('Percepcao de esforco'), findsNothing);
  });

  testWidgets('after completing focused exercise user chooses remaining one',
      (tester) async {
    final workout = Workout(
      id: 'workout-1',
      name: 'Treino A',
      ownerUid: 'user-1',
      machineIds: const ['supino', 'remada'],
    );

    await tester.pumpWidget(
      _executionApp(
        workout: workout,
        machines: [
          _machine('supino', 'Supino reto'),
          _machine('remada', 'Remada baixa')
        ],
      ),
    );

    await _completeWarmup(tester, target: 'Supino reto');
    await _completeFocusedExercise(tester);

    expect(find.text('Escolha o proximo exercicio'), findsOneWidget);
    expect(find.text('PROGRESSO DO TREINO'), findsOneWidget);
    expect(find.text('Exercicio concluido'), findsOneWidget);
    expect(find.text('Iniciar exercicio'), findsOneWidget);
  });

  testWidgets('retro current exercise name uses high contrast style',
      (tester) async {
    const exerciseName = 'Puxada alta com a barra em pegada aberta controlada';
    final workout = Workout(
      id: 'workout-1',
      name: 'Treino A',
      ownerUid: 'user-1',
      machineIds: const ['puxada'],
    );

    await tester.pumpWidget(
      _executionApp(
        workout: workout,
        machines: [_machine('puxada', exerciseName)],
        theme: AppThemeFactory.build(AppAppearanceMode.retro),
      ),
    );

    await _completeWarmup(tester);

    final text = tester.widget<Text>(find.text(exerciseName));
    expect(text.style?.color, RetroColors.amberLight);
    expect(text.style?.fontWeight, FontWeight.w800);
    expect(text.softWrap, isTrue);
  });

  testWidgets('retro completed exercise card keeps dark completed surface',
      (tester) async {
    final workout = Workout(
      id: 'workout-1',
      name: 'Treino A',
      ownerUid: 'user-1',
      machineIds: const ['supino', 'remada'],
    );

    await tester.pumpWidget(
      _executionApp(
        workout: workout,
        machines: [
          _machine('supino', 'Supino reto'),
          _machine('remada', 'Remada baixa'),
        ],
        theme: AppThemeFactory.build(AppAppearanceMode.retro),
      ),
    );

    await _completeWarmup(tester, target: 'Supino reto');
    await _completeFocusedExercise(tester);

    final statusFinder = find.text('STATUS // CONCLUIDO');
    expect(statusFinder, findsOneWidget);

    final card = tester.widget<Card>(
      find.ancestor(of: statusFinder, matching: find.byType(Card)).first,
    );
    expect(card.color, RetroColors.surfaceAlternative);

    final shape = card.shape;
    expect(shape, isA<RoundedRectangleBorder>());
    expect((shape! as RoundedRectangleBorder).side.color, RetroColors.amber);
  });

  testWidgets('warmup summary hides while a normal exercise is selected',
      (tester) async {
    final workout = Workout(
      id: 'workout-1',
      name: 'Treino A',
      ownerUid: 'user-1',
      machineIds: const ['supino', 'remada'],
    );

    await tester.pumpWidget(
      _executionApp(
        workout: workout,
        machines: [
          _machine('supino', 'Supino reto'),
          _machine('remada', 'Remada baixa'),
        ],
      ),
    );

    expect(find.text('Aquecimento'), findsOneWidget);

    await _completeWarmup(tester, target: 'Supino reto');
    expect(find.text('Aquecimento concluido'), findsNothing);
    expect(find.text('Concluir exercicio'), findsOneWidget);

    await _completeFocusedExercise(tester);
    expect(find.text('PROGRESSO DO TREINO'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar exercicio'));
    await tester.pumpAndSettle();

    expect(find.text('Aquecimento concluido'), findsNothing);
    expect(find.text('Remada baixa'), findsOneWidget);
    expect(find.text('Concluir exercicio'), findsOneWidget);
  });

  testWidgets('standard execution remains functional after HUD styling',
      (tester) async {
    final workout = Workout(
      id: 'workout-1',
      name: 'Treino A',
      ownerUid: 'user-1',
      machineIds: const ['supino'],
    );

    await tester.pumpWidget(
      _executionApp(
        workout: workout,
        machines: [_machine('supino', 'Supino reto')],
        theme: StandardAppTheme.data(),
      ),
    );

    await _completeWarmup(tester);

    final text = tester.widget<Text>(find.text('Supino reto'));
    expect(text.style?.color, StandardAppTheme.data().colorScheme.onSurface);
    expect(find.text('Concluir exercicio'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('exercise card shows accessible goal reached indicator',
      (tester) async {
    final workout = Workout(
      id: 'workout-1',
      name: 'Treino A',
      ownerUid: 'user-1',
      machineIds: const ['supino'],
    );

    await tester.pumpWidget(
      _executionApp(
        workout: workout,
        machines: [_machine('supino', 'Supino reto')],
      ),
    );

    await _completeWarmup(tester);
    expect(find.text('META ALCANCADA'), findsNothing);

    await _addFocusedSet(tester);
    await _addFocusedSet(tester);
    await _addFocusedSet(tester);

    expect(find.text('META ALCANCADA'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });

  testWidgets('focused exercise card hides noisy actions and shows OBS',
      (tester) async {
    final workout = Workout(
      id: 'workout-1',
      name: 'Treino A',
      ownerUid: 'user-1',
      machineIds: const ['supino'],
    );

    await tester.pumpWidget(
      _executionApp(
        workout: workout,
        machines: [_machine('supino', 'Supino reto')],
      ),
    );

    await _completeWarmup(tester);

    expect(find.text('Editar configuracao'), findsNothing);
    expect(find.textContaining('Nenhuma serie registrada'), findsNothing);
    expect(find.textContaining('Volume:'), findsNothing);
    expect(find.textContaining('Series registradas:'), findsNothing);
    expect(find.text('OBS'), findsOneWidget);
    expect(find.text('Concluir exercicio'), findsOneWidget);
  });

  testWidgets('focused exercise card does not invent a modification',
      (tester) async {
    final workout = Workout(
      id: 'workout-1',
      name: 'Treino A',
      ownerUid: 'user-1',
      machineIds: const ['supino'],
    );

    await tester.pumpWidget(
      _executionApp(
        workout: workout,
        machines: [
          _machine(
            'supino',
            'Supino reto',
            lastIncrease: MachineIncrease(
              type: MachineIncreaseType.weight,
              value: 45.5,
              date: DateTime(2026, 7, 28),
            ),
            previousIncrease: MachineIncrease(
              type: MachineIncreaseType.repetitions,
              value: 10,
              date: DateTime(2026, 7, 20),
            ),
          ),
        ],
      ),
    );

    await _completeWarmup(tester);

    expect(find.text('Ul_Mod: --'), findsOneWidget);
  });

  testWidgets('restored session keeps canonical progress on a narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final machines = [
      _machine('a', 'A'),
      _machine('b', 'B'),
      _machine('c', 'C'),
      _machine('d', 'D'),
    ];
    final workout = Workout(
      id: 'workout-1',
      name: 'Treino A',
      ownerUid: 'user-1',
      machineIds: const ['a', 'b', 'c', 'd'],
    );
    final session = WorkoutSession(
      workoutId: workout.id!,
      workoutName: workout.name,
      ownerUid: workout.ownerUid,
      status: WorkoutSessionStatus.inProgress,
      executionPhase: 'choosingNextExercise',
      exercises: [
        createWarmupExecution(completed: true),
        for (var index = 0; index < machines.length; index++)
          ExerciseExecution(
            exerciseId: machines[index].exerciseId,
            exerciseName: machines[index].exerciseName,
            sets: const [],
            completed: index < 3,
            status: index < 3 ? ExerciseExecutionStatus.completed : null,
          ),
      ],
    );

    await tester.pumpWidget(
      _executionApp(
        workout: workout,
        machines: machines,
        initialSession: session,
      ),
    );
    await tester.pump();

    expect(find.text('75%'), findsOneWidget);
    expect(find.text('Aquecimento concluido'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('set dialog uses steppers and records visible values',
      (tester) async {
    final workout = Workout(
      id: 'workout-1',
      name: 'Treino A',
      ownerUid: 'user-1',
      machineIds: const ['supino'],
    );

    await tester.pumpWidget(
      _executionApp(
        workout: workout,
        machines: [_machine('supino', 'Supino reto', weightKg: 40.5)],
      ),
    );

    await _completeWarmup(tester);
    await tester.tap(find.text('Adicionar serie'));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('40,5 kg'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);

    await tester.tap(find.byTooltip('Aumentar peso'));
    await tester.pump();
    expect(find.text('41,5 kg'), findsOneWidget);
    expect(find.textContaining('Serie 1:'), findsNothing);

    await tester.tap(find.byTooltip('Diminuir repeticoes'));
    await tester.pump();
    expect(find.text('11'), findsOneWidget);

    await tester.tap(find.text('Adicionar'));
    await tester.pumpAndSettle();

    expect(find.text('Serie 1: 11 reps, 41,5 kg'), findsOneWidget);
  });

  testWidgets('set steppers do not allow negative values', (tester) async {
    final workout = Workout(
      id: 'workout-1',
      name: 'Treino A',
      ownerUid: 'user-1',
      machineIds: const ['supino'],
    );

    await tester.pumpWidget(
      _executionApp(
        workout: workout,
        machines: [_machine('supino', 'Supino reto', reps: 0, weightKg: 0)],
      ),
    );

    await _completeWarmup(tester);
    await tester.tap(find.text('Adicionar serie'));
    await tester.pumpAndSettle();

    expect(find.text('0 kg'), findsOneWidget);
    final decreaseWeight = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '-').first,
    );
    expect(decreaseWeight.onPressed, isNull);
    expect(find.text('-1'), findsNothing);
  });

  testWidgets('maximum CRT overlay does not block workout interaction',
      (tester) async {
    final workout = Workout(
      id: 'workout-1',
      name: 'Treino A',
      ownerUid: 'user-1',
      machineIds: const ['supino'],
    );
    final appearance = AppAppearanceController(defaultCrtIntensity: 1);

    await tester.pumpWidget(
      AppAppearanceScope(
        controller: appearance,
        child: MaterialApp(
          theme: AppThemeFactory.build(AppAppearanceMode.retro),
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: AppAppearanceOverlay(
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: WorkoutExecutionScreen(
            workout: workout,
            machines: [_machine('supino', 'Supino reto')],
          ),
        ),
      ),
    );

    expect(find.byType(RetroCrtOverlay), findsOneWidget);

    await _completeWarmup(tester);

    expect(find.text('Concluir exercicio'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _executionApp({
  required Workout workout,
  required List<MachineProfile> machines,
  ThemeData? theme,
  WorkoutSession? initialSession,
}) {
  return MaterialApp(
    theme: theme,
    home: WorkoutExecutionScreen(
      workout: workout,
      machines: machines,
      initialSession: initialSession,
    ),
  );
}

Future<void> _completeWarmup(WidgetTester tester, {String? target}) async {
  if (target != null) {
    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await tester.pumpAndSettle();
    await tester.tap(find.text(target).last);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Adicionar'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Concluir aquecimento'));
  await tester.pumpAndSettle();
}

Future<void> _completeFocusedExercise(WidgetTester tester) async {
  await _addFocusedSet(tester);
  await tester.tap(find.text('Concluir exercicio'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Adequado'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Concluir maquina'));
  await tester.pumpAndSettle();
}

Future<void> _addFocusedSet(WidgetTester tester) async {
  await tester.tap(find.text('Adicionar serie'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Adicionar'));
  await tester.pumpAndSettle();
}

MachineProfile _machine(
  String id,
  String name, {
  int reps = 12,
  double weightKg = 40,
  MachineIncrease? lastIncrease,
  MachineIncrease? previousIncrease,
}) {
  return MachineProfile(
    exerciseId: id,
    exerciseName: name,
    category: 'Peito',
    ownerUid: 'user-1',
    currentSets: 3,
    currentRepetitions: reps,
    currentWeightKg: weightKg,
    lastIncrease: lastIncrease,
    previousIncrease: previousIncrease,
  );
}
