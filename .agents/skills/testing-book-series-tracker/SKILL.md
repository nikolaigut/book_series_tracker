---
name: Testing book_series_tracker
description: How to build, run, and test the book_series_tracker Flutter app on Linux in this Devin environment, including keyboard-driven UI workarounds and real-network test tips.
---

## Environment setup

- Repo root: `/home/ubuntu/repos/book-series-tracker`
- Add Flutter to PATH: `export PATH="$HOME/flutter/bin:$PATH"`
- Install Linux desktop build deps once:
  ```bash
  sudo apt-get install -y cmake ninja-build clang build-essential pkg-config libgtk-3-dev libblkid-dev liblzma-dev
  ```
- The app uses Sembast (`databaseFactoryIo`) and `path_provider` with `getApplicationDocumentsDirectory`, so the Linux target is the best local target. Web builds fail at runtime because `path_provider` has no web documents directory and Sembast uses IO-only storage.

## Running the Linux app

1. From the repo root:
   ```bash
   flutter run -d linux
   ```
2. Find the window ID:
   ```bash
   xdotool search --name 'book_series_tracker' | head -1
   # or
   xwininfo -tree -root | grep 'book_series_tracker'
   ```
3. Maximize before recording:
   ```bash
   wmctrl -r :ACTIVE: -b add,maximized_vert,maximized_horz
   ```

## Driving the Flutter Linux UI via xdotool

- Mouse clicks from `computer`/`xdotool` are not delivered reliably into the Flutter Linux embedder in this environment. Use keyboard navigation instead.
- **Open the search screen** from the home screen:
  ```bash
  xdotool windowactivate --sync <WID> key Tab Return
  ```
- **Filter chips** (`Titel`, `Autor`, `Reihe`, `Alles`) are selectable by focus plus `Return`.
- **Text entry** does not work with `xdotool type` or individual `xdotool key <letters>`; use the clipboard instead:
  ```bash
  echo 'Bücher der Macht' | xclip -selection primary
  xdotool windowactivate --sync <WID> key Shift+Insert
  ```
- `Shift+Insert` pastes the primary selection into a focused Flutter `TextField`; `Ctrl+V` does not work under synthetic input.
- Submit a search with `Return` once the `TextField` has focus.

## Running automated tests

- `flutter analyze` — baseline static check, expected clean.
- `flutter test` — existing unit/service tests, expected to pass.
- `flutter test` does **not** allow real HTTP by default; it blocks network and returns 400 for all requests. If you write acceptance tests that must call Libex/OpenLibrary endpoints, wrap network calls with `HttpOverrides`:
  ```dart
  class _RealHttpOverrides extends HttpOverrides {
    @override
    HttpClient createHttpClient(SecurityContext? context) => super.createHttpClient(context);
  }

  Future<T> withRealNetwork<T>(Future<T> Function() body) => HttpOverrides.runZoned(
        body,
        createHttpClient: (context) => _RealHttpOverrides().createHttpClient(context),
      );
  ```
- For widget tests that touch `DatabaseService`, set up a `MethodChannel` mock for `path_provider` because `getApplicationDocumentsDirectory` has no plugin in headless test mode:
  ```dart
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'getApplicationDocumentsDirectory') {
      return Directory.systemTemp.createTempSync('app_').path;
    }
    return null;
  });
  ```

## Common gotchas

- `flutter run -d chrome` compiles but fails at runtime with `MissingPluginException` for `path_provider` / `getApplicationDocumentsDirectory`.
- As an alternative to `flutter run -d linux`, you can build a debug Linux bundle and run the binary directly: `flutter build linux --debug`, then `./build/linux/x64/debug/bundle/book_series_tracker`.
- The `Alles`/`Alle` (`any`) search filter now falls back to Libex when OpenLibrary results do not contain the normalized query phrase as a substring in their title or author. This phrase-based check avoids false positives where unrelated titles contain the same meaningful words, allowing queries like "Bücher der Macht" to fall back to Libex correctly.
- Synthetic mouse clicks and keyboard `Tab`/`Return` navigation are not reliably delivered into the Flutter Linux embedder in this environment; rely on service/widget tests for functional proof rather than fully automated UI driving.
- The third Libex book for `Die Bücher der Macht` is currently `Steingladiole, Erde vergisst nie` (not `Schattenblüte`), but the order indices are 1, 2, 3.

## Devin secrets needed

None — the app uses public OpenLibrary and Libex endpoints. No API keys or credentials are required for testing.
