import 'dart:math' as math;

/// Single timed pass/system scope recorded during a frame.
final class TelemetrySpan {
  final String name;
  final double durationMs;
  final int depth;

  const TelemetrySpan({
    required this.name,
    required this.durationMs,
    this.depth = 0,
  });
}

/// Aggregated rolling window statistics over recent frame durations.
final class FrameTelemetryStats {
  final int sampleCount;
  final double lastMs;
  final double meanMs;
  final double p95Ms;
  final double p99Ms;
  final double maxMs;
  final double budgetHitRate;

  const FrameTelemetryStats({
    required this.sampleCount,
    required this.lastMs,
    required this.meanMs,
    required this.p95Ms,
    required this.p99Ms,
    required this.maxMs,
    required this.budgetHitRate,
  });
}

/// Rolling-window frame profiler and scoped pass timing counter.
final class FrameTelemetryRecorder {
  final int windowSize;
  final double budgetMs;
  final List<double> _frameSamples = [];
  final List<TelemetrySpan> _lastFrameSpans = [];
  final Map<String, double> _accumulatedScopeMs = {};
  int _totalFramesRecorded = 0;

  FrameTelemetryRecorder({
    this.windowSize = 120,
    this.budgetMs = 16.6667,
  });

  int get totalFramesRecorded => _totalFramesRecorded;
  List<TelemetrySpan> get lastFrameSpans => List.unmodifiable(_lastFrameSpans);
  Map<String, double> get lastScopeTotalsMs => Map.unmodifiable(_accumulatedScopeMs);

  void recordFrame({
    required double totalFrameMs,
    List<TelemetrySpan> spans = const [],
  }) {
    _totalFramesRecorded++;
    _frameSamples.add(math.max(0.0, totalFrameMs));
    final cap = math.max(1, windowSize);
    while (_frameSamples.length > cap) {
      _frameSamples.removeAt(0);
    }

    _lastFrameSpans
      ..clear()
      ..addAll(spans);
    _accumulatedScopeMs.clear();
    for (final s in spans) {
      _accumulatedScopeMs[s.name] =
          (_accumulatedScopeMs[s.name] ?? 0.0) + math.max(0.0, s.durationMs);
    }
  }

  FrameTelemetryStats computeStats() {
    if (_frameSamples.isEmpty) {
      return const FrameTelemetryStats(
        sampleCount: 0,
        lastMs: 0.0,
        meanMs: 0.0,
        p95Ms: 0.0,
        p99Ms: 0.0,
        maxMs: 0.0,
        budgetHitRate: 1.0,
      );
    }
    var sum = 0.0;
    var maxV = 0.0;
    var withinBudget = 0;
    for (final v in _frameSamples) {
      sum += v;
      if (v > maxV) maxV = v;
      if (v <= budgetMs) withinBudget++;
    }
    final sorted = List<double>.from(_frameSamples)..sort();
    final idx95 = ((sorted.length - 1) * 0.95).round().clamp(0, sorted.length - 1);
    final idx99 = ((sorted.length - 1) * 0.99).round().clamp(0, sorted.length - 1);

    return FrameTelemetryStats(
      sampleCount: _frameSamples.length,
      lastMs: _frameSamples.last,
      meanMs: sum / _frameSamples.length,
      p95Ms: sorted[idx95],
      p99Ms: sorted[idx99],
      maxMs: maxV,
      budgetHitRate: withinBudget / _frameSamples.length,
    );
  }
}
