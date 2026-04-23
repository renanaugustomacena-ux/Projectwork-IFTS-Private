# Relax Room — Plugin e Addon

> **Aggiornamento 17 Apr 2026**: LocalDatabase è attivamente usato per
> `accounts` (password_hash PBKDF2), `characters`, `rooms`, `inventario`,
> `sync_queue` (Supabase cloud retry), `settings`, `save_metadata`,
> `music_state`, `placed_decorations`. NON è più over-engineering — è
> l'infrastruttura per cloud sync + audit + multi-account. Sta rimanendo.

Questa cartella contiene i plugin Godot e i binari GDExtension del progetto.
**2 addon attivi**: godot-sqlite + virtual_joystick.

## godot-sqlite (GDExtension v4.7)

Wrapper GDExtension per SQLite, sviluppato da Piet Bronders & Jeroen De Geeter.

- **Licenza**: MIT
- **Compatibilita**: Godot 4.5+
- **Entry symbol**: `sqlite_library_init`
- **Utilizzato da**: `LocalDatabase` autoload (`scripts/autoload/local_database.gd`)

### Struttura

```
addons/
└── godot-sqlite/
    ├── bin/                                    # Binari per piattaforma
    │   ├── libgdsqlite.windows.*.dll           # Windows x86_64
    │   ├── libgdsqlite.linux.*.so              # Linux x86_64 + arm64
    │   ├── libgdsqlite.macos.*.framework/      # macOS universal
    │   ├── libgdsqlite.android.*.so            # Android arm64 + x86_64
    │   ├── libgdsqlite.ios.*.xcframework/      # iOS arm64
    │   ├── libgdsqlite.web.*.wasm              # WebAssembly (threads + nothreads)
    │   └── libgodot-cpp.ios.*.xcframework/     # Dipendenza godot-cpp per iOS
    ├── gdsqlite.gdextension                    # Dichiarazione piattaforme e librerie
    ├── godot-sqlite.gd                         # EditorPlugin (@tool stub)
    └── plugin.cfg                              # Metadati plugin
```

### Piattaforme Supportate

| Piattaforma | Architettura | Formato |
|-------------|-------------|---------|
| Windows | x86_64 | `.dll` |
| Linux | x86_64, arm64 | `.so` |
| macOS | Universal (arm64 + x86_64) | `.framework` |
| Android | arm64, x86_64 | `.so` |
| iOS | arm64 (+ simulator) | `.xcframework` |
| Web | wasm32 (threads + nothreads) | `.wasm` |

### Note

- I binari sono **pre-compilati** e committati nel repository (non compilati da sorgente)
- Il plugin viene attivato automaticamente da Godot tramite il file `.gdextension`
- Non richiede configurazione manuale: si carica in modo trasparente all'avvio del progetto
- Per iOS, e dichiarata la dipendenza aggiuntiva `libgodot-cpp` nel `.gdextension`

## virtual_joystick (CF Studios)

Addon originariamente in `projectwork-ifts/` parallelo, importato in v1.
Touch input simulato (funziona anche con mouse su desktop — utile per dev).

### Struttura

```
addons/
└── virtual_joystick/
    ├── scripts/
    │   └── virtual_joystick.gd
    ├── icon.png                 # editor icon
    └── plugin.cfg               # metadata
```

Instanziato via `scenes/ui/virtual_joystick.tscn`. Texture custom:
`assets/menu/ui/sprite_pad_base.png` + `sprite_pad_lever.png`.

**Stato**: incluso ma NON posizionato in `main.tscn` di default.
Decisione USE/REMOVE pending post-demo (B-023 open in backlog).

## Vedi anche

- [README data](../data/README.md) — schema 9 tabelle SQLite + cataloghi JSON
- [README scripts](../scripts/README.md) — `autoload/local_database.gd` + `autoload/supabase_client.gd`
- [AUDIT_REPORT 2026-04-23](../../AUDIT_REPORT_2026-04-23.md) — § 4.11.1 addon dependency audit
