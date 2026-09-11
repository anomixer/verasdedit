# AGENTS.md

This file is a working guide for coding agents and contributors working on
**verasdedit** — a PC-Tools-style 6502 hex sector editor for the Commander X16
**VERA expansion card**'s SD/MMC SPI. It captures the architecture and the
hard-won debugging lessons so future work doesn't re-trace the same mistakes.

> verasdedit was split out of the **AppleWin** repo (Apple II emulator for
> Windows) into its own repository. It is a *guest* 6502 program that is run by
> AppleWin; it is not part of AppleWin's C++ codebase and has no build
> dependency on it. The VERA SD SPI *emulation* it exercises lives in AppleWin's
> `source\VERACard\` — see that repo for emulator-side details.

## What this is

- A 6502 hex sector editor that reads **any LBA** of an SD card image directly
  over the **VERA SD/MMC SPI** (slot 2, `$C21E`/`$C21F`).
- Displays offset 0–511 as **hex + ASCII** in two pages (256 bytes / 16 rows).
- Runs on the Apple II (AppleWin) with the VERA card in slot 2, plus a mounted
  SD card image.
- Also has an **editor mode** (`E`) that writes a sector back via CMD24.
- Ships as a ready-to-boot **ProDOS disk image** (`verasdedit.po`, 143360 bytes).

## Repository layout

| File | Description |
|------|-------------|
| `verasdedit.asm` | 6502 assembly source (loads at `$2000`, ~3.1 KB) |
| `verasdedit.mjs` | Build script (Node.js ESM): assembles `.asm` → packs a ProDOS disk |
| `startup.bas` | Applesoft BASIC boot program (`BRUN VERASDEDIT.BIN`) |
| `asm6502.mjs` | **Dependency**: 6502 assembler (`assemble6502`), vendored |
| `applebasic.mjs` | **Dependency**: Applesoft BASIC compiler, vendored |
| `build.bat` | One-click build script (Windows): `node verasdedit.mjs` |
| `base/ProDOS_2_4_3.po` | **Dependency**: ProDOS 2.4.3 base disk image (build base) |
| `verasdedit.po` | **Build output** (git-ignored; regenerated) |

## Build

Self-contained — only **Node.js** (ESM) is required externally; all deps are
vendored in the repo.

```powershell
build.bat              # Windows one-click
node verasdedit.mjs    # any platform
```

The script:
1. Assembles `verasdedit.asm` (load `$2000`) → `VERASDEDIT.BIN`.
2. Compiles `startup.bas` → `STARTUP`.
3. Packs both onto a ProDOS 2.4.3 image (from `base/ProDOS_2_4_3.po`), freeing
   existing user files and keeping only PRODOS + BASIC.SYSTEM.

Successful output (current sizes):

```
Created ...\verasdedit.po (143360 bytes)
  VERASDEDIT.BIN: 3588 bytes (load $2000)
  STARTUP: 174 bytes
```

Copy `verasdedit.po` to `Release\` and boot it in AppleWin.

## Running it (AppleWin)

1. Install the **VERA card in Slot 2**, mount an SD card image via the VERA
   card's "Configure..." dialog.
2. **Boot order gotcha**: if a hard disk is configured in Slot 7 (registry
   `Slot 7\Last Harddisk Image 1`, commonly `x16-hero-vera.hdv`), it boots first
   and the editor never appears. Clear that registry value before launching:
   ```powershell
   reg delete "HKCU\Software\AppleWin\Configuration\Slot 7" /v "Last Harddisk Image 1" /f
   ```
   then boot with `-d1 verasdedit.po -power-on -m`.
3. It auto-runs `BRUN VERASDEDIT.BIN` and reads LBA `800` (FAT32 boot sector).

## Keys

| Key | Action |
|-----|--------|
| `SPACE` | Toggle page (PAGE 1 ↔ PAGE 2) |
| `N` / `P` | Next / previous LBA |
| `R` | Reload current LBA |
| `L` | Select LBA — type 1–8 hex digits + `RETURN` to load, `DEL` backspace, `ESC` cancel |
| `E` | Enter editor mode |
| `Q` | Return to ProDOS (BYE/RTS, restores IRQ vector) |

> Command keys accept **both cases** (`N`/`n`, `P`/`p`, `R`/`r`, `L`/`l`,
> `E`/`e`, `Q`/`q`, and in the editor `I`/`i`, `J`/`j`, `K`/`k`, `M`/`m`) — the
> key is case-normalised by `NORMKEY` before command comparisons. Only editor
> *data* input (hex nibbles / printable ASCII) stays case-sensitive, so
> lowercase ASCII can still be typed as data.
>
> In the *editor*, hex digits do nothing — LBA entry only happens inside the
> `[L]` select submode. Nibble edits only happen in the editor.

### Editor mode

The editor has two states: **navigate** (default, on entry) and **edit**
(press `E`). In navigate, `IJKM` move the cursor and `TAB` toggles field; in
edit, `0-F`/printable chars modify the byte under the cursor (so `IJKL` and
`E` are typed as data, not cursor movement / a toggle). `W` writes **only** in
navigate state — in edit state it's a printable char typed as data (the
`W`-write check sits after the EDITING check, so it never fires while editing).
`CR` (Enter) exits edit back to navigate.

| Key | Action |
|-----|--------|
| `I` / `M` | Cursor up / down one row (byte ±16) — navigate state only |
| `J` / `K` | Cursor left / right (hex moves per nibble) — navigate state only |
| `TAB` | Toggle hex field ↔ ASCII field |
| `E` | Navigate state: enter edit state |
| `CR` | Edit state: stop editing, **accept** the edit, return to navigate |
| `ESC` | Edit state: **discard** the edit (re-read sector from SD), return to navigate; navigate state: leave editor to editor |
| `0–9 A–F` | Edit state, hex field: set nibble under cursor, advance (incl. `E`) |
| (printable) | Edit state, ASCII field: set byte under cursor, advance (incl. `IJKL`) |
| `W` | Write whole 512-byte sector back via CMD24 (both `W`/`w`; shown in the navigate banner) |

The navigate banner shows `[W]=write`; the edit banner shows no `W` hint. `Q`
returns to ProDOS via the `BYE`/RTS convention (the BRUN return address), not
the Applesoft warm-start `$3D2`; the saved IRQ vector is restored first.

Edited bytes show **inverse**, the cursor cell **flashes** — `PUTCH` supports
three display modes (`ZP_DISPMODE`: 0=normal `|0x80`, 1=inverse `&0x3F`,
2=flash `&0x3F|0x40`; the 80-col flash bit is bit6 with bit7 clear). A 32-byte
dirty bitmap (`$2F00`, 1 bit per byte) tracks edits; `W` clears it.

A **changed byte shows inverse** (both nibbles) until written — and a byte only
counts as changed if its value actually differs from the **original** (the
last-loaded sector, kept in `ORIGBUF` at `$3400`). Editing a byte back to its
original value (e.g. `00` → `00`, or reverting `05` → `00`) clears its dirty bit
and it renders normal again, so typing through untouched bytes never shows
inverse. The **cursor cell always flashes** — in the hex field the nibble under
the cursor (`ZP_NIBPOS`) flashes, and in the ASCII field the cursor char flashes,
**even on a changed (inverse) byte**, so you can always tell where the cursor is
(`ASCII_DISPMODE` sets flash for the cursor byte + ASCII field without an
`IS_DIRTY` branch). The *other* nibble of a changed cursor byte stays inverse,
and changed non-cursor bytes render fully inverse. After `W` clears the dirty
bitmap and refreshes `ORIGBUF` (the written bytes become the new original).

In the hex field the cursor flashes **only the nibble under it** (`ZP_NIB`:
0=high/left, 1=low/right; `ZP_NIBPOS` selects which nibble is being drawn).
Typing a hex digit edits that nibble and advances high→low→next byte, so both
nibbles of a byte are editable; `ZP_NIB` is reset to 0 (high) on entering edit
mode.

## Debugging lessons (ordered by importance)

1. **Assembler `CPX`/`CPY` addressing-mode bug — root cause of LBA input
   failures.** The vendored `asm6502.mjs` used to emit **immediate** (`E0`/`C0`)
   for *every* `CPX`/`CPY`, never zero-page (`E4`/`C4`). So `CPX ZP_IBUFIDX`
   compared X to the *address value* (114) instead of the memory contents,
   making the LBA-input parse loop run the wrong number of times: typing `800`
   sent LBA `FF00FF00` (out of range) → "SD Read failed!", and `LBA>` drew
   garbage. **Fixed**: `CPX`/`CPY` now pick immediate for `#imm`, zero-page for
   a ZP label/`$XX`, absolute otherwise. **If you re-vendor `asm6502.mjs`, keep
   this fix.** Verified: `CPY ZP_IBUFIDX` → `C4 72`, `CPX ZP_IBUFIDX` → `E4 72`.
2. **Display init gotcha (garbled/inverse screen).** After switching to
   80-column text (`$C00D`), the guest must also set **80STORE OFF (`$C000`)**
   and **PAGE2 OFF (`$C054`)** so the display reads PAGE1 (`$0400`, where the
   guest writes). Forgetting these shows a garbled/inverse screen even though
   memory is correct — because the 80-col display reads PAGE1 vs PAGE2 per the
   PAGE2 soft-switch (`$C054`/`$C055`), which is independent of the write-routing
   RAMWRT soft-switch.
3. **SCRATCH / sector-buffer banking — and keep SCRATCH above the code.** `$0200–$BFFF`
   is subject to RAMWRT(write)/RAMRD(read) soft-switches. `PUTCH` toggles the bank
   per char, which leaks into other memory writes. The guest must explicitly
   `STA RAMWRTOFF` before writing SCRATCH or the sector buffer (`$3000`/`$3100`),
   and `RAMRDOFF` before reading them, or data silently lands in the wrong bank
   (e.g. ASCII column garbled, or a reloaded sector not updating the display).
   **SCRATCH must also sit strictly above the code** — it's a 16-byte work area
   for the ASCII column, and the code grows up through `$2E00` as features are
   added. When SCRATCH was `$2E00` and the program grew to 3587 bytes
   (`$2000`–`$2E02`), `DRAW_DATA`'s `STA SCRATCH,Y` overwrote the trailing
   `JMP EDIT_LOOP` with sector data → the guest executed garbage and hit a `BRK`
   at `$2E02` after any byte edit. SCRATCH is now `$2E20`. **If you add code,
   re-check that the code end (`load + length`) stays below `SCRATCH`.**
4. **Subroutine A-clobber pitfall.** `HEX_DISPMODE`/`ASCII_DISPMODE` use A as a
   temp and clobber the byte being printed; reload the buffer byte after calling
   them, or the hex column shows garbage.
5. **SD write persistence.** When writing a sector back, the emulator's
   `VERASD::WriteBlock` must `fflush` after `fwrite`, or a hard kill loses the
   write (stdio buffer never flushed). (Emulator-side, but the guest depends on
   it.)
6. **Assembler silently drops `label,Y` on `AND`/`ORA` — root cause of the
   "8-byte inverse" bug.** The vendored `asm6502.mjs` `AND`/`ORA` handlers only
   support `#imm`, `$zp`, and absolute — they have **no indexed-`Y` mode**, but
   6502 `AND`/`ORA` have *no* indexed-`Y` mode anyway (only indexed-`X`).
   Writing `AND BIT_TABLE,Y` was silently assembled as **`AND $0000`** (the
   label *and* the `,Y` were both dropped, `resolveVal` returned `NaN` →
   address 0). The zero page at `$0000` held `$FF`, so `SET_DIRTY_BIT`'s
   `ORA $0000` ORed `$FF` into the dirty-map byte (all 8 bits set → 8
   neighbouring bytes all rendered inverse), and `IS_DIRTY`'s `AND $0000`
   (identity on `$FF`) read them all as dirty — hence editing ONE byte made
   the whole `00-07`/`08-0F` group inverse. **Fixed**: compute the bit mask by
   shifting in a `BITMASK` routine (`LDA #1; CPY #0; BEQ done; ASL A; DEY;
   JMP`) instead of a table lookup, so `AND`/`ORA` never take an indexed-Y
   operand. **If you re-vendor `asm6502.mjs`, keep this in mind** — and never
   write `AND/ORA/EOR label,Y` (invalid 6502); use indexed-`X` or compute the
   mask by shifting. Verified by disassembling the binary: `AND BIT_TABLE,Y`
   had become `2D 00 00` (`AND $0000`), now `AND $5A`.

## 80-column display model (Apple IIe)

- 80-column text **interleaves AUX/MAIN per column** — each 40-address
  text-page cell renders AUX(left)+MAIN(right) (`NTSC.cpp updateScreenText80`:
  `bits=(main<<7)|aux`). So even columns→AUX, odd columns→MAIN, cell offset =
  column>>1. `PUTCH` must swap banks per char.
- Display row R's cell base = `$0400 + (R&7)*$80 + (R/8)*$28`.

## Testing

- **Offline assembler check**: `node -e "..."` to confirm `CPX`/`CPY` emit
  `E4`/`C4` (zero-page) for ZP labels, not `E0`/`C0`.
- **Interactive (headless)**: launch AppleWin with the editor disk, confirm the
  process stays alive and the 80-col text page can be reconstructed from
  `MemGetMainPtr`/`MemGetAuxPtr`. In a headless environment `FindWindow`/
  `PrintWindow` return handle 0, so screenshots don't work — use a text-page
  dump diagnostic instead. `MemGetAuxPtr` has a cache artifact; some chars are
  garbled when rebuilding the frame.
