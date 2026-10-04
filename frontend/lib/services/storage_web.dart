import 'dart:html' as html;

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
