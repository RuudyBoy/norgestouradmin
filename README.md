# Spikedunk – Admin

Turneringsverktøyet for arrangører i Spikedunk, et hobbyprosjekt som digitaliserer norske sandvolleyballturneringer fra påmelding til resultat.

Spikedunk består av tre Flutter-apper som deler én Firebase-database:

| App | Repo | Brukes av |
| --- | --- | --- |
| **Admin** (dette repoet) | [norgestouradmin](https://github.com/RuudyBoy/norgestouradmin) | Arrangører |
| Dommerapp | [norgestourlivescore](https://github.com/RuudyBoy/norgestourlivescore) | Dommere ved banen |
| Spillerapp | [norgestourapp](https://github.com/RuudyBoy/norgestourapp) | Spillere og publikum |

Case study: [cjrportfolio.netlify.app/spikedunk](https://cjrportfolio.netlify.app/spikedunk)

## Hva appen gjør

- Oppretter turneringer og klasser, og behandler påmeldinger (godta, venteliste, avvis).
- Seeder lag etter spillernes rankingpoeng og genererer puljer med serpentine-seeding.
- Genererer hele sluttspillet på forhånd etter NVBF-oppsettet: A- og B-puljer, omspill, kryssseeding og sluttspill til finale.
- Fordeler kamper på baner og starttider per runde.
- Lager en QR-kode per kamp som dommeren skanner for å åpne dommerappen.
- Følger turneringen live: kamper som pågår, neste kamper og ting som trenger oppfølging.
- Godkjenner spillere som gjør krav på en spillerprofil i spillerappen.

## Hvordan det henger sammen

Hvert sluttspill er en lenket graf: hver kamp har `next_match_id` og `next_match_slot`. Når dommerappen setter en kamp til `finished`, flytter Cloud Function `matchRunner` vinneren videre til neste kamp og setter puljeplasseringer.

1. Admin skriver turneringer, lag og kamper til Firestore og viser en QR-kode per kamp.
2. Dommeren skanner QR-koden og fører kampen i dommerappen. Poeng og hver handling lagres i `matches/{id}` og `matches/{id}/events`.
3. Når kampen er ferdig, trigges `matchRunner`, som flytter vinneren videre.
4. Spillerappen leser alt i sanntid: live-resultater, kampprogram og statistikk.

## Struktur

```
norges_tour_admin/         Flutter-appen (web/desktop)
  lib/
    main.dart                    Oversikt og innlogging
    tournament_control_page.dart Turneringskontroll: lag, seeding, puljer, sluttspill, kampprogram
    schedule_logic.dart          Automatisk bane- og tidsoppsett
    registrations_page.dart      Påmeldinger
    player_claims_page.dart      Godkjenning av spillerprofiler
    theme/                       Farger, typografi og tema (designsystem)
  test/                    Widgettester for responsiv layout
functions/src/index.ts     Cloud Function matchRunner (TypeScript)
firestore.rules            Sikkerhetsregler for databasen
```

## Teknologi

Flutter og Dart · Firebase Auth · Cloud Firestore · Cloud Functions (Node 20, TypeScript) · Firebase Storage · qr_flutter

## Kjør lokalt

Krever Flutter (Dart SDK 3.9 eller nyere). Appen kobler seg til Firebase-prosjektet via `lib/firebase_options.dart`, og innlogging krever en bruker i `admins`-samlingen.

```bash
cd norges_tour_admin
flutter pub get
flutter run -d chrome
```

Cloud Functions:

```bash
cd functions
npm install
npm run deploy
```

## Status

Fungerende prototype, testet med demoturneringer. Ikke klar for ekte brukere ennå. Neste steg er strammere Firestore-regler, at all avansement-logikk ligger i Cloud Functions, en ryddigere kobling mellom bruker og spiller, og å dele opp `tournament_control_page.dart`.

Laget av Christian Jørgensen Ruud.
