import 'machine_history.dart';
import 'workout.dart';

List<MachineProfile> resolveWorkoutMachines(
  Workout workout,
  Map<String, MachineProfile> machinesById,
) {
  final machines = <MachineProfile>[];
  for (final id in workout.machineIds) {
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
      .where((id) => !machinesById.containsKey(id))
      .toList(growable: false);
}
