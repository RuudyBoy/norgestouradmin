# Opprydding – Norges Tour admin (analyserapport)

> Kun analyse. Ingen kildefiler er endret. Status ved analyse: `git status` ren, `flutter analyze --no-pub` = 23 merknader (0 feil), `flutter test --no-pub` = **76 av 76 tester grønne**.

## 1. Sammendrag

- **Omfang:** ~13 000 linjer Dart i `norges_tour_admin/lib`, 1 Cloud Function (`functions/src/index.ts`), `firestore.rules`. Én fil dominerer: `tournament_control_page.dart` (5 497 linjer).
- **Død kode:** ca. **2 900 linjer** kan fjernes uten oppførselsendring: 4 filer som aldri importeres eller nås (≈1 740 linjer), ≈1 190 linjer ubrukte metoder i `tournament_control_page.dart`, ubrukte tema-varianter, 3 ubrukte pakker og **15 MB ubrukte bilder** i `assets/images/` som bakes inn i web-bygget.
- **Største risikoer (bugs):**
  1. `firestore.rules` lar **hvem som helst uten innlogging** skrive og slette `teams`, `matches` og `events` (B1).
  2. Store deler av turneringsflyten (runde 2 i puljene, puljeplass → sluttspill, omspill-taper → B-sluttspill) løses **bare når en admin har turneringssiden åpen**. Cloud Function dekker bare vinner → `next_match_id` (B2, B3).
  3. Et resultat som overstyres etterpå, flyttes ikke videre: feil lag blir stående i neste kamp (B4).
  4. Race condition i `matchRunner`: kan la en finale bli stående som «Venter...» for alltid (B5).
  5. Generering med et lagantall som ikke er delelig med 4 gir ødelagte puljer (B7). Seeding-forhåndsvisningen viser andre puljer enn det som faktisk genereres når det er over 16 lag (B9).
  6. Testknapper i produksjons-UI overskriver alle spillernavn eller rankingpoeng uten bekreftelse (B18).
- **Ytelse:** Firestore-strømmer lages inne i `build()`. Hvert tastetrykk i et søkefelt og hver musebevegelse over en rad river ned og setter opp 5–15 lyttere på nytt (B14). Det gir ikke minnelekkasje, men ekstra lesninger og flimring.
- **Forenkling:** samme logikk finnes i 2–5 kopier (datoparsing, live-score-linje, rundenavn, kopiering av lagfelter, bracket-sortering og avansement-logikk på tre steder).

## 2. Anbefalt rekkefølge (tryggest først)

| Fase | Innhold | Risiko | Verifisering |
|---|---|---|---|
| **0** | Ta utgangspunkt: `flutter analyze`, `flutter test` (76 grønne), og en manuell røyktest (se §8). | – | – |
| **1** | Fjern død kode: D1–D6, D9 og lint-rydding (L1, L2, L5). Ren sletting, ingen logikk røres. | Trygg | analyze + test + røyktest |
| **2** | Samle duplikater som rene hjelpefunksjoner med identisk resultat (F1–F7). Legg til konstanter (L3). Legg til manglende `mounted`-sjekker og `dispose` (B13, B39). | Trygg / Lav | analyze + test + røyktest |
| **3** | Cache strømmer i `State` (B14/B15). Del opp `tournament_control_page.dart` i flere filer uten å endre logikk (F8). Fjern ubrukte pakker og bilder (D7, D8, D10), men først etter svar på spørsmål. | Lav / Må testes | + manuell test av alle faner og live-oppdatering |
| **4** | Feilrettinger som **endrer oppførsel**, bare de du godkjenner: B4, B5, B6, B7, B9, B18, B19 osv. Regler (B1) og flytting av avansement til Cloud Function (B2) tas til slutt og koordineres med app og livescore. | Endrer oppførsel | egen testturnering i Firestore |

Hver fase bør være én commit (eller én PR), slik at den kan rulles tilbake alene.

---

## 3. Kartlegging

### 3.1 Struktur

```
norgestouradmin/
  firestore.rules            Sikkerhetsregler (deles av ALLE tre appene – samme prosjekt «norges-tour»)
  firebase.json / .firebaserc  Deploy av rules + functions
  functions/src/index.ts     Cloud Function matchRunner (onDocumentUpdated matches/{id})
  norges_tour_admin/
    lib/
      main.dart                     AdminApp, AuthGate, AdminDashboard (turneringsliste), sletting
      admin_shell.dart              Sidemeny/drawer, faner (turneringer, spillere, krav)
      admin_dashboard_overview.dart KPI-kort «Krever handling»
      admin_login_page.dart
      add_tournament_page.dart / edit_tournament_page.dart
      tournament_control_page.dart  5 497 linjer: lag, seeding, generering, resolve, kampprogram, oversikt
      schedule_logic.dart           Bane- og tidsfordeling (autoScheduleTournament)
      registrations_page.dart, all_players_page.dart, player_claims_page.dart
      match_control_page.dart, tournament_schedule_page.dart,
      category_schedule_editor.dart, simulator_logic.dart   ← nås ikke (se D1/D2)
      theme/                        Kopi av designsystemet fra spillerappen + admin_ui.dart
    test/                           6 testfiler (responsiv layout/navigasjon), 76 tester
    assets/images/                  15 bilder, 15 MB – ingen brukes
```

### 3.2 Avhengigheter (`pubspec.yaml`)

| Pakke | Brukes? |
|---|---|
| firebase_core, firebase_auth, cloud_firestore | Ja |
| qr_flutter | Ja (`tournament_control_page.dart:374`) |
| google_fonts | Ja (tema) |
| **firebase_storage** | **Nei**, ingen import |
| **image_picker** | **Nei**, ingen import |
| **cupertino_icons** | **Nei**, ingen `CupertinoIcons` |
| functions: firebase-admin, firebase-functions | Ja |

### 3.3 Hvordan admin snakker med Firebase

- **Ingen tjenestelag.** Alle sider kaller `FirebaseFirestore.instance` direkte, både lesing (`StreamBuilder` og `.get()`) og skriving (`update`, `set`, `batch`).
- **Auth:** e-post og passord. `AuthGate` (`main.dart:45-111`) sjekker at `admins/{uid}` finnes.
- **Samlinger admin skriver til:** `tournaments`, `categories`, `teams`, `matches` (og `matches/*/events` ved sletting), `registrations` (status, wildcard), `players`, `player_claims`, `users` (ved godkjent krav).
- **Avansement i turneringen skjer to steder:**
  1. **Klient:** `_resolvePendingMatches` (`tournament_control_page.dart:902-1032`). Den trigges av en lytter på ferdige kamper (`:78-109`), av Sync-knapper og av redigering eller walkover. Den løser `*_from_match_id/slot` (vinner/taper) og `*_from_group/place`, og setter `group_placement`.
  2. **Server:** `matchRunner` (`functions/src/index.ts`). Den setter `group_placement` etter K3/K4 og kopierer vinneren via `next_match_id/next_match_slot`.
  3. (`match_control_page.dart:136-218` har en tredje kopi, men den nås ikke.)

### 3.4 Kontrakter som deles med spillerappen og livescore (må ikke endres)

Kontrollert read-only mot søsken-repoene `../norgestourapp` og `../norgestourlivescore`:

| Kontrakt | Brukes av |
|---|---|
| QR-URL `https://spikedunk.web.app/?matchId=<id>` (`tournament_control_page.dart:360`) | livescore leser `Uri.base.queryParameters['matchId']`, hosting-target `spikedunk` |
| `matches`: `team_a_*`/`team_b_*` (`_name`, `_id`, `_p1_name`, `_p1_id`, `_p2_*`), `status` (`pending`/`scheduled`/`live`/`finished`), `home_score`/`away_score`, `home_sets`/`away_sets`, `past_sets`, `current_set`, `court`, `match_time`, `match_date`, `stage`, `group`, `match_type`, `bracket`, `round`, `match_number`, `next_match_id`, `next_match_slot`, `walkover` | admin, livescore, app, function |
| **Konvensjon:** når `status == 'finished'`, inneholder `home_score`/`away_score` **antall vunne sett**. Under spill inneholder de poeng i settet som pågår. | livescore (`main.dart:853-857`), simulator, match_control, alle visninger i admin |
| `'placeholder'` som `team_*_id` for ukjente lag | admin, function |
| `categories.published` (appen spør `where('published', isEqualTo: true)`) | app |
| `teams.team_points` (appen faller tilbake på `combined_ranking`) | app |
| `registrations.combined_ranking`, `wildcard_requested`, `status` | app skriver, admin leser og oppdaterer |
| `users.linkedPlayerId`, `users.isPlayer`, `player_claims.{uid, playerId, status, updatedAt}` (camelCase!) | app |
| `tournaments.tournament_type_label` | app (`tournament_registration_page.dart:345`) |
| Tema (`lib/theme/app_colors.dart` m.fl.) er en **kopi** av appens tema. Filene er ikke delt og har allerede glidd fra hverandre (`diff` viser forskjell). | – |

**Ikke endre feltnavn, verdier eller samlingsnavn** i noen fase. Navnemiksen camelCase/snake_case (`updatedAt` mot `updated_at`) må bli som den er.

---

## 4. Regler fra `.agent/rules` og hvordan koden forholder seg

Mappen inneholder fem PDF-er (domeneregler, ikke kodestil): NVBF-reglement 2026, rankingtabell, systeminstruks, seedingtabell (vedlegg 3) og sluttspilloppsett Masters (vedlegg 4). Det jeg har sjekket koden mot:

| Regel | Status i koden |
|---|---|
| Fourset-pulje: K1 = S1–S4, K2 = S2–S3, K3 = vinnere (1./2.), K4 = tapere (3./4.) (reglement 2.5.2) | ✅ `_generateGroupStage` `:473-506` og `matchRunner` |
| Serpentine per «divisjon» på 16 lag (seed 1–16 i puljene 1–4, seed 17–32 i puljene 5–8) (vedlegg 3) | ✅ for 16/32/48/64 lag (`:426-437`). ❌ for andre lagantall (B7) |
| Seedingtabellen for 17–19, 21–23 osv.: ekstra lag legges som 5. lag i eksisterende puljer, ikke i en ny minipulje | ❌ Koden lager en ny pulje med 1–3 lag (B7) |
| 24-lags A-sluttspill, B og C 16 lag (vedlegg 4) | ⚠️ Koden har egne oppsett for 4 og 8 puljer. Andre puljeantall får **ingen** sluttspill (B8) |
| «Lag fra samme pulje møtes ikke i første utslagsrunde» | ✅ for 4 og 8 puljer (kommentert i koden) |
| NT Master/Open: seed 1–4 plasseres, 5–16 **trekkes** (reglement 2.3.6) | ❌ Koden bruker ren serpentine også her (ingen trekning). Ikke en kodefeil, men et avvik: se spørsmål S5 |
| Poenglikhet i seeding: høyest totalranking → høyeste enkeltresultat → trekning (1.3.6) | ❌ Sortering bare på `team_points`, uavgjort gir tilfeldig rekkefølge fra Firestore (spørsmål S5) |
| Rankingkategorier (tabell) | ⚠️ Se B20 |

---

## 5. Funn – Bugs og risiko

Formatet for hvert funn er **fil:linje**, deretter problem, forslag, **risiko** og **vurdering** (faktisk bug eller mulig med vilje).

### B1 · Firestore-reglene er åpne for alle · `firestore.rules:25-35`
- **Problem:** `teams`, `matches` og `matches/*/events` har `allow read, write: if true`. Alle med prosjekt-ID-en (den er offentlig i `firebase_options.dart`) kan slette eller endre alle kamper og lag uten innlogging. I tillegg gir reglene **bare admins** skrivetilgang til `users`, `registrations` og `player_claims`, mens spillerappen skriver til alle tre (`register_page.dart:33`, påmelding, krav). Enten er reglene i repoet ikke de som er deployet, eller så feiler de flytene i appen.
- **Forslag:** Krev minst `request.auth != null` for skriving til `matches`/`events`. Livescore må da logge inn (f.eks. anonymt). Gi innloggede brukere skrivetilgang til egne `users/{uid}` og egne `registrations`/`player_claims`.
- **Risiko:** Endrer oppførsel (påvirker alle tre appene).
- **Vurdering:** Reell sikkerhetsrisiko. README nevner «strammere Firestore-regler» som neste steg, så dette er kjent og midlertidig. **Spørsmål S1.**

### B2 · Avansement avhenger av at en admin har siden åpen · `tournament_control_page.dart:78-109, 902-1032` / `functions/src/index.ts:39-112`
- **Problem:** `matchRunner` håndterer bare (a) `group_placement` etter K3/K4 og (b) vinner → `next_match_id`. Disse slot-typene løses **bare av klienten**:
  - K3/K4 i puljen (`team_*_from_match_id` fra K1/K2, uten `next_match_id`),
  - puljeplass → sluttspill (`*_from_group/_from_place`),
  - taper av omspill → B-kvartfinale (`from_slot: 'loser'`).

  Er ingen admin på turneringssiden, stopper turneringen etter runde 1 i puljene. README (`README.md:27-31`) sier at `matchRunner` flytter lagene videre.
- **Forslag:** Flytt hele `_resolvePendingMatches`-logikken til Cloud Function, og la klienten bare ha «Sync»-knappen som reserve.
- **Risiko:** Endrer oppførsel / Må testes.
- **Vurdering:** Arkitekturrisiko, ikke en enkeltlinje-bug. Trolig bevisst midlertidig (README: «at all avansement-logikk ligger i Cloud Functions»). **Spørsmål S2.**

### B3 · Lytteren ignorerer kamper som ble ferdige mens siden var lukket · `tournament_control_page.dart:87-92`
- **Problem:** Første emisjon fra lytteren merkes bare som «kjent». Kamper som ble `finished` før siden ble åpnet, blir derfor ikke løst før noen trykker Sync eller en ny kamp blir ferdig.
- **Forslag:** Kjør `_resolvePendingMatches` én gang per klasse ved første emisjon. Funksjonen er idempotent.
  ```dart
  // før
  if (!_listenerReady) { _knownFinishedIds = currentIds; _listenerReady = true; return; }
  // etter
  if (!_listenerReady) {
    _knownFinishedIds = currentIds; _listenerReady = true;
    for (final c in _categoriesOf(snapshot.docs)) { _resolvePendingMatches(categoryId: c); }
    return;
  }
  ```
- **Risiko:** Endrer oppførsel (flere skrivinger ved åpning) / Må testes.
- **Vurdering:** Kan være med vilje (for å unngå skriving ved åpning), men gir hull sammen med B2. **Spørsmål S2.**

### B4 · Et overstyrt resultat flyttes ikke videre · `tournament_control_page.dart:973, 980, 1254-1260` / `functions/src/index.ts:27`
- **Problem:** I «Overstyr resultat» lover kommentaren «Resolve downstream kamper hvis resultat er endret». Men `_resolvePendingMatches` hopper over kamper med status `scheduled` (`:973`) og slots som ikke lenger er `placeholder` (`:980`). Når neste kamp først er fylt, blir feil lag stående. `matchRunner` reagerer heller ikke, fordi `before.status` allerede er `finished`.
- **Forslag:** Ved overstyring: finn kampene som peker på denne (`*_from_match_id == id` eller `next_match_id`). Hvis de ikke er startet (`!= live/finished`), skriv riktig lag på nytt. Hvis de er startet, vis en advarsel.
- **Risiko:** Endrer oppførsel.
- **Vurdering:** Faktisk bug.

### B5 · Race i `matchRunner` · `functions/src/index.ts:96-111`
- **Problem:** Funksjonen leser neste kamp og oppdaterer den deretter, uten transaksjon. Blir begge semifinalene ferdige nesten samtidig, leser begge kjøringene den andre sloten som `placeholder`, og ingen av dem setter `status: 'scheduled'`. Finalen får begge lag, men står som `pending`. Klientens resolver hopper over den (begge id-er er ekte, `upd` blir tom), og QR-knappen er deaktivert for `pending` (`tournament_control_page.dart:2123-2125`).
- **Forslag:**
  ```ts
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(nextMatchRef);
    if (!snap.exists) return;
    const other = snap.get(`${otherPfx}_id`);
    if (other && other !== "placeholder") updateFields["status"] = "scheduled";
    tx.update(nextMatchRef, updateFields);
  });
  ```
- **Risiko:** Lav / Må testes (resultatet er det samme, bare atomisk).
- **Vurdering:** Faktisk bug (sjelden, men realistisk på turneringsdag).

### B6 · Dobbel generering ved to raske klikk, og feil klasse ved bytte underveis · `tournament_control_page.dart:392-513, 4292`
- **Problem:** `_generateGroupStage` har ikke noe «pågår»-flagg. Knappen i `_buildGenerateCard` er alltid aktiv. To klikk ser begge 0 kamper og skriver begge et fullt oppsett. I tillegg leses `_selectedCategoryId` **etter** flere `await` (`_buildGroupMatch:152`, `_pendingGroupMatch:554`, `mkPlayoff:615`). Bytter brukeren klasse mens genereringen pågår, får kampene feil `category_id`.
- **Forslag:** Fang `final catId = _selectedCategoryId!` øverst og send den inn. Legg til `bool _isGenerating` som deaktiverer knappen.
- **Risiko:** Lav.
- **Vurdering:** Faktisk bug (lav sannsynlighet).

### B7 · Puljer med færre enn 4 lag blir ødelagt · `tournament_control_page.dart:419-437, 474-506`
- **Problem:** `numGroups = ceil(n/4)`. Er `n` ikke delelig med 4, får siste pulje 1–3 lag:
  - **3 lag:** K1 = `gTeams[0]` mot `gTeams.last` (= seed 3) og K2 = seed 2 mot seed 3. Seed 3 er satt opp i to kamper i samme runde.
  - **2 lag:** K2 opprettes ikke, men K3/K4 peker på K2-id-en, så puljen blir aldri ferdig.
  - **1 lag** (f.eks. 17 lag): ingen kamper, og K3/K4 peker på kamper som ikke finnes.

  NVBF-tabellen (vedlegg 3) legger lag 17–19 som 5. lag i puljene 1–3.
- **Forslag:** Avvis lagantall som ikke støttes, med en tydelig melding, eller implementer tabellen. Bestemmes etter svar på S3.
- **Risiko:** Endrer oppførsel.
- **Vurdering:** Faktisk bug.

### B8 · Sluttspill lages bare for 4 eller 8 puljer, men meldingen sier noe annet · `tournament_control_page.dart:513, 628, 687, 897`
- **Problem:** For 3, 5, 6, 7 eller 9+ puljer opprettes ingen sluttspill, men meldingen sier «grupper + sluttspillkryssninger generert».
- **Forslag:** Vis en egen melding når det ikke finnes noe sluttspillsoppsett (eller blokker, se S3).
- **Risiko:** Endrer oppførsel (tekst).
- **Vurdering:** Misvisende. Grensen på 4/8 puljer er trolig med vilje.

### B9 · Seeding-forhåndsvisningen viser andre puljer enn genereringen · `tournament_control_page.dart:4064-4072` mot `:426-437`
- **Problem:** Forhåndsvisningen bruker én slangelinje over alle puljene. Genereringen bruker blokker på 16 lag fordelt på 4 puljer. Eksempel med 32 lag: seed 5 vises som «Pulje H», men havner i Pulje D.
- **Forslag:** Lag én felles funksjon `serpentineGroupIndex(seedIdx, numGroups)` og bruk den begge steder.
- **Risiko:** Endrer oppførsel (bare visning, som da stemmer med virkeligheten).
- **Vurdering:** Faktisk bug.

### B10 · Uavgjort resultat gir seier til bortelaget · `tournament_control_page.dart:928, 988, 1255-1256` / `functions/src/index.ts:34-36`
- **Problem:** `homeWins = home > away`. Ved 1–1 eller 0–0 (f.eks. en tastefeil i «Overstyr resultat») vinner lag B uten varsel.
- **Forslag:** Valider i redigeringsdialogen at resultatet ikke er likt og er 2–0, 2–1, 1–2, 0–2 eller 1–0/0–1 (walkover).
- **Risiko:** Endrer oppførsel.
- **Vurdering:** Edge case. Sannsynligvis ikke tenkt på.

### B11 · Harde `as int?`-cast på tallfelter · mange steder
- **Problem:** Blant annet `home_score` (`tcp:928, 988, 1611, 2083, 4387, 4595, 4980`), `seed`, `match_number`, `group_placement` (`tcp:960`), `combined_ranking` (`registrations_page.dart:148, 168, 430-432, 441`) og `max_teams` (`registrations_page.dart:657`). Kommer et felt noen gang som `double` (f.eks. fra en annen klient eller en manuell redigering i konsollen), krasjer bygget. Andre steder brukes allerede `(x as num?)?.toInt()`.
- **Forslag:** Bruk en felles hjelper, `int intOf(Object? v, [int d = 0]) => (v as num?)?.toInt() ?? d;`.
- **Risiko:** Trygg (identisk resultat for heltall).
- **Vurdering:** Latent risiko.

### B12 · Manglende feilhåndtering ved skriving til Firestore
- **Problem:** Disse skrivingene har ingen `try/catch`, så brukeren får ingen tilbakemelding og en eventuell spinner henger:
  - `registrations_page.dart:87-96, 132-138, 592-597`
  - `tournament_control_page.dart:278-288` (`.then` uten `catchError`), `:350`, `:1120-1132`, `:1223-1227`, `:1249-1261`, `:1347`, `:4927`, `:4934-4948`
  - `all_players_page.dart:157-170, 255, 285, 302, 373`
  - `edit_tournament_page.dart:646-651, 669, 676, 811, 846, 900`

  Lytteren kaller dessuten `_resolvePendingMatches` uten `await` og uten `catchError` (`tcp:105`), og `.listen` har ingen `onError` (`tcp:84`).
- **Forslag:** Vis en feilmelding med samme `_snack(..., isError: true)` som allerede brukes.
- **Risiko:** Lav (bare nytt feilvarsel).
- **Vurdering:** Faktisk mangel.

### B13 · `BuildContext`/`setState` brukes etter `await` uten `mounted`-sjekk
- **Problem:**
  - Analyzer: `all_players_page.dart:279`, `tournament_control_page.dart:272, 4939, 4947`.
  - I tillegg `_snack` etter `await` i `tcp:513, 537, 314, 338, 1132, 1280, 1450, 3999, 4728, 4929`.
  - `setState` i `addPostFrameCallback` uten `mounted` (`tcp:3349-3351`, mens `:3766-3768` har sjekken).
  - `admin_login_page.dart:33-39` kaller `setState` i `catch` uten `mounted`.
- **Forslag:** `if (!mounted) return;` før bruk.
- **Risiko:** Trygg.
- **Vurdering:** Latent krasj («setState() called after dispose»).

### B14 · Firestore-strømmer opprettes i `build()` og settes opp på nytt ved hver rebuild
- **Problem:** `.snapshots()` gir en **ny** `Stream` hver gang. `StreamBuilder` ser da en ny strøm, avslutter den gamle lytteren og starter en ny. Eksempler:
  - `TournamentControlPage._buildHeader` (`tcp:2285-2299`): 5 lyttere, pluss 2–6 til i aktiv fane (`:1715, 1725, 2571-2583, 3339, 3355, 3756-3762, 3878-3886`). **Hvert tastetrykk** i «Søk lag eller kampnr» (`:1905`) eller «Søk lag eller spiller» (`:3518`) kaller `setState` og river ned og setter opp alle sammen på nytt.
  - `AdminDashboard` (`main.dart:166-190`): nye strømmer ved hvert tastetrykk i søket.
  - `_TournamentRow` (`main.dart:886-887`): `setState` ved hover bygger `_TourStatsBuilder` på nytt med 3 nye strømmer (`main.dart:535-541`) **for hver hover-endring**.
- **Forslag:** Lag strømmene én gang (`late final` i `initState`, eller en liten `TournamentStreams`-klasse) og send dem videre. Dataflyten blir identisk, men med færre gjenoppkoblinger.
  ```dart
  // før (i build)
  stream: db.collection('matches').where('tournament_id', isEqualTo: widget.tournamentId).snapshots(),
  // etter
  late final _matches$ = db.collection('matches').where('tournament_id', isEqualTo: widget.tournamentId).snapshots();
  ...
  stream: _matches$,
  ```
- **Risiko:** Må testes (live-oppdatering må fortsatt virke i alle faner).
- **Vurdering:** Ikke minnelekkasje (StreamBuilder rydder), men unødvendige lesninger, flimring og tregere UI.

### B15 · Samme spørring lyttes på mange steder samtidig
- **Problem:** `matches where tournament_id` lyttes av den ferdig-filtrerte lytteren (`:79`), headeren (`:2292`), oversikten (`:2571`), kampprogrammet (`:1725`), klasse-filteret (`:3355`) og klasselisten (`:3762`). Firestore-SDK-en slår delvis sammen identiske spørringer, men koden blir uoversiktlig.
- **Forslag:** Løses sammen med B14.
- **Risiko:** Må testes.

### B16 · «Nullstill» etterlater `events` · `tournament_control_page.dart:1120-1131`
- **Problem:** Kampene slettes, men ikke `matches/{id}/events`. Det blir foreldreløse dokumenter. `_deleteTournamentCascade` (`main.dart:1543-1546`) gjør dette riktig.
- **Forslag:** Gjenbruk mønsteret fra kaskadeslettingen, med batching på 450.
- **Risiko:** Lav.
- **Vurdering:** Faktisk bug (datasøppel, ikke synlig).

### B17 · Batch-grensen på 500 operasjoner ignoreres
- **Problem:** `all_players_page.dart:207-255, 281-285, 297-302`, `registrations_page.dart:132-138`, `tcp:4936, 4944, 1120`. Med mer enn 500 dokumenter feiler hele committen.
- **Forslag:** Bruk den samme chunk-løkken som `main.dart:1554-1560`.
- **Risiko:** Lav.
- **Vurdering:** Latent. Inntreffer først ved over 500 spillere.

### B18 · Farlige testverktøy i produksjons-UI · `all_players_page.dart:196-305, 370-375`; `tournament_control_page.dart:299-339, 3434-3468`
- **Problem:**
  - «Gjør alle anonyme & legg til 20 tullespillere» **overskriver navnet og kjønnet til alle ekte spillere**, uten bekreftelse. Unntaket er hardkodet til eierens navn.
  - «Tilfeldigiser poeng» overskriver alle `ranking_points` uten bekreftelse.
  - Søppelbøtta på en spiller sletter umiddelbart.
  - «Auto-generer 16 testlag» står i Lag-fanen.
- **Forslag:** Fjern, eller vis bare i `kDebugMode`. Legg til bekreftelse ved sletting av spiller.
- **Risiko:** Endrer oppførsel.
- **Vurdering:** Med vilje som utviklerverktøy, men stor risiko for datatap. **Spørsmål S4.**

### B19 · Redigering endrer typenavnet for NM · `edit_tournament_page.dart:45-55, 193` mot `add_tournament_page.dart:83-91`
- **Problem:** Opprettelse lagrer `tournament_type_label: 'Norgesmesterskap'`, men redigering har sin egen tabell med `'nm': 'NM'`. Å lagre en NM-turnering endrer etiketten, noe som påvirker typefilteret på oversikten og teksten i spillerappen. Redigering oppdaterer heller ikke `ranking_category` når typen endres.
- **Forslag:** Bruk `_tournamentTypes` fra opprettelsen begge steder (gjør den offentlig) og sett `ranking_category` ved typeendring.
- **Risiko:** Endrer oppførsel (data).
- **Vurdering:** Sannsynlig bug.

### B20 · `ranking_category` ser feil ut og leses aldri · `add_tournament_page.dart:49, 59, 109`
- **Problem:** `nt_open` → `'RT Open sr og jr'` og `nt_topp_x` → `'NT Open'`, mens rankingtabellen har egne kolonner for «NT Open» og «NT Master». Feltet leses ikke av admin, appen eller livescore.
- **Risiko:** Endrer oppførsel (data).
- **Vurdering:** Uklart. **Spørsmål S5.**

### B21 · Divisjonsinnstillingene brukes ikke · `add_tournament_page.dart:298-299, 704-750`; `edit_tournament_page.dart:194-195, 450-474`
- **Problem:** UI-et forklarer «Seed 1–N → 1. div (A) … Seed N+1–2N → 2. div (B)», men `has_division_play` og `div1_size` leses aldri. Genereringen bruker alltid faste blokker på 16. `max_teams_total` og `max_teams_per_category` håndheves heller ikke.
- **Risiko:** Endrer oppførsel (enten fjerne UI-et eller implementere logikken).
- **Vurdering:** Uferdig funksjon. **Spørsmål S5.**

### B22 · Dobbeltklikk lagrer to ganger
- **Problem:** `add_tournament_page.dart:249, 814` har ikke noe `_isSaving` og kan opprette to like turneringer. Det samme gjelder godkjenning av krav (`player_claims_page.dart:141`), spillerdialogen (`all_players_page.dart:136`) og «Ny klasse» (`edit_tournament_page.dart:897`).
- **Forslag:** Bruk samme `_isSaving`-mønster som `edit_tournament_page.dart:43, 176`.
- **Risiko:** Lav.
- **Vurdering:** Faktisk bug.

### B23 · Turnering og klasser lagres i to separate skrivinger · `add_tournament_page.dart:308, 310-336`
- **Problem:** Feiler den andre skrivingen, finnes turneringen uten klasser.
- **Forslag:** `final tourRef = db.collection('tournaments').doc();` og legg alt i samme batch.
- **Risiko:** Lav.
- **Vurdering:** Edge case.

### B24 · Valgte baner overlever en reduksjon i antall baner · `add_tournament_page.dart:591, 630, 651-664`; `edit_tournament_page.dart:613, 640`
- **Problem:** Velger man bane 7–8 og så reduserer til 6 baner, lagres `court_numbers: [7, 8]`, og `schedule_logic` setter opp kamper på baner som ikke finnes.
- **Forslag:** Filtrer `court_numbers` mot `courts_count` ved lagring.
- **Risiko:** Endrer oppførsel.
- **Vurdering:** Edge case.

### B25 · Datovelgeren kan krasje · `add_tournament_page.dart:213-227`; `edit_tournament_page.dart:132-145`
- **Problem:** `firstDate: DateTime(2024)` og `lastDate: DateTime(2030)`. Er `initialDate` utenfor intervallet (en turnering før 2024, eller fra 2030), utløses en assert i `showDatePicker`. Redigeringssiden lar også sluttdato havne før startdato (opprettelsen håndterer det på `:233`).
- **Forslag:** Klem `initialDate` inn i intervallet og gjenbruk sjekken fra opprettelsen.
- **Risiko:** Lav.
- **Vurdering:** Latent bug (aktuelt fra 2030).

### B26 · «Bytt Lag A ↔ Lag B» på en ferdig eller ventende kamp · `tournament_control_page.dart:1209-1216, 1270-1281`
- **Problem:** Lagfeltene byttes, men ikke resultatet eller `*_from_*`-referansene. På en ferdig kamp bytter vinneren side. På en `pending`-kamp løses slotene senere feil.
- **Forslag:** Tillat bare bytte når `status == 'scheduled'`, eller bytt alle feltene, også `from_*`.
- **Risiko:** Endrer oppførsel.
- **Vurdering:** Trolig ikke tenkt på. **Spørsmål S6.**

### B27 · Seed-bytte etter generering skriver om ferdige kamper · `tournament_control_page.dart:4843-4930`
- **Problem:** Lag-id-er byttes i **alle** kampene i klassen, også `finished`. Resultathistorikken skrives dermed om.
- **Forslag:** Bytt bare i kamper som ikke er startet, eller blokker bytte når en kamp er startet.
- **Risiko:** Endrer oppførsel.
- **Vurdering:** Uklart. **Spørsmål S6.**

### B28 · «Flytt til pulje» oppdaterer ikke kampene · `tournament_control_page.dart:1285-1355`
- **Problem:** Lagets `group` endres, men kampene i puljen beholder det gamle laget. I tillegg lages `TextEditingController` inne i `StatefulBuilder`-builderen (`:1318`), så markøren hopper når dropdownen endres.
- **Risiko:** Lav (controller) / Endrer oppførsel (kamper).
- **Vurdering:** Uklart. **Spørsmål S6.**

### B29 · Seed-numrene på påmeldingssiden blander klassene · `registrations_page.dart:143-151, 436-447`
- **Problem:** Fanen «Oversikt» og «Seeding-preview» rangerer alle godkjente påmeldinger i hele turneringen sammen (Menn og Damer i samme liste). Sorteringen gjøres dessuten på nytt for **hvert kort** (O(n² log n)).
- **Forslag:** Grupper per `category_id`, og regn ut seed én gang per snapshot.
- **Risiko:** Endrer oppførsel (visning).
- **Vurdering:** Sannsynlig bug.

### B30 · Godkjenning av spillerkrav · `player_claims_page.dart:10-39, 102-103`
- **Problem:** Er `uid` tom, kaster `doc('')`. Det sjekkes ikke om spilleren allerede er koblet til en annen bruker, og andre ventende krav på samme spiller står igjen.
- **Risiko:** Endrer oppførsel.
- **Vurdering:** **Spørsmål S7.**

### B31 · `AuthGate` henter admin-dokumentet ved hver rebuild · `main.dart:54-58`
- **Problem:** `future:` opprettes i `build`. I praksis bygges den sjelden på nytt, men mønsteret er feil. Admin-status sjekkes dessuten bare én gang per innlogging.
- **Forslag:** Gjør `AuthGate` stateful og cache future per `uid`.
- **Risiko:** Lav.
- **Vurdering:** Mindre viktig.

### B32 · «Publisert» leses bare fra første klasse · `main.dart:549-550`; `tournament_control_page.dart:2307`
- **Problem:** En ny klasse lagt til via «Ny klasse» (`edit_tournament_page.dart:900-906`) får ikke `published`. Status kan da bli blandet, men vises ut fra første dokument (tilfeldig rekkefølge).
- **Risiko:** Lav / Endrer oppførsel.
- **Vurdering:** Uklart om publisering skal være per klasse. **Spørsmål S8.**

### B33 · Controllere ryddes ikke opp i dialoger (liten minnelekkasje)
- **Problem:** `all_players_page.dart:20-27`, `edit_tournament_page.dart:767-768, 850`, `tournament_control_page.dart:1139-1142, 1287, 1318`.
- **Forslag:** Kall `dispose()` når dialogen er lukket (`showDialog(...).then((_) => ctrl.dispose())`), eller bruk en `StatefulWidget`-dialog.
- **Risiko:** Trygg.
- **Vurdering:** Mindre viktig.

### B34 · Merknad om livescore (ikke dette repoet)
`norgestourlivescore/.../main.dart:860-874` setter `group_placement` bare for `match_type` `group_final`/`group_bronze`, mens admin genererer `group_match_3`/`group_match_4`. Blokken er død i livescore, og plasseringene kommer fra `matchRunner` og admin. Ingen endring her, men nyttig å vite ved B2.

---

## 6. Funn – Død kode

Alle punkter er verifisert med `grep -w` over `lib/` og `test/`. Prosjektet har ingen navngitte ruter (`routes:`, `pushNamed` og `onGenerateRoute` finnes ikke), ingen refleksjon og ingen dynamiske imports. All navigasjon går via `MaterialPageRoute` med direkte klassereferanser.

| ID | Hva | Fil:linje | Bevis | Risiko |
|---|---|---|---|---|
| **D1** | Hele filer som aldri importeres: `simulator_logic.dart` (218), `category_schedule_editor.dart` (177), `tournament_schedule_page.dart` (929) | – | 0 imports i `lib/` og `test/` | Trygg |
| **D2** | `match_control_page.dart` (412). Importeres bare av `tcp:6` og brukes bare i `_buildMatchRow` (`tcp:5393`), som selv er død (D3). Inneholder en tredje kopi av avansement-logikken. | `tcp:6, 5393` | Kun nåbar fra død kode | Trygg (spørsmål S9) |
| **D3** | Døde metoder i `tournament_control_page.dart` (≈1 190 linjer): `_matchRoundOrder`, `_fmtMinutes`, `_autoScheduleForCategory` (`:1036-1088`, duplikat av `schedule_logic.dart`); `_buildPlayoffsTab_UNUSED`, `_buildVisualBracket`, `_bracketCard` (`:1374-1709`); `_buildOppsettWrapper`, `_buildOppsettWrapperForCategory` (`:3083-3333`); `_oppsettRoundLabel`, `_oppsettSectionHeader`, `_buildOppsettMatchRow` (`:4950-5062`); `_buildGroupsTab_DELME`, `_buildGroupsDisplay`, `_statHeader`, `_statCell`, `_buildMatchRow` (`:5064-5404`); `_BracketPainterTopDown` (`:5407-5498`) | se kolonnen | `flutter analyze` (unused_element) + transitiv sjekk | Trygg |
| **D4** | Imports som blir ubrukte etter D3: `dart:math show max` (`tcp:2`, brukes bare `:1522`), `match_control_page.dart` (`tcp:6`) | `tcp:2, 6` | – | Trygg |
| **D5** | Ubrukte variabler og parametere: `isPlaceholder` (`tcp:4977`, analyzer); `_selectedCategoryName` (`registrations_page.dart:26`, settes aldri); parameteren `index` i `_buildRegistrationCard` (`registrations_page.dart:424`); `tournamentType` på `RegistrationsPage` (`registrations_page.dart:9`, leses aldri), som gjør at `_openRegistrations` (`tcp:2198-2209`) gjør en **unødvendig Firestore-lesing**; `courtsCount` i `_CategoryAdminDialog` (`edit_tournament_page.dart:699`); `wrapInContainer` (`admin_dashboard_overview.dart:19`, dokumentert som ubrukt) | se kolonnen | grep | Trygg |
| **D6** | `schedule_logic.dart`: `autoScheduleCategory` (`:281-299`), `CategorySchedule.toMap`/`copyWith`/`roundKeys`/`roundLabels` brukes bare av D1-filene | `:16-27, 52-61, 281-299` | grep | Trygg (etter D1) |
| **D7** | Tema: `AppTheme.light` og `AppTheme.dark` (`app_theme.dart:48-239`, ≈190 linjer; bare `admin` brukes); ubrukte farger `sand1, coralGlow, greenLight, nightSurface1, nightSurface2, nightInk2, heroCoral, heroMix, cardInk` (`app_colors.dart:13-68`); `AppText.dispScoreLight`, `dispH1Light`, `monoSmLight`; `Responsive.isTabletOrSmaller`, `contentPaddingInsets`; `ResponsiveBuilder`/`ResponsiveConstraintsBuilder`/`ResponsiveWidget` brukes bare av tester | `lib/theme/*` | grep | Trygg teknisk, men tema er en kopi av appens designsystem (spørsmål S10) |
| **D8** | Pakker: `firebase_storage`, `image_picker`, `cupertino_icons` | `pubspec.yaml` | 0 imports | Lav (krever `pub get`, endrer `pubspec.lock`) |
| **D9** | Utdatert dokumentasjon: `lib/theme/README.md` er en «Dart-kommentar»-fil med en løs `import`-linje (`:13`), gammel `google_fonts ^6.2.1` og `AppTheme.light`; `norges_tour_admin/README.md` er Flutter-boilerplate | – | – | Trygg |
| **D10** | `assets/images/*` (15 filer, **15 MB**) refereres ikke fra `lib/` eller `web/`, men bundles via `pubspec.yaml: assets: - assets/images/` | `pubspec.yaml` | grep på alle filnavn | Lav (spørsmål S11) |
| **D11** | Test `challenger_mobile_navigation_test.dart` (17 linjer) tester bare Flutters egen `tester.view`, ikke appen. Testfilnavnene (`adversarial_m1_it3_…`) er agent-artefakter. | `test/` | – | Trygg (spørsmål S12) |

---

## 7. Funn – Forenkling

| ID | Duplikat eller problem | Steder | Forslag | Risiko |
|---|---|---|---|---|
| **F1** | Parsing av `dd.MM.yyyy` | `main.dart:424-433`, `admin_dashboard_overview.dart:92-101`, `edit_tournament_page.dart:114-127`, `tcp:2335-2341`, `:1750-1754`, `:2655-2662`, `:2153-2157`, `main.dart:569-580` | Én `DateTime? parseNoDate(String?)` og `String fmtNoDate(DateTime)` i `lib/utils/dates.dart` | Trygg (hvis resultatene er like, også reserveteksten) |
| **F2** | Formatering av datoperiode | `main.dart:450-460`, `tcp:2334-2348` | Felles `formatDateRange(..., withYear:)`. **Merk:** utdataene er like for gyldige datoer, men reserveteksten ved ugyldig dato er ulik (`'? - ?'` mot ikke-tomme verdier skilt med `' – '`). Den forskjellen må beholdes via et parameter | Lav |
| **F3** | Kort dato `dd.MM` | `main.dart:462-467`, `admin_dashboard_overview.dart:103-108` | Én funksjon | Trygg |
| **F4** | Live-score-linje | `main.dart:470-478` (skille `'  '`), `tcp:2182-2190` (skille `' · '`) | Én funksjon med `separator`-parameter | Trygg |
| **F5** | Etikett for rundenavn (`r16` → «1/16» …), 4 varianter | `tcp:1776-1785` og `:1800-1808` (identiske if-kjeder), `:2176`, `:4537-4544`, `:4950-4953` (død) | Én `const roundLabels`-map per visningsstil, og én `_roundFilterLabel(d)` brukt både til filterlisten og filtreringen | Trygg |
| **F6** | Sortering av brackets A/B/C/D, 4 kopier | `tcp:1410-1423` (død), `:3130-3136` (død), `:3194-3201` (død), `:4546-4559` | `int bracketCompare(String a, String b)` | Trygg |
| **F7** | Kopiering av de 6 lagfeltene (`name`, `id`, `p1_name`, `p1_id`, `p2_name`, `p2_id`) mellom prefikser | `tcp:993-998`, `:1009-1014`, `:1273-1278`, `:4892-4921`, `:165-176`, `functions/src/index.ts:84-91` | `Map<String,dynamic> teamSlot(String prefix, {name,id,p1,p2...})` | Trygg |
| **F8** | `tournament_control_page.dart` (5 497 linjer) | – | Del opp **uten logikkendring** (flytt, ikke skriv om): `tournament_generation.dart` (`_generateGroupStage`, `_addPlayoffsToBatch`, `_pendingGroupMatch`, `_buildGroupMatch`), `tournament_resolver.dart` (`_resolvePendingMatches`), `tabs/overview_tab.dart`, `tabs/schedule_tab.dart`, `tabs/setup_tab.dart`, `tabs/teams_tab.dart`, `dialogs/match_edit_dialog.dart`. Rene funksjoner kan bli toppnivå og enhetstestes. | Må testes |
| **F9** | `_addPlayoffsToBatch` har ≈30 nesten like `batch.set(r[n]!, mkPlayoff(...))` | `tcp:636-895` | Tabelldrevet: `const _playoff8 = [ (n:1, br:'A', rd:'omspill', next:101, slot:'b', a:G(0,4), b:G(4,1)), ... ]` og én løkke. Gjør oppsettet lettere å sammenligne med vedlegg 4 | Må testes (sammenlign generert JSON før og etter) |
| **F10** | Samme `KPI`/«fase»-utregning per klasse to steder | `tcp:2711-2748` og `:3811-3856` | Én `_categoryPhase(matches)` | Trygg |
| **F11** | Sidemeny og drawer har 3 nesten like fliser hver | `admin_shell.dart:281-307`, `:514-589` | Løkke over `AdminNavDestination.values` | Trygg |
| **F12** | Overflødige ternærer med lik verdi i begge grener | `admin_shell.dart:526-528, 552-554, 578-580` (`adminSidebarText : adminSidebarText`), `registrations_page.dart:47-58` (tre case gir `adminPrimary`), `:198-203` (`<=4` og `<=16` gir samme farge) | Fjern grenene | Trygg |
| **F13** | Redundant validering | `edit_tournament_page.dart:187-190` (`if (_startTime != null)` etter at det er validert), `:191` parser `int.tryParse` på nytt i stedet for `mt` | Bruk `mt` og fjern `if` | Trygg |
| **F14** | Seed-sortering av påmeldinger kopieres og kjøres per kort | `registrations_page.dart:147-151`, `:437-444` | Beregn én gang per snapshot (se B29) | Trygg (samme resultat) |
| **F15** | Lister over turneringstyper finnes to steder | `add_tournament_page.dart:31-122`, `edit_tournament_page.dart:45-55` | Én kilde (se B19) | Trygg hvis etikettene beholdes, Endrer hvis NM-etiketten rettes |
| **F16** | `_autoScheduleForCategory` (død) dupliserer innhenting av `interleave` | `tcp:1063-1088` | Slettes (D3) | Trygg |
| **F17** | Dyp nesting av `StreamBuilder` (5 nivåer) | `tcp:2285-2331`, `:2569-2962`, `main.dart:534-607` | Etter B14: kombinér med `StreamBuilder` over en sammensatt strøm, eller en `ChangeNotifier`-«TournamentData» | Må testes |
| **F18** | `_publishCategory`/`_unpublishCategory` er nesten identiske | `tcp:4934-4948` | `_setPublished(bool)` | Trygg |

---

## 8. Funn – Lesbarhet

| ID | Problem | Sted | Forslag | Risiko |
|---|---|---|---|---|
| **L1** | `if/else if`-kjeder uten krøllparenteser (10 analyzer-merknader) | `tcp:1780-1784`, `:1803-1807` | Forsvinner med F5 | Trygg |
| **L2** | Metodenavn som bryter konvensjonen | `_buildPlayoffsTab_UNUSED`, `_buildGroupsTab_DELME` | Slettes (D3) | Trygg |
| **L3** | Magiske strenger brukt overalt | `'placeholder'` (≈25 steder), statuser `'pending'/'scheduled'/'live'/'finished'`, QR-URL (`tcp:360`), `'all'`/`'alle'` som sentinel | `lib/model/match_fields.dart` med `const kPlaceholder = 'placeholder'` osv. **Verdiene er de samme**, bare navngitte | Trygg |
| **L4** | Norsk/engelsk blanding og ulike sentinelverdier: `'all'` for klasse mot `'alle'` for andre filtre; metodenavn `_buildOppsett…` mot `_buildSchedule…`; kommentarer på begge språk | `tcp` | Velg ett språk for kode og ett for UI-tekst, og ett sentinel-navn | Trygg (internt) |
| **L5** | Misvisende kommentarer | `tcp:54` «NavigationRail-indeks» (det er ingen NavigationRail); `edit_tournament_page.dart:435` «KAPASITET» står over klasse-planleggingen; `main.dart:3` «brukes i AdminDashboard» (brukes også i AuthGate); `tcp:1374` peker til død kode; `README.md:27-31` (se B2) | Rett teksten | Trygg |
| **L6** | Manglende kommentar der logikken ikke forklarer seg selv | `tcp:426-437` (16-lags blokk-serpentine, henvis til vedlegg 3); `:687-708` (bra); `:928` og `functions/index.ts:34` (at `home_score` = sett når kampen er ferdig, se §3.4); `:973` (hvorfor `scheduled` hoppes over) | Kort kommentar med regelhenvisning | Trygg |
| **L7** | **Tegnkodingsfeil i UI-tekst** (synlig for brukeren) | `add_tournament_page.dart:618` «pǾ» (skal være «på»), `:670` «Frste» (Første); `edit_tournament_page.dart:589` «pǾ», `:607` «p siden frst» (på siden først), `:795, 883` «Kjnn» (Kjønn), `:799, 887` «Mix (pen)» (Mix (åpen)) | Rett teksten | Endrer oppførsel (kun tekst) |
| **L8** | Inkonsekvent ordlyd i UI | Entall og flertall mangler i `main.dart:1386` («1 kamper pågår») mot `:713`; «Venter...» mot «Venter»; farge på destruktive knapper: `adminPrimary` (`tcp:1104`, `edit_tournament_page.dart:739, 839`) mot `adminDanger` andre steder | Harmoniser (etter godkjenning) | Endrer oppførsel (UI) |
| **L9** | Mappestruktur: alle sider ligger flatt i `lib/` | – | `lib/pages/`, `lib/widgets/`, `lib/logic/` (generering, resolver, schedule), `lib/utils/`. Flytting endrer bare import-stier | Trygg (men gjør diffen stor: egen commit) |
| **L10** | Gamle `console.log`/`print` | – | **Ingen funnet** i `lib/`, `test/` eller `functions/src` | – |
| **L11** | Utkommentert kode | – | Ingen blokker funnet. Den «utkommenterte» koden er i praksis de døde metodene i D3 | – |
| **L12** | Inkonsistent innrykk: `_publishCategory` har 4 mellomrom (`tcp:4934`), og `_buildScheduleTab`/`_buildDashboardTab` har feil innrykk inne i nestede builders (`:1737-2038`, `:2585-2951`) | – | `dart format` (egen commit, ren whitespace) | Trygg |

---

## 9. Spørsmål til deg

**S1 (B1).** Er `firestore.rules` i repoet det som faktisk er deployet? Spillerappen skriver til `users`, `registrations` og `player_claims`, som reglene bare tillater for admins. Skal strammere regler være en del av denne oppryddingen, eller en egen oppgave koordinert med livescore (som da må logge inn)?

**S2 (B2/B3).** Er det greit at avansement (K3/K4 i puljen, puljeplass → sluttspill, taper av omspill → B-sluttspill) bare skjer når en admin har turneringen åpen? Eller skal logikken flyttes til `matchRunner` nå? Skal siden løse ventende kamper automatisk når den åpnes?

**S3 (B7/B8).** Hvilke lagantall per klasse skal støttes? Bare 16 og 32 (4 og 8 puljer), som sluttspillet støtter i dag? Skal andre lagantall blokkeres med en melding, eller skal NVBF-tabellen (5-lagspuljer) implementeres?

**S4 (B18).** Kan testverktøyene fjernes fra produksjon, eller skal de skjules bak `kDebugMode`? Gjelder anonymisering og 20 tullespillere, tilfeldige poeng, slett alle spillere og auto-generer 16 testlag.

**S5 (B20/B21, §4).** Er `ranking_category`-verdiene for NT Open og NT Topp X med vilje? Skal divisjonsinnstillingene (`has_division_play`, `div1_size`) og trekning for seed 5–16 (NT Master/Open) implementeres, eller skal UI-teksten som lover det, fjernes? Hva skal skje ved poenglikhet i seeding?

**S6 (B26/B27/B28).** Skal «Bytt lag», «Bytt seed» og «Flytt til pulje» være mulig etter at kamper er spilt, eller bare før første kamp i klassen starter?

**S7 (B30).** Ved godkjenning av spillerkrav: skal andre ventende krav på samme spiller avvises automatisk, og skal det advares hvis spilleren allerede er koblet til en bruker?

**S8 (B32).** Skal publisering gjelde hele turneringen (som i dag: alle klasser samtidig), eller per klasse? Skal nye klasser arve publiseringsstatusen?

**S9 (D2).** `MatchControlPage` (manuell poengføring i admin) nås ikke lenger. Skal den slettes, eller kobles inn igjen (f.eks. fra kamp-dialogen)?

**S10 (D7).** Skal `lib/theme/` holdes som en speilkopi av appens tema, slik at ubrukte deler beholdes? Eller er det greit å trimme admin-kopien?

**S11 (D10).** Skal de 15 MB med bilder i `assets/images/` brukes til noe i admin, eller kan de fjernes fra dette repoet?

**S12 (D11).** Vil du beholde alle seks testfilene, eller slå dem sammen til færre med beskrivende navn (samme tester og dekning)?

---

## 10. Verifisering etter hver fase

1. `flutter analyze --no-pub`: ingen nye merknader (målet er færre enn dagens 23).
2. `flutter test --no-pub`: 76 av 76 grønne (eller flere, hvis rene funksjoner får enhetstester under F8).
3. `cd functions && npm run build`: TypeScript kompilerer (fase 4).
4. **Manuell røyktest** i Chrome mot en **testturnering**:
   - innlogging og utlogging,
   - opprette en turnering,
   - legge til 16 lag,
   - se seeding,
   - generere,
   - åpne QR,
   - registrere resultat (walkover) og se at K3/K4 fylles,
   - kampprogram med søk og filtre,
   - oversikt og klasseliste,
   - redigere turnering og klasser,
   - påmeldinger (godkjenn, venteliste),
   - godkjenne spillerkrav,
   - nullstille,
   - slette turneringen.
5. For F8/F9 (flytting og tabelldrevet sluttspill): generer samme turnering før og etter, og sammenlign kamp-dokumentene felt for felt (unntatt auto-id-er).

*Venter på godkjenning av hvilke punkter som skal gjennomføres.*
