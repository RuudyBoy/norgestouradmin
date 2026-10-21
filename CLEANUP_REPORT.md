# Kodeopprydding – Norges Tour admin

> **Mål:** gjøre koden ryddig, oversiktlig og lett å lese, **uten å endre en eneste funksjon**. Appen skal se ut og oppføre seg nøyaktig som i dag, og skrive de samme feltene til Firebase.
>
> **Ikke med:** bugs, sikkerhet og forbedringer. Den forrige rapporten er flyttet til `CLEANUP_REPORT_bugs.md` til senere.
>
> **Utgangspunkt:** `flutter analyze` gir 23 merknader og ingen feil. `flutter test` er grønn med 76 av 76 tester. Ingen filer er endret ennå.

## 1. Sammendrag

Koden fungerer, men bærer preg av at den har vokst i flere omganger:

- **Mye død kode.** Fire hele filer og 18 metoder brukes ikke lenger. Det er ca. **2 900 linjer** av ca. 13 000, altså nesten en fjerdedel. I tillegg er det 15 MB ubrukte bilder og 3 ubrukte pakker.
- **Én kjempefil.** `tournament_control_page.dart` er på 5 497 linjer og inneholder alt: lag, seeding, generering, kampprogram, oversikt og dialoger. Etter at den døde koden er fjernet, blir den ca. 4 300 linjer. Den bør deles i flere filer.
- **Samme kode skrevet flere ganger.** Det gjelder datoparsing (8 kopier), tidsformatering (17), rundenavn (5), sortering av sluttspill (4) og kopiering av lagfelter (6).
- **Små ting som gjør koden tyngre å lese:** misvisende kommentarer, ternærer der begge greiner gir samme verdi, metoder med navn som `_DELME`/`_UNUSED`, og uensartet innrykk.

Alt nedenfor er **ren omstrukturering**. Koden flyttes, slettes eller samles, men resultatet på skjermen og i databasen blir det samme.

## 2. Plan – fire steg, tryggest først

Hvert steg blir én commit. Etter hvert steg kjører jeg `flutter analyze` og `flutter test` og røyktester appen i Chrome. Da kan hvert steg rulles tilbake for seg.

| Steg | Hva | Linjer | Risiko |
|---|---|---|---|
| **1** | Slette død kode (§3) | ≈ −2 900 | Trygg. Koden kjøres aldri i dag |
| **2** | Samle duplisert kode i felles hjelpefunksjoner (§4) | ≈ −300 | Trygg. Hver hjelper gir nøyaktig samme utdata som koden den erstatter |
| **3** | Dele opp `tournament_control_page.dart` og rydde mappestrukturen (§5) | ±0 (flytting) | Lav. Ren flytting, logikken røres ikke |
| **4** | Lesbarhet: kommentarer, navn, konstanter og eventuelt formatering (§6) | små | Trygg |

---

## 3. Steg 1 – Død kode som slettes

Jeg har søkt i hele prosjektet (`lib/` og `test/`) etter hvert navn før det ble markert som ubrukt. Appen bruker ingen navngitte ruter (`routes:`/`pushNamed`), ingen dynamiske imports og ingen oppslag via strenger. Alt navigeres med direkte klassereferanser, så resultatene fra søket er pålitelige.

### 3.1 Hele filer som aldri brukes

| Fil | Linjer | Bevis |
|---|---|---|
| `lib/simulator_logic.dart` | 218 | Importeres ingen steder |
| `lib/category_schedule_editor.dart` | 177 | Importeres ingen steder |
| `lib/tournament_schedule_page.dart` | 929 | Importeres ingen steder |
| `lib/match_control_page.dart` | 412 | Åpnes bare fra `_buildMatchRow`, som selv er død kode (se 3.2) |

### 3.2 Ubrukte metoder i `tournament_control_page.dart` (≈1 190 linjer)

| Linjer | Metoder | Hvorfor død |
|---|---|---|
| 1036–1088 | `_matchRoundOrder`, `_fmtMinutes`, `_autoScheduleForCategory` | Ikke kalt (analyzer). Kopier av funksjoner i `schedule_logic.dart` |
| 1374–1709 | `_buildPlayoffsTab_UNUSED`, `_buildVisualBracket`, `_bracketCard` | Gammel sluttspill-visning, erstattet av «Sluttspillsoversikt» |
| 3083–3333 | `_buildOppsettWrapper`, `_buildOppsettWrapperForCategory` | Gammel Oppsett-visning, erstattet av `_buildOppsettSection` |
| 4950–5062 | `_oppsettRoundLabel`, `_oppsettSectionHeader`, `_buildOppsettMatchRow` | Brukes bare av den gamle Oppsett-visningen over |
| 5064–5404 | `_buildGroupsTab_DELME`, `_buildGroupsDisplay`, `_statHeader`, `_statCell`, `_buildMatchRow` | Merket «dead code kept for reference» |
| 5407–5498 | Klassen `_BracketPainterTopDown` | Brukes bare av `_buildVisualBracket` |

Imports som blir overflødige: `dart:math show max` (linje 2) og `match_control_page.dart` (linje 6).

### 3.3 Ubrukte variabler, parametere og felter

| Sted | Hva |
|---|---|
| `tournament_control_page.dart:4977` | `isPlaceholder` regnes ut, men brukes aldri (forsvinner med 3.2) |
| `registrations_page.dart:26` | `_selectedCategoryName` settes aldri. Visningen viser alltid «Alle», og det fortsetter den med |
| `registrations_page.dart:424` | Parameteren `index` i `_buildRegistrationCard` brukes ikke |
| `registrations_page.dart:9` | `tournamentType` sendes inn, men leses aldri. `_openRegistrations` (`tournament_control_page.dart:2198`) henter turneringsdokumentet **bare** for å fylle dette feltet. Den lesingen fjernes også, og siden åpnes ellers likt |
| `edit_tournament_page.dart:699` | `courtsCount` i `_CategoryAdminDialog` brukes ikke |
| `admin_dashboard_overview.dart:17-19` | `wrapInContainer` brukes ikke (står i kommentaren) |

### 3.4 Ubrukt i `schedule_logic.dart` (blir død når filene i 3.1 er borte)
`autoScheduleCategory` (linje 279–299), og `CategorySchedule.toMap`, `copyWith`, `roundKeys` og `roundLabels`.

### 3.5 Tema (`lib/theme/`)
- `AppTheme.light` og `AppTheme.dark` (`app_theme.dart:48-239`, ≈190 linjer). Admin bruker bare `AppTheme.admin`.
- Ubrukte farger i `app_colors.dart`: `sand1`, `coralGlow`, `greenLight`, `nightSurface1`, `nightSurface2`, `nightInk2`, `heroCoral`, `heroMix`, `cardInk`.
- Ubrukte tekststiler i `app_text_styles.dart`: `dispScoreLight`, `dispH1Light`, `monoSmLight`.
- `lib/theme/README.md` er utdatert: den beskriver `AppTheme.light`, har gammel `google_fonts`-versjon og en løs `import`-linje.

> Temaet ble opprinnelig kopiert fra spillerappen. Hvis du vil kunne kopiere filene frem og tilbake mellom appene, lar jeg 3.5 være. **Si fra.**

### 3.6 Pakker og filer som ikke brukes
- `pubspec.yaml`: `firebase_storage`, `image_picker` og `cupertino_icons` importeres ingen steder.
- `assets/images/`: alle 15 bildene (15 MB) er ubrukte, men bakes inn i web-bygget. Ingen kode viser til dem.
- `norges_tour_admin/README.md` er standardteksten fra `flutter create` («A new Flutter project»). Den kan erstattes med en lenke til README-en i rotmappen.

Ingen gamle `print`/`console.log` og ingen utkommenterte kodeblokker ble funnet. Den «utkommenterte» koden er i praksis metodene i 3.2.

---

## 4. Steg 2 – Samle duplisert kode

Felles hjelpefunksjoner legges i `lib/utils/format.dart`. Der to kopier gir litt ulik tekst, får hjelperen et parameter, slik at skjermen viser nøyaktig det samme som før.

| # | Duplikat | Antall og steder | Felles løsning |
|---|---|---|---|
| 4.1 | Lese `dd.MM.yyyy` til `DateTime` | 8 kopier: `main.dart:424`, `admin_dashboard_overview.dart:92`, `edit_tournament_page.dart:114`, `tournament_control_page.dart:1750, 2153, 2335, 2655`, `main.dart:569` | `parseNoDate(String?)` |
| 4.2 | Skrive dato som `dd.MM.yyyy` | `add_tournament_page.dart:278`, `edit_tournament_page.dart:129`, `main.dart:564`, `tournament_control_page.dart:1757` | `fmtNoDate(DateTime)` |
| 4.3 | Skrive tid som `HH:mm` | 17 kopier av `hour.toString().padLeft(2,'0')…` i `add_tournament_page.dart` (5), `edit_tournament_page.dart` (7), `tournament_control_page.dart` (4) og `main.dart` (1). `schedule_logic.dart` har allerede `fmtMinutes` | `fmtTimeOfDay(TimeOfDay)` |
| 4.4 | Kort dato `dd.MM` | `main.dart:462`, `admin_dashboard_overview.dart:103` (identiske) | `shortDate(String?)` |
| 4.5 | Datoperiode («22.–24.08.2026») | `main.dart:450`, `tournament_control_page.dart:2334` | Én funksjon. Teksten ved ugyldig dato er ulik i dag, så den beholdes via et parameter |
| 4.6 | Live-score-linje (fullførte sett + pågående poeng) | `main.dart:470` (skilles med `'  '`), `tournament_control_page.dart:2182` (skilles med `' · '`) | Én funksjon med `separator` |
| 4.7 | Rundenavn i filteret (`r16` → «1/16» osv.) | Samme if-kjede to ganger: `tournament_control_page.dart:1776-1785` og `1800-1808` | Én `_roundFilterLabel(d)`. Dette fjerner også 10 analyzer-merknader om manglende krøllparenteser |
| 4.8 | Sortere sluttspill A, B, C, D | `tournament_control_page.dart:4546-4559` (pluss tre kopier i død kode) | `bracketCompare(a, b)` |
| 4.9 | Kopiere de seks lagfeltene (`*_name`, `*_id`, `*_p1_name`, `*_p1_id`, `*_p2_name`, `*_p2_id`) mellom kamper | `tournament_control_page.dart:165-176, 993-998, 1009-1014, 1273-1278, 4892-4921` | `teamFields(prefix, kilde)`. Samme felt og verdier skrives |
| 4.10 | Fase per klasse («Ikke generert», «Gruppespill», «Sluttspill», «Ferdig») | `tournament_control_page.dart:2718-2730` og `3821-3830` | Én `_categoryPhase(...)` |
| 4.11 | Tre nesten like menyknapper | Sidemenyen `admin_shell.dart:281-307` og drawer `:514-589` | Løkke over `AdminNavDestination.values` |
| 4.12 | Publiser og skjul (identiske bortsett fra `true`/`false` og teksten) | `tournament_control_page.dart:4934-4948` | `_setPublished(bool)` |
| 4.13 | Seed-sortering av påmeldinger skrevet to ganger | `registrations_page.dart:147-151`, `440-444` | Én sorteringsfunksjon |
| 4.14 | Listen over turneringstyper med navn | `add_tournament_page.dart:31-122` og `edit_tournament_page.dart:45-55` | **Bare hvis du vil:** én felles liste. Begge sidene må vise de samme navnene som i dag, så jeg tar vare på dagens forskjell (`NM` mot `Norgesmesterskap`) |

### Overflødig kode som forenkles (samme resultat)
- `admin_shell.dart:526-528, 552-554, 578-580`: `selected ? adminSidebarText : adminSidebarText`, altså samme farge i begge greiner.
- `registrations_page.dart:47-58`: tre av fire grener gir `adminPrimary`. `:198-203`: to grener gir samme farge.
- `edit_tournament_page.dart:187-191`: `if (_startTime != null)` etter at feltet allerede er validert, og `int.tryParse` gjøres to ganger på samme tekst.

---

## 5. Steg 3 – Struktur

### 5.1 Dele opp `tournament_control_page.dart`
Koden **flyttes**, men skrives ikke om. `_TournamentControlPageState` og all tilstand blir der den er. Byggemetodene for hver fane flyttes til egne filer som `part`-filer eller `extension`, slik at de har tilgang til den samme tilstanden. Da endres ingen logikk.

```
lib/pages/tournament/
  tournament_control_page.dart     Selve siden, tilstand, header, navigasjon (~600 linjer)
  tournament_generation.dart       _generateGroupStage, _addPlayoffsToBatch, _buildGroupMatch, _pendingGroupMatch
  tournament_resolver.dart         _resolvePendingMatches og lytteren
  tabs/overview_tab.dart           Oversikt
  tabs/schedule_tab.dart           Kampprogram
  tabs/setup_tab.dart              Oppsett (seeding, puljer, sluttspill)
  tabs/teams_tab.dart              Lag
  dialogs/team_dialogs.dart        Nytt lag, rediger lag, slett lag
  dialogs/match_dialogs.dart       Rediger kamp, QR
```

### 5.2 Mappestruktur for resten
I dag ligger alle sider flatt i `lib/`. Forslag:

```
lib/
  main.dart                  Bare main(), AdminApp og AuthGate
  pages/
    dashboard/               AdminDashboard + turneringskort, tabell og hero (flyttes ut av main.dart, ~1 400 linjer)
    tournament/              Se 5.1
    tournament_form/         add_ og edit_tournament_page
    registrations_page.dart, all_players_page.dart, player_claims_page.dart, admin_login_page.dart
  widgets/                   admin_shell.dart, admin_dashboard_overview.dart
  logic/                     schedule_logic.dart
  utils/                     format.dart (steg 2)
  theme/                     Som i dag
```

Testene viser til `main.dart`, `admin_shell.dart`, `admin_dashboard_overview.dart` og `theme/responsive_layout.dart`. Der oppdateres bare import-stiene.

---

## 6. Steg 4 – Lesbarhet

| Hva | Hvor | Endring |
|---|---|---|
| Kommentarer som ikke stemmer | `tournament_control_page.dart:54` sier «NavigationRail-indeks», men det finnes ingen NavigationRail. `edit_tournament_page.dart:435` har «KAPASITET» over feil seksjon. `main.dart:3` «brukes i AdminDashboard» er ufullstendig. `tournament_control_page.dart:1374` viser til slettet kode | Rett eller fjern |
| Logikk som ikke forklarer seg selv | Serpentine i blokker på 16 lag (`tournament_control_page.dart:426-437`). At `home_score`/`away_score` inneholder antall **sett** når kampen er ferdig (`:928`, `functions/src/index.ts:34`). Hvorfor kamper med status `scheduled` hoppes over (`:973`) | Kort forklarende kommentar |
| Magiske strenger | `'placeholder'` (~25 steder), QR-URL-en (`:360`), statuser | Navngitte konstanter i én fil, f.eks. `kPlaceholder`. **Verdiene er nøyaktig de samme**, så Firebase-dataene endres ikke |
| Uensartet innrykk | `_publishCategory` har 4 mellomrom (`:4934`). Feil innrykk inne i nestede builders (`:1737-2038`, `:2585-2951`) | Retter innrykket i de berørte blokkene |
| Uensartede navn | Både `'all'` og `'alle'` som «ingen filter». `_buildOppsett…` ved siden av `_buildSchedule…` | Ensartet internt. UI-teksten røres ikke |

**Formatering med `dart format`:** jeg har sjekket uten å skrive noe. Verktøyet ville endret 26 av 27 filer, fordi Dart 3.9 bruker en ny formateringsstil. Det er bare mellomrom og linjeskift, men diffen blir enorm og vanskelig å gå gjennom. Jeg foreslår å **hoppe over** det nå, eller ta det som en helt egen siste commit. **Si fra hva du vil.**

---

## 7. Hva jeg bevisst ikke rører

- Funksjonalitet, UI-tekst, farger og layout. Det gjelder også stavefeilene i noen ledetekster («Kjnn», «pǾ»), fordi retting endrer det brukeren ser. Si fra om du vil ha dem med.
- Firebase-felter, samlinger, `firestore.rules` og Cloud Function (bortsett fra eventuelt én kommentar).
- Testverktøy-knappene og alle bugs fra forrige rapport.
- Ytelsesforbedringer som caching av strømmer. Det er en endring i hvordan appen kjører, så den venter.
- Testene, utover endrede import-stier.

## 8. Tre korte valg før jeg begynner

1. **Tema (3.5):** skal ubrukte farger, stiler og `AppTheme.light`/`dark` fjernes, eller beholdes som kopi av appens tema?
2. **Bilder og pakker (3.6):** kan de 15 MB ubrukte bildene og de tre pakkene fjernes?
3. **`dart format` (§6):** hoppe over, eller kjøre som egen siste commit?

Resten (steg 1, steg 2 bortsett fra 4.14, og steg 3) kan jeg gjennomføre så snart du sier ja.
