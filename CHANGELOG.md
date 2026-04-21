# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Build/release pipeline production (Fase A-F): versioning centrale,
  keystore Android automation, export presets hardening, smoke-binaries
  gate, release workflow, CI gate.

## [1.0.0] - 2026-04-22

### Added
- **Prima release pubblica** di Relax Room
- Build Windows x64 (.exe standalone, `embed_pck=true`, no console wrapper)
- Build Android APK multi-arch (arm64-v8a + armeabi-v7a, Android 7.0+)
- Build HTML5 Web per browser moderni (zipped distribution)
- **Profile HUD** con immagine profilo locale (mai cloud, privacy-first)
- **Mood slider** 0-1 con effetti graduali: overlay gloomy, rain particles,
  pet berserk WILD state, audio crossfade
- **6 badge** sbloccabili via eventi di gioco (decorations_placed,
  mood_changes, stormy_mood, play_time)
- **i18n IT/EN** via .po files + `TranslationServer.set_locale()`
- **MoodManager** autoload (layer=5 overlay, rain.tscn scene, pet WILD FSM
  state, AudioManager.crossfade_to_mood_track)
- **BadgeManager** autoload + SQLite `badges_unlocked` table + catalog
  `badges.json`
- **Virtual joystick** gated `OS.has_feature("mobile")` (attivo solo
  Android/Web, dead-code su desktop)
- **PBKDF2 v3** password hashing 100k iter SHA-256 + migration trasparente
  v1/v2→v3 al login

### Changed
- **Save format v5.0.0** con dual-write atomico JSON + SQLite
- **Supabase client** exponential backoff su HTTP 429 (cap 5 min)
- **Autoload chain** 12 singleton: SignalBus → AppLogger → LocalDatabase →
  AuthManager → GameManager → SaveManager → SupabaseClient → AudioManager
  → PerformanceManager → StressManager → MoodManager → BadgeManager
- **local_database.gd** splittato in 9 moduli (repo pattern, B-033):
  db_helpers + schema + 7 repo (accounts/characters/inventory/rooms_deco/
  settings/sync_queue/badges). API pubblica 1:1 preservata
- **CI validators** 12 job green: lint + format + 8 validator + smoke +
  deep tests + button-focus + version sync + no-keystore guard

### Fixed
- **B-001** Movimento character bloccato (focus chain Godot 4.5/4.6)
- **B-002** Drag & drop decorazioni silent fail (DecoButton TextureRect)
- **B-003** Tab DecoPanel non cliccabili (focus_mode explicit)
- **B-004** Grid quadrati giganti in edit mode (viewport dinamico +
  `size_changed` redraw)
- **B-016** JSON/SQLite divergence (dual-write completo settings/music/
  room/decorations in transaction atomica)
- **B-021** Supabase 429 no-backoff (exponential `min(2^attempts*1000,
  300000)` ms reset su 2xx)
- **B-023** virtual_joystick dead code (mobile-gated)
- **B-024** CI no focus_mode check (new validator + fix 13 existing
  Button.new())
- **B-029** PBKDF2 10k→100k iter + v2→v3 migration chain
- **B-030** RNG non deterministico in debug build
- **B-033** local_database 894-line monolith splittato in 9 moduli

### Security
- PBKDF2 password hash 100k iter SHA-256 (OWASP trade-off per UX
  login responsiva)
- Migration trasparente v1/v2→v3 al primo login successful
- Profile image locale only (privacy-first, mai upload Supabase)
- Supabase publishable key: safe in repo pubblico (RLS-protected)
- Keystore release mai in repo: CI validator `validate_no_keystore.py`
  blocca commit accidentali
- Git commit author fixed: `Renan Augusto Macena` (no AI attribution)

### Known limitations (post-1.0.0 backlog)
- Storm ambient track non presente (`AudioManager.crossfade_to_mood_track`
  modula solo volume, no swap track)
- Badge icons: emoji unicode (pixel art PNG 24×24 post-demo)
- i18n refactor incompleto: solo ProfileHUDPanel in .po, resto UI
  hardcoded
- 63 Kenney PNG bathroom/kitchen/tiles non registrati in
  `decorations.json`

[Unreleased]: https://github.com/renanaugustomacena-ux/Projectwork-IFTS-Private/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/renanaugustomacena-ux/Projectwork-IFTS-Private/releases/tag/v1.0.0
