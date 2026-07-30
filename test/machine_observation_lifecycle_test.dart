import 'dart:async';

import 'package:firebased/models/machine_history.dart';
import 'package:firebased/screens/machine_history_screen.dart';
import 'package:firebased/services/machine_history_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('machine observation lifecycle', () {
    testWidgets('saves OBS after dialog closes and rebuilds without exceptions',
        (tester) async {
      final service = FakeMachineService(
        initial: _machine(observation: 'Antiga'),
      );
      await _pumpDetail(tester, service);

      await tester.tap(find.byIcon(Icons.notes));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Nova OBS');
      await tester.tap(find.text('Salvar OBS'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      await tester.pumpAndSettle();

      expect(service.updateCalls, 1);
      expect(service.lastObservation, 'Nova OBS');
      expect(find.text('OBS: Nova OBS'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('canceling OBS dialog does not write', (tester) async {
      final service = FakeMachineService(
        initial: _machine(observation: 'Antiga'),
      );
      await _pumpDetail(tester, service);

      await tester.tap(find.byIcon(Icons.notes));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(service.updateCalls, 0);
      expect(find.text('OBS: Antiga'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'clearing OBS writes empty value and legacy fallback does not return',
        (tester) async {
      final service = FakeMachineService(
        initial: _machine(observation: 'Legada'),
      );
      await _pumpDetail(tester, service);

      await tester.tap(find.byIcon(Icons.notes));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Salvar OBS'));
      await tester.pumpAndSettle();

      expect(service.lastObservation, '');
      expect(find.text('OBS: Sem OBS'), findsOneWidget);
      expect(tester.takeException(), isNull);

      final canonical = _machine(observation: '');
      expect(canonical.observation, '');
    });

    testWidgets('service error closes dialog and keeps screen usable',
        (tester) async {
      final service = FakeMachineService(
        initial: _machine(observation: 'Antiga'),
        throwOnUpdate: true,
      );
      await _pumpDetail(tester, service);

      await tester.tap(find.byIcon(Icons.notes));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Falha');
      await tester.tap(find.text('Salvar OBS'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Erro ao salvar OBS. Tente novamente.'), findsOneWidget);
      expect(find.byIcon(Icons.notes), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'disposing screen during OBS write does not call setState later',
        (tester) async {
      final completer = Completer<void>();
      final service = FakeMachineService(
        initial: _machine(observation: 'Antiga'),
        updateCompleter: completer,
      );
      await _pumpDetail(tester, service);

      await tester.tap(find.byIcon(Icons.notes));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Depois');
      await tester.tap(find.text('Salvar OBS'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      completer.complete();
      await tester.pumpAndSettle();

      expect(service.lastObservation, 'Depois');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'legacy machine materializes canonical update preserving counter',
        (tester) async {
      final service = FakeMachineService(
        initial: _machine(observation: 'Legada', completionCount: 8),
      );
      await _pumpDetail(tester, service);

      await tester.tap(find.byIcon(Icons.notes));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Canonica');
      await tester.tap(find.text('Salvar OBS'));
      await tester.pumpAndSettle();

      expect(service.current.completionCount, 8);
      expect(service.current.observation, 'Canonica');
      expect(find.text('Realizado: 8 vezes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _pumpDetail(
  WidgetTester tester,
  FakeMachineService service,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MachineDetailScreen(
        ownerUid: 'user-1',
        exerciseId: 'supino_simples',
        service: service,
      ),
    ),
  );
  service.emitCurrent();
  await tester.pumpAndSettle();
}

MachineProfile _machine({
  String? observation,
  int completionCount = 2,
}) {
  return MachineProfile(
    exerciseId: 'supino_simples',
    exerciseName: 'Supino Simples',
    category: 'Peito',
    ownerUid: 'user-1',
    completionCount: completionCount,
    observation: observation,
    lastIncrease: MachineIncrease(
      type: MachineIncreaseType.weight,
      value: 40,
      date: DateTime(2026, 7, 1),
    ),
  );
}

class FakeMachineService extends MachineService {
  FakeMachineService({
    required MachineProfile initial,
    this.throwOnUpdate = false,
    this.updateCompleter,
  })  : current = initial,
        super();

  final _controller = StreamController<MachineProfile?>.broadcast();
  final bool throwOnUpdate;
  final Completer<void>? updateCompleter;
  MachineProfile current;
  int updateCalls = 0;
  String? lastObservation;

  void emitCurrent() {
    _controller.add(current);
  }

  @override
  Stream<MachineProfile?> watchByExerciseId(
    String ownerUid,
    String exerciseId,
  ) {
    return _controller.stream;
  }

  @override
  Future<void> updateObservation({
    required String ownerUid,
    required String exerciseId,
    required String exerciseName,
    required String category,
    required String observation,
  }) async {
    updateCalls++;
    lastObservation = observation;
    await updateCompleter?.future;
    if (throwOnUpdate) {
      throw Exception('offline');
    }
    current = current.copyWith(
      exerciseName: exerciseName,
      category: category,
      observation: observation,
    );
    _controller.add(current);
  }
}
