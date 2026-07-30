class RetroCrtSettings {
  const RetroCrtSettings({
    required this.scanlineOpacity,
    required this.vignetteOpacity,
    required this.glowOpacity,
    required this.noiseOpacity,
    required this.sweepOpacity,
  });

  final double scanlineOpacity;
  final double vignetteOpacity;
  final double glowOpacity;
  final double noiseOpacity;
  final double sweepOpacity;

  factory RetroCrtSettings.fromIntensity(double intensity) {
    final value = intensity.clamp(0.0, 1.0);
    return RetroCrtSettings(
      scanlineOpacity: 0.12 * value,
      vignetteOpacity: 0.30 * value,
      glowOpacity: 0.15 * value,
      noiseOpacity: 0.04 * value,
      sweepOpacity: 0.10 * value,
    );
  }
}
