import 'dart:typed_data';

class DropZoneSubscription {
  void dispose() {}
}

DropZoneSubscription registerWebDropZone({
  required void Function(bool isDraggingOver) onDragState,
  required void Function(Uint8List bytes, String filename, int sizeBytes) onFileDrop,
  required void Function(String filename) onInvalidFile,
}) {
  return DropZoneSubscription();
}
