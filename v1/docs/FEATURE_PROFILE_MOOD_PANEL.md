# Feature Cluster — Profile + Mood Panel HUD

**Owner**: Renan (architettura + integrazione core)
**Richiesta**: 2026-04-17
**Target**: post-demo (non implementabile in toto pre-demo del 17 Apr 9:00)
**Stato**: scope doc, non ancora in produzione

---

## Vision d'insieme

Un **mini pannello profilo orizzontale** accessibile dall'icona profilo vicino alla barra di stress nell'HUD in-game. Sostituisce/integra l'attuale `profile_panel.gd` standalone. Contiene:

1. **Immagine profilo** — scelta dal device locale, MAI caricata su Supabase (privacy first)
2. **Nome utente**
3. **Badge sbloccati** — riga orizzontale di icone
4. **Bottone settings** — apre `settings_panel.gd` esistente
5. **Language toggle** — IT ↔ EN con bandiere animate (blu+rosso → rosso+bianco+verde)
6. **Mood bar** — slider orizzontale: right = cozy originale / left = gloomy+dark. Al massimo sinistro: **pioggia + gatto che corre scompigliando la stanza**

Audio reattivo alla mood bar: a sinistra → track tempesta (asset da scaricare), a destra → track lo-fi cozy originale.

Estensibilita futura: nuove animazioni gatto + nuovi character aggiungeranno variabili al mood changer.

---

## Task cluster — 9 sub-tasks

### T-R-015 (parent) — Profile Mood Panel HUD
*Scope: orchestrazione della feature, ownership architetturale*

### T-R-015a (P2) — Icona profilo in GameHUD
- **Scope**: aggiungere `TextureButton` in `game_hud.gd` accanto a serenity bar + coin label. Icon default generica. Al click emette `SignalBus.profile_hud_requested` (nuovo signal).
- **File**: `v1/scripts/ui/game_hud.gd`, `v1/scripts/autoload/signal_bus.gd`
- **Tempo stimato**: 30 min

### T-R-015b (P2) — Mini ProfileHUDPanel scene + script
- **Scope**: nuova scena `v1/scenes/ui/profile_hud_panel.tscn` + script. PanelContainer anchored top-right, dimensione orizzontale compatta (es. 420x120). Si apre/chiude su `profile_hud_requested`.
- **Lifecycle**: usa `PanelManager` esistente (registrare key "profile_hud") OR sistema proprio (tween slide-in).
- **Tempo stimato**: 45 min

### T-R-015c (P1 dentro feature) — Profile image da device locale
- **Scope**: `FileDialog` Godot nativo, filter `*.png *.jpg *.jpeg`. Salvataggio persistente in `user://profile_image.png` (copia locale, mai cloud). Display come `TextureRect` circolare in ProfileHUDPanel.
- **Privacy**: documentare chiaramente nel tooltip "solo locale, non inviato online". Coerente con filosofia offline-first.
- **File**: `profile_hud_panel.gd` + helper `load_profile_image()`.
- **Schema DB**: NO cambio. Immagine su filesystem, non in SQLite/Supabase.
- **Tempo stimato**: 1 ora

### T-R-015d (P2) — Badge system
- **Scope**: data-driven via nuovo catalog `v1/data/badges.json` (entries: id, name, icon_path, unlock_condition). Display riga HBoxContainer di TextureRect 24x24 grayscale se lock / colore se unlock.
- **Stato**: richiede definire cosa sbloccare (es. "1h di gioco", "100 decorazioni posizionate", "ESC spammato 10 volte").
- **Schema DB**: aggiungere tabella `badges_unlocked(account_id, badge_id, unlocked_at)` in SQLite + mirror Supabase (B-032 roadmap).
- **Tempo stimato**: 2 ore (ma solo 45 min per scheletro senza logica unlock)

### T-R-015e (P2) — Settings button moved inside profile panel
- **Scope**: rimuovere (o nascondere) il bottone HUD "Opzioni" attuale, aggiungerlo dentro ProfileHUDPanel. `PanelManager.open_panel("settings")` da click.
- **File**: `v1/scripts/main.gd` (rimozione wiring HUD), `profile_hud_panel.gd` (aggiunta)
- **Tempo stimato**: 15 min

### T-R-015f (P2) — Language toggle IT/EN
- **Scope**: TextureButton con 2 stati visual:
  - Stato EN: icona bandiera UK (blu+rosso+bianco con pattern croci) + text "EN"
  - Stato IT: icona bandiera IT (verde+bianco+rosso vertical) + text "IT"
- **Asset necessari**: 2 PNG bandiera 32x24 (cerca su flaticon.com sezione free, o crea in pixel art stile gioco)
- **Logica**: click → toggle `SaveManager.get_setting("language")` tra "en" e "it" → emit `SignalBus.language_changed(lang_code)`
- **Tempo stimato**: 30 min (solo toggle, senza .po dietro)

### T-R-015g (P1 dentro feature) — i18n reale via .po files
- **Scope**: Godot `TranslationServer`. Crea `v1/locale/it.po` + `v1/locale/en.po` con tutte le stringhe UI marcate via `tr()`. Al `language_changed` → `TranslationServer.set_locale(lang)`.
- **Lavoro**: 50+ stringhe hardcoded sparse negli script UI → refactor a `tr("KEY")`. Estrazione + traduzione.
- **Tempo stimato**: 3-4 ore (big)
- **Dipendenza**: T-R-015f solo per trigger; la i18n reale richiede questo

### T-R-015h (P2) — Mood bar slider
- **Scope**: HSlider 0.0 → 1.0 in ProfileHUDPanel con pallina custom (TextureButton draggable). Value cambia in tempo reale, emette `SignalBus.mood_level_changed(value: float)`.
- **Persistenza**: salva ultimo valore in settings → `mood_level` key.
- **File**: `profile_hud_panel.gd` + nuovo signal in `signal_bus.gd`.
- **Tempo stimato**: 30 min

### T-R-015i (P1 dentro feature) — Mood visual effects pipeline
- **Scope**: `MoodManager` autoload che ascolta `mood_level_changed` e applica:
  - **Overlay ColorRect** sopra la stanza con alpha 0..0.5 blu/viola (gloomy filter). Full-screen CanvasModulate o ColorRect layer 5.
  - **Pioggia particle system** (scena `v1/scenes/effects/rain.tscn`) → istanziata in main scene quando `mood_level < 0.15`
  - **Cat berserk mode**: se `mood_level < 0.1`, override pet FSM → forza stato "run_wild" (nuovo stato) che fa il giro della stanza + trigger `SignalBus.mess_spawn_requested` ogni 5s
  - **Audio crossfade**: trigger `AudioManager.crossfade_to_mood_track()` con nuova track "storm" (asset download needed)
- **File**: `v1/scripts/autoload/mood_manager.gd` (nuovo), `v1/scenes/effects/rain.tscn` (nuovo), `v1/scripts/rooms/pet_controller.gd` (nuovo stato WILD), `v1/scripts/autoload/audio_manager.gd` (mood-based track switch)
- **Asset da scaricare/creare**:
  - `v1/assets/audio/storm_ambient.ogg` (tempesta, 30-60s loop)
  - `v1/assets/effects/rain_drop.png` (gocciolina pixel art 8x8)
  - Eventuale shader per gloomy filter (post-demo)
- **Tempo stimato**: 3-5 ore (con asset già pronti; altrimenti +2h per asset)

---

## Estendibilita future (menzionata)

User menziona di voler aggiungere:
- Nuove animazioni gatto (happy, scared, wet, sleeping_deep) → mood_manager mappa a variants
- Nuovi character (male_yellow dal prompts, altri) → profile image placeholder per character preview diventa config per stile mood visto

Architettura: gia pronta per estensione se MoodManager usa un dict `mood_profiles[character_id][mood_range]`.

---

## Tempo totale stimato

- **Scheletro minimo** (T-R-015a/b/e/f/h, no logica mood reale, no i18n): ~2.5 ore
- **Feature completa con mood effects** (+ T-R-015c/d/g/i): 10-14 ore
- **Con asset custom da generare** (bandiere, pioggia, tempesta track): +3 ore

---

## Integrazione con codice esistente

### Da riusare (NON toccare)
- `PanelManager` per open/close lifecycle
- `SignalBus` per tutti i nuovi signal (`profile_hud_requested`, `language_changed` gia esiste, `mood_level_changed` nuovo)
- `SaveManager.set_setting` per persistere mood_level + profile_image_path
- `AudioManager` per crossfade (estendere con `crossfade_to_mood_track(mood: float)`)
- `StressManager` — NON confondere con MoodManager. StressManager = gameplay interno (stress del personaggio). MoodManager = volontario dell'utente (atmosfera). Sono disaccoppiati.

### Da aggiungere al SignalBus
```gdscript
# Mood (user-controlled atmosphere, distinto da stress_changed)
signal mood_level_changed(mood: float)  # 0.0 (gloomy/stormy) → 1.0 (original cozy)

# Profile HUD
signal profile_hud_requested  # click icona in game_hud
signal profile_hud_closed     # chiusura panel
```

### Da aggiungere ai Constants
```gdscript
# Mood
const MOOD_GLOOMY_THRESHOLD := 0.15  # sotto → attiva pioggia
const MOOD_STORMY_THRESHOLD := 0.10  # sotto → cat wild mode
const MOOD_AUDIO_TRACK_STORM := "res://assets/audio/storm_ambient.ogg"
```

### Schema DB — addizioni

**SQLite** (locale):
```sql
CREATE TABLE IF NOT EXISTS badges_unlocked (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id INTEGER NOT NULL,
  badge_id TEXT NOT NULL,
  unlocked_at TEXT DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(account_id, badge_id),
  FOREIGN KEY(account_id) REFERENCES accounts(account_id) ON DELETE CASCADE
);
```

**Settings keys nuove**:
- `mood_level` (float 0..1, default 1.0)
- `language` (String "it"/"en", gia esiste)
- `profile_image_path` (String, default "")

**Supabase (post-demo, non necessario ora)**: mirror `badges_unlocked` se vuoi sync. Profile image rimane locale sempre (privacy-first).

---

## Approccio implementativo consigliato

**Fase 1 — Scaffold UI** (45 min, safe):
- T-R-015a (icona HUD)
- T-R-015b (panel scene + script vuoto con Label "Profilo" + posizionamento)
- NO logica → commit, smoke test, test user che l'apertura/chiusura funzioni

**Fase 2 — Contenuto statico** (1 ora):
- T-R-015e (move settings button)
- T-R-015h (mood slider senza effects → solo valore persistito)
- T-R-015f (language toggle con 2 asset placeholder e stato visivo, no i18n reale)
- Commit iterativo ogni 15-20 min

**Fase 3 — Feature logic** (post-demo):
- T-R-015c (profile image FileDialog + save locale)
- T-R-015i (MoodManager autoload + ColorRect filter, senza rain/cat-wild ancora)

**Fase 4 — Asset + polish** (post-demo):
- T-R-015d (badge system, richiede definire "cosa sblocca")
- T-R-015g (i18n reale via .po)
- Rain effect + storm audio + cat wild mode

---

## Referenze Godot 4.6 utili

- [FileDialog — Godot Docs](https://docs.godotengine.org/en/stable/classes/class_filedialog.html) per T-R-015c
- [TranslationServer](https://docs.godotengine.org/en/stable/tutorials/i18n/internationalizing_games.html) per T-R-015g
- [GPUParticles2D](https://docs.godotengine.org/en/stable/classes/class_gpuparticles2d.html) per rain T-R-015i
- [CanvasModulate](https://docs.godotengine.org/en/stable/classes/class_canvasmodulate.html) per gloomy filter
