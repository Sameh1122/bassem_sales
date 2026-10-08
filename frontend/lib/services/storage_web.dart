import 'dart:html' as html;
import 'dart:convert';

String? getLocalStorage(String key) {
  try {
    return html.window.localStorage[key];
  } catch (_) {
    return null;
  }
}

void setLocalStorage(String key, String value) {
  try {
    html.window.localStorage[key] = value;
  } catch (_) {}
}

void removeLocalStorage(String key) {
  try {
    html.window.localStorage.remove(key);
  } catch (_) {}
}

void downloadBlob(String filename, String content, {String mimeType = 'text/csv;charset=utf-8;'}) {
  try {
    final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(content)];
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
  } catch (_) {}
}
