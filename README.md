# Kneipenzeit

Kneipenzeit erfasst Besuche in der Stammkneipe anhand eines einstellbaren GPS-Radius und wertet die Anwesenheitszeiten übersichtlich aus.

## Funktionen

- automatisches Ein- und Auschecken per GPS
- einstellbarer Erkennungsradius und Mindestaufenthalt
- manuelles Ein- und Auschecken
- Statistiken für heute, Woche, Monat und Jahr
- vollständige Besuchschronik
- lokale Speicherung auf dem Gerät
- responsive Darstellung für Smartphone und Desktop

## Lokal starten

```bash
npm install
npm run dev
```

Danach die App unter http://localhost:3000 öffnen.

## Datenschutz

Standort- und Besuchsdaten werden ausschließlich lokal im Browser gespeichert. Eine Web-App kann auf dem iPhone bei gesperrtem Bildschirm nicht durchgehend auf den Standort zugreifen.

## Native iPhone-App

Die native SwiftUI-Version liegt im Ordner `ios/`. Sie ergänzt die Web-App um iOS-Bereichsüberwachung im Hintergrund, lokale Benachrichtigungen und ausführliche Tages-, Wochen- und Monatsstatistiken.

### In Xcode öffnen

1. Repository klonen.
2. `ios/Kneipenzeit.xcodeproj` mit Xcode 27 oder neuer öffnen.
3. Beim Target **Kneipenzeit** unter **Signing & Capabilities** das eigene Personal Team auswählen.
4. Ein verbundenes iPhone als Ziel wählen und die App mit **Run** starten.
5. In der App Standortzugriff zuerst **Beim Verwenden** und danach **Immer** erlauben.

Web-Version 1.2.1 · Native iOS-Version 2.0.2 · Designed & Developed by Andreas Binder
