# Elev-guide: Byg din Marble-bane

## Hvad er dette projekt?

**Marble Starter** er et undervisningskit:

- ✅ Bolden (marble) virker allerede
- ✅ Kamera, hop, respawn virker allerede
- 🧱 **I skal bygge banen** fra START-platformen og frem

Tænk på det som et racing-spil, hvor bilen er færdig — I designer racerbanen.

---

## Trin 1 — Åbn og test

1. Åbn `MarbleStarter.rbxlx` i Roblox Studio
2. Tryk den grønne **Play**
3. Vælg fanen **Client** (øverst i viewport)
4. Klik én gang i spilvinduet (så tastaturet virker)
5. Brug **WASD** — bolden skal rulle på den grønne START-plade

Virker det? Godt. Stop Play (rød knap) før I bygger.

---

## Trin 2 — Find “bygge-mappen”

Allerede i **Explorer** (uden Play):

```
Workspace
 └── StudentCourse
      ├── StartPad                 ← grøn start-platform
      ├── Wall...                  ← kanter (åbning mod +Z)
      └── BuildYourCourseHere      ← LÆG JERES PLATFORME HER
```

### Byg i Edit-mode (anbefalet)

1. Markér `BuildYourCourseHere`
2. Indsæt en **Part** (`Home` → Part)
3. Sæt **Anchored = true**
4. Placer den foran START (positiv **Z** — der er åbningen)
5. Skaler til platform (fx Size `20, 2, 40`)
6. Play og test
7. **Gem place-filen** når I er færdige (`Ctrl+S`)
---

## Trin 3 — Design jeres bane hen til MÅL

I kan se et **gult mål** langt ude (med en høj lysende pæl).
Afstand: ca. **600 studs** langs +Z fra START.

Lav mindst:

1. **Platforme** der forbinder START → MÅL
2. **Et sving** eller højdeforskel
3. **En rampe** (roteret Part)
4. **En udfordring** (smal bro, gap, vægge)

Tryk **Enter** i spillet for at pege kameraet mod målet.
### Rampe (simpel metode)

1. Lav en Part
2. Brug **Rotate** (Ctrl+R eller Rotate-værktøj)
3. Kip den blødt (10–20°)
4. Sørg for at toppen møder næste platform uden hul

### Undgå typiske fejl

| Problem | Løsning |
|---------|---------|
| Falder igennem | Anchored + CanCollide |
| Hul mellem platforme | Overlap 1–2 studs |
| For stejlt | Mindre vinkel / længere rampe |
| Spawner midt i Part | Flyt Parts væk fra (0, ~8, 0) |

---

## Trin 4 — Test målet

Målet (`GoalPad`) er allerede sat op med `IsGoal = true`.
Når I rører den gule platform: **MÅL NÅET!**

(I må gerne flytte/omdesigne målet — husk bare at Attribute `IsGoal` skal være true.)

---

## Trin 5 — Playtest checklist

- [ ] Kan man køre fra start til mål uden at sidde fast?
- [ ] Er der mindst én “aha”-udfordring?
- [ ] Er det fair (ikke umulige gaps)?
- [ ] Virker respawn (R / fald)?
- [ ] Virker målet?

---

## Bonus-idéer

- Checkpoint-platform (kun visuelt først — logik kan tilføjes senere)
- Is-agtig Part (lav Friction i CustomPhysicalProperties)
- Dekoration (neon, lys, skilte med SurfaceGui)
- Flere veje (nem / svær)

---

## Struktur (til nysgerrige)

```
Games/Marble Starter/
  src/
    ServerScriptService/
      StartPad.luau      ← laver START
      Game.server.luau   ← spawner marble + mål-logik
    StarterPlayer/.../
      MarbleControl...   ← styring (færdig)
      Hud...             ← tekst på skærmen
    ReplicatedStorage/Shared/
      Config.luau        ← fart/hop-tal
```

**I må gerne læse koden** — men opgaven er at bygge banen, ikke omskrive motoren.
