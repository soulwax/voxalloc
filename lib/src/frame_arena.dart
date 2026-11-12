import 'dart:math' as math;
import 'dart:typed_data';

/// Byte slice returned by [LinearFrameArena.alloc].
final class ArenaAllocation {
  final int offset;
  final int length;
  final int alignment;
  final ByteData view;

  const ArenaAllocation({
    required this.offset,
    required this.length,
    required this.alignment,
    required this.view,
  });
}

/// Linear bump allocator backed by a single contiguous byte buffer, reset once per frame.
final class LinearFrameArena {
  final int capacityBytes;
  final Uint8List _buffer;
  int _cursor = 0;
  int _peakBytes = 0;
  int _allocationCount = 0;
  int _overflowCount = 0;

  LinearFrameArena({this.capacityBytes = 65536})
      : _buffer = Uint8List(math.max(64, capacityBytes));

  int get usedBytes => _cursor;
  int get remainingBytes => math.max(0, _buffer.length - _cursor);
  int get peakBytes => _peakBytes;
  int get allocationCount => _allocationCount;
  int get overflowCount => _overflowCount;
  double get utilization => _buffer.isEmpty ? 0.0 : _cursor / _buffer.length;

  /// Aligns [_cursor] up to [alignment] (power of two >= 1) and reserves [bytes], or returns `null` if exhausted.
  ArenaAllocation? alloc(int bytes, {int alignment = 8}) {
    final len = math.max(0, bytes);
    final align = math.max(1, alignment);
    final alignedOffset = (_cursor + align - 1) & ~(align - 1);
    final end = alignedOffset + len;
    if (end > _buffer.length) {
      _overflowCount++;
      return null;
    }

    _cursor = end;
    _allocationCount++;
    if (_cursor > _peakBytes) {
      _peakBytes = _cursor;
    }
    return ArenaAllocation(
      offset: alignedOffset,
      length: len,
      alignment: align,
      view: ByteData.sublistView(_buffer, alignedOffset, end),
    );
  }

  /// Resets the bump cursor to `0` for the next frame while keeping [peakBytes].
  void resetFrame() {
    _cursor = 0;
    _allocationCount = 0;
  }
}
