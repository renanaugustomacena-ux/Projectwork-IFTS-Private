# Task per Mohamed e Giovanni — Game Assets & Core Logic

Questo documento contiene le task specifiche da completare per il progetto Mini Cozy Room.
Ogni sezione include istruzioni dettagliate passo-passo.

---

## TASK 1: Calibrazione Confini Movimento Personaggio (PRIORITA ALTA)

### Problema
Il personaggio puo camminare fuori dai limiti del pavimento isometrico della stanza.
I confini attuali sono approssimati e devono essere calibrati visivamente in Godot Editor.

### Come Funziona
La stanza usa un `StaticBody2D` chiamato `RoomBounds` con un nodo figlio
`CollisionPolygon2D` chiamato `FloorBounds`. Questo poligono ha `build_mode = 1`
(SEGMENTS), il che significa che i lati del poligono fungono da muri invisibili.
Il personaggio (`CharacterBody2D`) usa `move_and_slide()` e viene bloccato da questi segmenti.

### Istruzioni Passo-Passo in Godot Editor

1. **Aprire il progetto** in Godot Engine 4.5+
2. **Aprire la scena** `res://scenes/main/main.tscn`
3. **Nel pannello Scene Tree** (sinistra), navigare a:
   ```
   Main > Room > RoomBounds > FloorBounds
   ```
4. **Selezionare il nodo `FloorBounds`** (tipo: CollisionPolygon2D)
5. **Nell'Inspector** (destra), verificare:
   - `Build Mode` = `Segments`
   - `Polygon` = 4 punti (attualmente: 460,290 / 980,365 / 980,655 / 300,655)
6. **Nella viewport** (centro), i 4 punti appariranno come cerchi arancioni collegati da linee
7. **Attivare lo strumento Edit Polygon**: nella toolbar sopra la viewport, cliccare l'icona
   del poligono (o premere il tasto corrispondente)
8. **Trascinare ogni punto** per allinearlo al bordo del pavimento isometrico:
   - **Punto 1 (alto-sinistra)**: dove il muro posteriore incontra il muro sinistro a livello pavimento
   - **Punto 2 (alto-destra)**: dove il muro posteriore incontra il bordo destro della stanza
   - **Punto 3 (basso-destra)**: angolo in basso a destra del pavimento
   - **Punto 4 (basso-sinistra)**: angolo in basso a sinistra del pavimento
9. **Per aggiungere piu punti** (se servono per seguire curve):
   - Con lo strumento Edit Polygon attivo, cliccare su un segmento per inserire un nuovo punto
   - Utile se il bordo del pavimento non e perfettamente rettilineo
10. **Testare**: premere F5 (o F6 per testare solo la scena corrente)
    - Muovere il personaggio con WASD/frecce
    - Verificare che NON possa uscire dall'area del pavimento
    - Se passa attraverso un muro, aggiustare i punti del poligono
11. **Salvare** la scena (Ctrl+S)

### Note Tecniche
- Il pavimento isometrico NON e un rettangolo: ha linee diagonali dove i muri incontrano il pavimento
- Il muro posteriore ha una leggera pendenza (da sinistra a destra scende leggermente)
- Il muro sinistro ha una pendenza piu ripida
- Potrebbe servire un poligono con 5-6 punti per seguire bene la forma
- La stanza (`room.png`) e 180x155 pixel, scalata a 4x, centrata a (640, 360)
- L'immagine della stanza occupa: x=280..1000, y=50..670

### Riferimento Visivo
```
       Punto 1 -------- Punto 2
      /                        |
     /                         |
    /                          |
Punto 4 -------------- Punto 3

Il pavimento e un trapezio/parallelogramma isometrico.
I bordi superiore e sinistro sono diagonali.
```

---

## TASK 2: Popup Interazione Decorazioni (PRIORITA MEDIA)

### Problema
Quando si clicca su una decorazione piazzata nella stanza, non succede nulla di visibile.
Attualmente il sistema supporta solo: tasto destro per rimuovere, trascinamento per spostare.
Serve un popup con pulsanti per Eliminare, Ruotare e Ridimensionare.

### File da Modificare
- `res://scripts/rooms/decoration_system.gd`

### Implementazione Suggerita

1. **Nel file `decoration_system.gd`**, aggiungere una funzione per mostrare un popup:
   ```gdscript
   var _popup: PanelContainer = null

   func _show_popup(decoration: Sprite2D) -> void:
       if _popup != null:
           _popup.queue_free()

       _popup = PanelContainer.new()
       var vbox := VBoxContainer.new()

       var btn_delete := Button.new()
       btn_delete.text = "Elimina"
       btn_delete.pressed.connect(_on_delete.bind(decoration))

       var btn_rotate := Button.new()
       btn_rotate.text = "Ruota 90"
       btn_rotate.pressed.connect(_on_rotate.bind(decoration))

       var btn_resize := Button.new()
       btn_resize.text = "Ridimensiona"
       btn_resize.pressed.connect(_on_resize.bind(decoration))

       vbox.add_child(btn_delete)
       vbox.add_child(btn_rotate)
       vbox.add_child(btn_resize)
       _popup.add_child(vbox)
       _popup.global_position = get_global_mouse_position()
       get_tree().current_scene.add_child(_popup)

   func _on_delete(decoration: Sprite2D) -> void:
       decoration.queue_free()
       _popup.queue_free()
       _popup = null
       SignalBus.save_requested.emit()

   func _on_rotate(decoration: Sprite2D) -> void:
       decoration.rotation_degrees += 90.0
       SignalBus.save_requested.emit()

   func _on_resize(decoration: Sprite2D) -> void:
       # Esempio: cicla tra 3 scale
       var current_scale := decoration.scale.x
       if current_scale < 1.5:
           decoration.scale = Vector2(2.0, 2.0)
       elif current_scale < 2.5:
           decoration.scale = Vector2(3.0, 3.0)
       else:
           decoration.scale = Vector2(1.0, 1.0)
       SignalBus.save_requested.emit()
   ```

2. **Modificare `_input_event`** per chiamare `_show_popup()` al click sinistro (se non si sta trascinando)

3. **Chiudere il popup** quando si clicca altrove (connettere un segnale o gestire in `_input`)

---

## TASK 3: Rotazione e Ridimensionamento Decorazioni (PRIORITA MEDIA)

### Problema
Le decorazioni piazzate non possono essere ruotate o ridimensionate dopo il posizionamento.

### File da Modificare
- `res://scripts/rooms/decoration_system.gd` — aggiungere logica rotazione/scala
- `res://scripts/rooms/room_base.gd` — aggiornare `_spawn_decoration()` e `_save_decorations()`
- `res://scripts/autoload/save_manager.gd` — aggiungere campo `rotation` ai dati decorazione

### Cosa Fare
1. Quando si piazza una decorazione, salvare anche `rotation` e `scale` nei dati di salvataggio
2. Quando si carica una partita, applicare `rotation` e `scale` salvati
3. Il popup (Task 2) permette di modificare rotazione e scala

### Formato Dati Salvataggio Attuale (in SaveManager)
```json
{
    "decorations": [
        {"item_id": "plant_01", "position": [400, 500], "item_scale": 6.0}
    ]
}
```

### Formato Aggiornato
```json
{
    "decorations": [
        {"item_id": "plant_01", "position": [400, 500], "item_scale": 6.0, "rotation": 0.0}
    ]
}
```

---

## TASK 4: Semplificazione Codice Over-Engineered (PRIORITA BASSA)

### Analisi
Il codebase contiene sistemi troppo complessi per un gioco cozy room:

| Sistema | File | Righe | Problema |
|---------|------|-------|----------|
| SupabaseClient | `scripts/autoload/supabase_client.gd` | 515 | Client REST completo con pool HTTP, token refresh, autenticazione. Il gioco e offline. |
| LocalDatabase | `scripts/autoload/local_database.gd` | 298 | 7 tabelle SQLite che replicano Supabase. JSON via SaveManager e sufficiente. |
| SaveManager | `scripts/autoload/save_manager.gd` | 327 | Sistema di migrazione v1->v2->v3->v4, backup, auto-save timer. Eccessivo. |
| Logger | `scripts/autoload/logger.gd` | 220 | Log strutturati JSON Lines con rotazione file. Enterprise-grade. |

### Azioni Suggerite
1. **SupabaseClient**: Sostituire con uno stub vuoto che logga "online features disabled".
   Il gioco funziona gia completamente offline.
2. **LocalDatabase**: Rimuovere se tutti i dati necessari sono gia salvati in JSON.
   Oppure semplificare a 2-3 tabelle essenziali.
3. **SaveManager**: Rimuovere la catena di migrazione versioni. Usare un singolo
   formato senza backward compatibility.
4. **Logger**: Opzionale — funziona, ma e molto piu di quanto serve.

---

## TASK 5: Verifiche e Test

### Checklist Finale
- [ ] Il personaggio resta all'interno del pavimento isometrico in tutte le direzioni
- [ ] Click su decorazione piazzata mostra popup con Elimina/Ruota/Ridimensiona
- [ ] Ruotare una decorazione funziona (90 gradi)
- [ ] Ridimensionare una decorazione funziona
- [ ] Il salvataggio/caricamento preserva posizione, rotazione e scala delle decorazioni
- [ ] Il drag-and-drop decorazioni funziona ancora dopo le modifiche
- [ ] Il personaggio collide con le decorazioni piazzate (non ci cammina attraverso)
- [ ] La musica parte automaticamente (nessun pulsante Music nel HUD)
- [ ] Il menu mostra il personaggio Ragazzo Classico nel walk-in

---

## Risorse Utili

- **Documentazione Godot 4**: https://docs.godotengine.org/en/stable/
- **CollisionPolygon2D**: https://docs.godotengine.org/en/stable/classes/class_collisionpolygon2d.html
- **CharacterBody2D**: https://docs.godotengine.org/en/stable/classes/class_characterbody2d.html
- **Studio materiale progetto**: `v1/study/GODOT_ENGINE_STUDY_IT.md`
- **Deep dive progetto**: `v1/study/PROJECT_DEEP_DIVE_IT.md`
