/// Generational handle referencing a slot inside [FixedSlabPool].
final class SlabHandle {
  final int index;
  final int generation;

  const SlabHandle({required this.index, required this.generation});

  @override
  bool operator ==(Object other) =>
      other is SlabHandle && other.index == index && other.generation == generation;

  @override
  int get hashCode => Object.hash(index, generation);
}

final class _SlabSlot<T> {
  T? value;
  int generation = 1;
  bool occupied = false;
  int nextFree = -1;
}

/// O(1) fixed-capacity typed slab pool with generation validation preventing stale handle reuse.
final class FixedSlabPool<T> {
  final int capacity;
  final List<_SlabSlot<T>> _slots;
  int _freeHead = 0;
  int _activeCount = 0;

  FixedSlabPool({this.capacity = 256})
      : _slots = List.generate(capacity < 1 ? 1 : capacity, (i) {
          final slot = _SlabSlot<T>();
          slot.nextFree = (i + 1 < (capacity < 1 ? 1 : capacity)) ? i + 1 : -1;
          return slot;
        });

  int get activeCount => _activeCount;
  int get freeCount => _slots.length - _activeCount;

  /// Allocates a slot for [item] and returns its generational [SlabHandle], or `null` when full.
  SlabHandle? allocate(T item) {
    if (_freeHead == -1) return null;
    final idx = _freeHead;
    final slot = _slots[idx];
    _freeHead = slot.nextFree;
    slot.nextFree = -1;
    slot.value = item;
    slot.occupied = true;
    _activeCount++;
    return SlabHandle(index: idx, generation: slot.generation);
  }

  bool isValid(SlabHandle handle) {
    if (handle.index < 0 || handle.index >= _slots.length) return false;
    final slot = _slots[handle.index];
    return slot.occupied && slot.generation == handle.generation;
  }

  T? get(SlabHandle handle) {
    if (!isValid(handle)) return null;
    return _slots[handle.index].value;
  }

  /// Releases [handle] if still valid, incrementing its generation so dangling handles fail cleanly.
  bool free(SlabHandle handle) {
    if (!isValid(handle)) return false;
    final slot = _slots[handle.index];
    slot.occupied = false;
    slot.value = null;
    slot.generation++;
    slot.nextFree = _freeHead;
    _freeHead = handle.index;
    _activeCount--;
    return true;
  }
}
