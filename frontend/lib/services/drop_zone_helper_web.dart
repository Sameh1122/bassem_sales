import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

class DropZoneSubscription {
  final List<StreamSubscription<dynamic>> _subs;
  DropZoneSubscription(this._subs);

  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
  }
}

DropZoneSubscription registerWebDropZone({
  required void Function(bool isDraggingOver) onDragState,
  required void Function(Uint8List bytes, String filename, int sizeBytes) onFileDrop,
  required void Function(String filename) onInvalidFile,
}) {
  final subs = <StreamSubscription<dynamic>>[];
  const allowed = {'xlsx', 'xls', 'csv'};

  subs.add(html.window.onDragOver.listen((event) {
    event.preventDefault();
    onDragState(true);
  }));

  subs.add(html.window.onDragLeave.listen((event) {
    onDragState(false);
  }));

  subs.add(html.window.onDrop.listen((event) {
    event.preventDefault();
    onDragState(false);
    final files = event.dataTransfer.files;
    if (files == null || files.isEmpty) return;

    final file = files.first;
    final name = file.name;
    final dotIdx = name.lastIndexOf('.');
    final ext = dotIdx >= 0 ? name.substring(dotIdx + 1).toLowerCase() : '';
    if (!allowed.contains(ext)) {
      onInvalidFile(name);
      return;
    }

    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      final res = reader.result;
      Uint8List? bytes;
      if (res is Uint8List) {
        bytes = res;
      } else if (res is ByteBuffer) {
        bytes = res.asUint8List();
      }
      if (bytes != null) {
        onFileDrop(bytes, name, file.size);
      }
    });
    reader.readAsArrayBuffer(file);
  }));

  return DropZoneSubscription(subs);
}
