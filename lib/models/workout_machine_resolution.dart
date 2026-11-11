import 'machine_history.dart';
import 'workout.dart';
import '../data/exercise_catalog.dart';

List<MachineProfile> resolveWorkoutMachines(
  Workout workout,
  Map<String, MachineProfile> machinesById,
) {
  final machines = <MachineProfile>[];
  for (final id in workout.machineIds) {
    if (isSyntheticWarmupExerciseId(id)) continue;
    final machine = machinesById[id];
    if (machine != null) {
      machines.add(machine);
    }
  }
  return machines;
}

List<String> missingMachineIds(
  Workout workout,
  Map<String, MachineProfile> machinesById,
) {
  return workout.machineIds
      .where((id) => !isSyntheticWarmupExerciseId(id))
      .where((id) => !machinesById.containsKey(id))
      .toList(growable: false);
}
