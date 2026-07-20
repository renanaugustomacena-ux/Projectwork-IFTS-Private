## Constants — Global constants and enumerations for Relax Room.
class_name Constants

# Room identifiers
const ROOM_COZY_STUDIO := "cozy_studio"

# Room themes
const THEME_MODERN := "modern"
const THEME_NATURAL := "natural"
const THEME_PINK := "pink"

# Character identifiers
const CHAR_MALE_OLD := "male_old"

# Playlist modes
const PLAYLIST_SEQUENTIAL := "sequential"
const PLAYLIST_SHUFFLE := "shuffle"
const PLAYLIST_REPEAT_ONE := "repeat_one"
# Single-source playlist default (audit 4.1.18-L139). The music_state DDL
# default stays 'sequential' (schema migration not worth it); every read
# path funnels through this constant instead.
const DEFAULT_PLAYLIST_MODE := PLAYLIST_SHUFFLE

# Display modes
const DISPLAY_WINDOWED := "windowed"

# Supported languages
const LANGUAGES := {
	"en": "English",
	"it": "Italiano",
}

# Audio
const CROSSFADE_DURATION := 2.0

# Performance
const FPS_FOCUSED := 60
const FPS_UNFOCUSED := 15

# UI animation durations (seconds)
const PANEL_TWEEN_DURATION := 0.3
const FADE_DURATION := 0.5

# Auth
const AUTH_MIN_PASSWORD_LENGTH := 6
const AUTH_GUEST_UID := "local"
const AUTH_GUEST_EMAIL := "offline@local"
const AUTH_MAX_FAILED_ATTEMPTS := 5
const AUTH_LOCKOUT_SECONDS := 300  # 5 minutes
const AUTH_MAX_USERNAME_LENGTH := 50

# Supabase sync
const SUPABASE_SYNC_INTERVAL := 120.0
const SUPABASE_REQUEST_TIMEOUT := 15.0
const SUPABASE_MAX_RETRY := 5
## Pre-schema-freeze concession: when true, a missing cloud table (404 /
## PostgREST relation error) is skipped with a WARN instead of failing the
## sync. Flip to false once the Supabase schema is frozen so table-name
## typos surface as sync_error instead of silent data loss (audit 4.1.1-L300).
const SUPABASE_ALLOW_MISSING_TABLES := true

# Viewport resolution
const VIEWPORT_WIDTH := 1280
const VIEWPORT_HEIGHT := 720

# RNG determinism
# Debug build: seed costante → bug/issue report riproducibili
# Release build: randomize() → varieta` gameplay
const DEBUG_RNG_SEED := 0xC02E

# Mood thresholds (T-R-015i)
const MOOD_GLOOMY_THRESHOLD := 0.15
const MOOD_STORMY_THRESHOLD := 0.10

# Application version — synced da scripts/bump_version.sh
const APP_VERSION := "1.0.0"
