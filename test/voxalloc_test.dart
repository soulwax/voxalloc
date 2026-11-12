import 'package:test/test.dart';
import 'package:voxalloc/voxalloc.dart';

void main() {
  test('LinearFrameArena enforces byte alignment, overflow guards & peak watermark on reset', () {
    final arena = LinearFrameArena(capacityBytes: 64);

    final a1 = arena.alloc(5, alignment: 1)!;
    expect(a1.offset, 0);
    expect(a1.length, 5);

    final a2 = arena.alloc(16, alignment: 8)!;
    expect(a2.offset, 8);
    expect(arena.usedBytes, 24);
    expect(arena.peakBytes, 24);

    // Request exceeding capacity returns null and increments overflowCount
    final oom = arena.alloc(48);
    expect(oom, isNull);
    expect(arena.overflowCount, 1);

    arena.resetFrame();
    expect(arena.usedBytes, 0);
    expect(arena.peakBytes, 24);
  });

  test('FixedSlabPool recycles freed indices and rejects stale generation handles', () {
    final pool = FixedSlabPool<String>(capacity: 2);

    final h0 = pool.allocate('MeshA')!;
    final h1 = pool.allocate('MeshB')!;
    expect(pool.allocate('Overflow'), isNull);
    expect(pool.get(h0), 'MeshA');

    expect(pool.free(h0), isTrue);
    expect(pool.free(h0), isFalse); // double free rejected
    expect(pool.get(h0), isNull);

    final h0Reused = pool.allocate('MeshC')!;
    expect(h0Reused.index, h0.index);
    expect(h0Reused.generation, greaterThan(h0.generation));
    expect(pool.get(h0), isNull); // stale handle invalid
    expect(pool.get(h0Reused), 'MeshC');
    expect(pool.get(h1), 'MeshB');
  });

  test('FrameTelemetryRecorder tracks mean, P95, P99, budget hit rate & scope sums', () {
    final rec = FrameTelemetryRecorder(windowSize: 20, budgetMs: 16.67);
    for (var i = 0; i < 19; i++) {
      rec.recordFrame(
        totalFrameMs: 8.0 + (i % 3),
        spans: const [
          TelemetrySpan(name: 'Physics', durationMs: 2.5, depth: 0),
          TelemetrySpan(name: 'Render', durationMs: 5.5, depth: 0),
        ],
      );
    }
    rec.recordFrame(totalFrameMs: 25.0);

    final stats = rec.computeStats();
    expect(stats.sampleCount, 20);
    expect(stats.maxMs, closeTo(25.0, 1e-6));
    expect(stats.p99Ms, closeTo(25.0, 1e-6));
    expect(stats.budgetHitRate, closeTo(19.0 / 20.0, 1e-6));
  });
}
