# Buch-Reihen Tracker (Flutter Prototyp)

Flutter-Prototyp für Android und iOS, um Buchreihen zu verwalten und den Lesefortschritt zu tracken.

## Funktionen

- **Buch-Suche**: Suche nach Titel, Autor oder allgemeinem Begriff über die OpenLibrary API.
- **Reihen verwalten**: Füge Bücher einer bestehenden oder neuen Reihe hinzu.
- **Lesefortschritt**: Markiere einzelne Bücher als gelesen/nicht gelesen.
- **Onleihe-Verfügbarkeit**: Prüfe die Verfügbarkeit direkt in der Onleihe-3-Suche der DiBiZentral (Regionalbibliothek Sursee / Zentralschweiz). Der Button öffnet die Onleihe-Suchseite im Systembrowser; für eine vollautomatische Verfügbarkeitsprüfung wäre ein Onleihe-Login/API nötig.
- **Lokale Datenspeicherung**: Alle Daten werden lokal mit `sembast` gespeichert.

## Abhängigkeiten

- Flutter 3.24+ / Dart 3.5+
- `http` für OpenLibrary
- `sembast` für lokale Datenbank
- `path`, `path_provider` für Dateipfade
- `url_launcher` für Onleihe-Links

## Projekt-Setup

```bash
flutter pub get
```

## Ausführen

Auf Android/iOS-Gerät oder Emulator:

```bash
flutter run
```

Desktop-Test (z.B. Linux) funktioniert ebenfalls, ist aber nicht das primäre Zielgerät:

```bash
flutter run -d linux
```

## Build

```bash
# Android
flutter build apk

# iOS (nur auf macOS)
flutter build ios
```

## Onleihe-Anpassung

Die Onleihe-URL ist in `lib/services/onleihe_service.dart` konfiguriert auf `https://dibizentral.onleihe.com/search` (DiBiZentral / Zentralschweiz). Für andere Onleihe-Regionen kann der Slug hier angepasst werden.

## Hinweis zum Prototyp

- Es wird keine Benutzer-Authentifizierung und kein Cloud-Backend genutzt.
- Die Onleihe-Prüfung öffnet aktuell die öffentliche Suchseite; nach Login sieht der Nutzer Verfügbarkeit/Ausleihe direkt auf der Onleihe-Seite.
