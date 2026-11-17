# sovo. 1.0.1 (9) — Integrationen und Prüfstand

Stand: **18. November 2026**, Asia/Tokyo. Ergänzung zur [Integrationsrecherche](INTEGRATION-RESEARCH.de.md). Dieser Bericht unterscheidet ausgeführte Softwaretests, vorbereitete Gerätepakete und noch offene Hardwaretests.

## Umgesetzt

- **iCloud-Metadaten:** koordinierte, größenbegrenzte JSON-Zugriffe; Buchmanifeste werden vor dem Schreiben mit dem vorhandenen Stand und vorhandenen Konfliktversionen zusammengeführt. Konfliktversionen werden erst nach erfolgreichem Schreiben als aufgelöst markiert. Ein neuerer bewusster Rücksprung der Hörposition gewinnt gegen einen älteren höheren Fortschritt.
- **Kontoschutz:** die App bindet die Synchronisierung an die gespeicherte iCloud-Identität. Ein Wechsel pausiert den Abgleich, verwirft den zwischengespeicherten Container und erfordert eine ausdrückliche Bestätigung in Settings, bevor lokale Bücher in ein anderes Konto hochgeladen werden. Lokale Bücher werden nicht gelöscht.
- **Fortschrittsquote:** konservatives Budget für den Key-Value-Cache; die Buchmanifeste behalten den Fortschritt als weiteren Übertragungsweg. Eine Quotenmeldung wird sichtbar, statt einen vollständigen Erfolg zu behaupten.
- **Verständlicher Status:** Zeitpunkt des letzten lokalen Abgleichs, Hinweis auf möglicherweise noch laufende iCloud-Übertragung und klare Erklärung, dass lokales Entfernen keine Cloud-Löschung ist.
- **Goodreads:** eigene persistente Website-Sitzung bleibt unabhängig von Safari/Chrome. Ein Timeout pro Seite, Validierung der Rückgaben und eine Begrenzung der vollständigen Pagination verhindern endlose oder still unvollständige Aktualisierungen. Anmelde-/Challenge-Seiten, beschädigte Daten und verspätete Antworten ersetzen keinen gültigen Cache.
- **Goodreads-Kontowahl:** ein neu gewähltes Profil wird nicht mit den Büchern des bisherigen Profils als neue Regalkopie veröffentlicht. Regalkopien und Anmeldedaten bleiben getrennt.
- **Interaktive Goodreads-Seiten:** gezielt geöffnete Buch-/Rezensionsseiten dürfen ihre Website-Funktionen ausführen; die Hintergrund-Regalauswertung bleibt ohne Website-Skripte. Host- und Inhaltsregeln bleiben aktiv. Der Nutzer kann den Status auf Goodreads selbst ändern und anschließend die Regale neu laden. Live-Schreibaktionen mit einem angemeldeten Konto wurden nicht als getestet ausgegeben.
- **AirPods:** präzisierte Anleitung einschließlich AirPods Max 2; vorhandene Systempause und Positionsspeicherung bleiben der Integrationsweg. Keine Gesundheitsberechtigung, kein Scheintraining und keine selbst behauptete Schlaferkennung.

## Ausgeführte Prüfungen

| Prüfung | Ergebnis | Aussagegrenze |
| --- | --- | --- |
| Native Logiktests auf iPhone-Duo-Simulator, iOS 27.1 | **PASS: 39**, **SKIP: 1**, keine Compilerwarnungen | Der ausgelassene Keychain-Test braucht echte Signierungsberechtigungen |
| Native XCTest-Oberflächentests auf demselben Simulator | **PASS: 8** | Kein physisches iPhone und kein echter AirPods-Sensor |
| iCloud-Dateimerge, neuerer Rücksprung, falsche Buch-ID | **PASS** | Koordinierte lokale Testdateien, kein Nachweis für zwei iCloud-Geräte |
| Metadatengröße, symbolischer Link, Quotenbudget | **PASS** | Lokale Grenzfalltests |
| Identitätsvergleich, falsches/beschädigtes Archiv, Kontowechsel | **PASS** | Testidentitäten; realer Apple-Account-Wechsel bleibt offen |
| Goodreads-Parser mit Buchseite, leerem Regal und Anmeldeseite | **PASS** | Native WKWebView mit kontrollierten HTML-Fällen |
| Goodreads-Regalkopie über zwei lokale Testinstanzen und lokales Trennen | **PASS** | Gemeinsames Testverzeichnis, keine Live-Anmeldung |
| Wiedergabe, Konvertierung, Metadaten, Warteschlange und Pause | **PASS** | Vorhandene native Regressionstests; kein subjektiver Hörtest |
| Native Settings-/AirPods-Ansichten | **PASS: gerenderte XCTest-Bilder geprüft** | Repräsentative Simulatoransicht, kein vollständiges Accessibility-Audit |
| Mac-Catalyst-Debug-Build | **PASS** | Kompilierung, kein neuer physischer Mac-Wiedergabetest |
| iOS-Release-Archiv | **PASS** | Archiv erstellt, nicht automatisch im Store verfügbar |
| App/Share/Widget, Version 9, Audiobeispiel, Datenschutzmanifest | **PASS** | Paketprüfung für iOS und Catalyst |
| Anzeigename und AppIcon im signierten iOS-Paket | **PASS** | Assets vorhanden; kein frischer Store-Installationsnachweis |
| Signierung für das registrierte Test-iPhone | **PASS** | Eigene QA-Profile, richtiges Bundle, App Group, iCloud und Gerät geprüft |

Lokale Evidenz: `/private/tmp/sovo-integration-final.xcresult`, `/private/tmp/sovo-integration-ui.xcresult` sowie die zugehörigen MobileBuildMCP-Buildlogs. Die UI-Bilder stammen aus echten nativen Tests, nicht aus HTML-Mockups. Der iOS-QA-Build wurde mit dem vorhandenen isolierten Zertifikat ohne Passwortabfrage signiert; dessen dedizierter Schlüsselbund wurde anschließend wieder gesperrt. Private Zertifikate, Profile und Gerätekennungen werden nicht ins Repository aufgenommen.

## Direkter physischer Gerätezugriff

Das angeschlossene **iPhone 14 mit iOS 27.2.1** ist bereits registriert und vertraut dem Mac; Entwickler-Modus ist aktiv. Nach erneutem Einstecken bestätigt Apple den Transport **wired**. Xcode 27.2 und ein verwendbares Developer Disk Image sind installiert. Die relevanten Firewall-Regeln für Xcode, `remoted` und `devicectl` erlauben Verbindungen; Schutzregeln wurden nicht abgeschaltet.

Zum dokumentierten Prüfzeitpunkt blieb Apples Entwicklertunnel bei **connecting**, die Developer-Dienste waren nicht verfügbar. Geräteabfragen und die direkte Installation liefen in begrenzte Timeouts. Auch Apples **Device Hub → View Screen** endete mit **Connection timed out**, und `xcodebuild -showdestinations` bot das physische iPhone nicht als nutzbares Ziel an. Die eigenen hängenden Installationsprozesse wurden beendet. **Daraus folgt kein bestandener physischer App-Test und keine bestätigte Installation von Build 9.**

Der vorhandene Ablauf aus `Shinkoiwa-sardistic` wurde gelesen: native XCTest-Tests, unsigned Build, dateibasierte Signierung und direkte Installation über `devicectl`. Seine früheren physischen Testergebnisse beweisen nicht, dass der heutige Gerätetunnel bereit ist. Keine Game-Tests, fremden QA-Zertifikate oder bestehenden Game-Spielstände wurden verändert. iPhone Mirroring wurde auf Wunsch des Eigentümers nicht als Ersatz für einen direkten Test verwendet.

## Bewusst noch offen

1. Physisches Installieren und Testen von Build 9, sobald Apples direkter Gerätezustand bereit ist.
2. Echter iCloud-Abgleich zwischen zwei angemeldeten Geräten einschließlich Uploadabschluss, Offline-Konflikten, Kontowechsel, Speicherknappheit und ausgelagertem Audio.
3. Aktuelle Goodreads-Anmeldung und private Regale. Die Apple-Developer-Anmeldung in Chrome wurde bestätigt; sie ist keine Goodreads-Sitzung in der App.
4. Automatischer Goodreads-Schreibabgleich. Dafür gibt es weiterhin keinen verifizierten neuen offiziellen API-Zugang. Die interaktive Website ersetzt diesen nicht. Ein inoffizieller Adapter benötigt eine separate Entscheidung über Dienstbedingungen, Buchzuordnung, Einwilligung und veraltete Offline-Aufträge.
5. Tatsächliche AirPods-Schlafpause mit unterstütztem Modell, aktivierter Systemeinstellung und realer Einschlafsituation. Softwaretests können das nicht nachbilden.

**Veröffentlichung:** Quellstand und QA-Paket sind Build 9. Der zuletzt hochgeladene Build 8 enthält diese neuen Änderungen nicht. Build 9 wurde mit diesem Arbeitsschritt weder bei Apple hochgeladen noch zur Review eingereicht. GitHub Actions bleiben deaktiviert; bestehende Store-Einreichungen werden nicht als neuer Testerfolg ausgegeben.
