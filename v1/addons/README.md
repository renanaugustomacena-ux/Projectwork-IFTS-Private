# Mini Cozy Room — Plugin e Addon

> **Nota sulla Semplificazione**: Il plugin godot-sqlite e' utilizzato da `LocalDatabase`, che
> e' attualmente **over-engineered** (il salvataggio JSON basta). Se LocalDatabase venisse rimosso
> in futuro, anche questo addon potrebbe essere rimosso dal progetto, riducendo la dimensione
> del repository. Per ora resta necessario perche' LocalDatabase e' ancora attivo.

Questa cartella contiene i plugin Godot e i binari GDExtension utilizzati dal progetto.
Attualmente l'unico addon e **godot-sqlite**.

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

## Vedi Anche

- [README Database](../data/README.md) — Schema delle 7 tabelle usate con SQLite
- [README Script](../scripts/README.md) — `local_database.gd` che utilizza questo plugin
