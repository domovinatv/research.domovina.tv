// Web implementation — clears URL query params via history.replaceState.
import 'dart:js_interop';

@JS('window')
external _Window get _window;

@JS()
extension type _Window(JSObject _) implements JSObject {
  external _History get history;
}

@JS()
extension type _History(JSObject _) implements JSObject {
  external JSAny? get state;
  external void replaceState(JSAny? data, String title, String url);
}

void clearUrlParams() {
  final uri = Uri.base;
  if (uri.hasQuery) {
    // Preserve Flutter's history state to avoid navigation assertion errors
    _window.history.replaceState(_window.history.state, '', uri.path);
  }
}
