# Mini Micro BMF Font Library - AI Coding Guide

## Project Overview
This is a MiniScript library for Mini Micro that reads and renders bitmap fonts in ByteMap Font (BMF) format. It supports both BMF v1.1 and v1.2, including Unicode characters, kerning, anti-aliasing, and alpha channels.

## Language & Runtime
- **Language**: MiniScript (https://miniscript.org)
- **Runtime**: Mini Micro virtual computer (https://miniscript.org/MiniMicro)
- **Testing**: Run code directly in Mini Micro, not via terminal commands

## Core Architecture

### Main Components
1. **bmfFonts.ms** - Primary module with `Font` and `CharData` classes
2. **grfon.ms** - GRFON parser (General Recursive Format Object Notation)
3. **util/** - Font conversion/editing tools (pack, unpack, fontEdit)
4. **fonts/** - Collection of .bmf font files
5. **YAFF support** - Text-based YAFF format loader (converts to BMF at load time)

### Key Classes
- `Font`: Main font container with loading, rendering, and sav (auto-detects format)
  - `Font.loadBMF(path)` - Load binary BMF format
  - `Font.loadYAFF(path)` - Load text-based YAFF format (converts to BMF v1.1)ing capabilities
  - `Font.load(path)` - Entry point for loading BMF/YAFF fonts
  - `Font.print(string, x, y, scale, tint)` - Render text to gfx display
  - `Font.save(path)` - Write font as BMF v1.1 or v1.2
- `CFont Format Support
**BMF (Binary)**: 
- Supports v1.1 (basic ASCII) and v1.2 (Unicode, kerning, alpha)
- Binary format: header → palette → ASCII chars → Unicode chars → kerning pairs
- Font metrics: `lineHeight`, `sizeOver`, `sizeUnder`, `addSpace`, `sizeInner`
- Character metrics: `width`, `height`, `relX`, `relY`, `shift`

**YAFF (Text-based)**:
- Human-readable ASCII art bitmaps (`.` = transparent, `@` = inked)
- Supports Unicode labels (`u+XXXX`), decimal/hex (`65`, `0x41`), literals (`'A'`), tags (`"name"`)
- Per-glyph metrics: `left-bearing`, `right-bearing`, `shift-up`
- Global metrics: `line-height`, `ascent`, `descent`, `spacing`, `cell-size`
- Kerning support via `right-kerning` property
- Converted to BMF v1.1 at load time (white palette for tinting) → kerning pairs
- Font metrics: `lineHeight`, `sizeOver`, `sizeUnder`, `addSpace`, `sizeInner`
- Character metrics: `width`, `height`, `relX`, `relY`, `shift`

## Critical Developer Workflows

### Loading and Using Fonts
// Load binary BMF format
f = bmfFonts.Font.load("fonts/ming.bmf")
f.print "Hello world!", 20, 500

// Load text-based YAFF format
yaff = bmfFonts.Font.load("fonts/test.yaff")
yaff.print "YAFF fonts!", 20, 450

f = bmfFonts.Font.load("fonts/ming.bmf")
f.print "Hello world!", 20, 500
w = f.width("some text")  // Calculate text width
```

### Font Conversion Workflow
**Unpack** (BMF → images + GRFON):
```miniscript
env.importPaths.insert 0, ".."
import "bmfFonts"
// Run util/unpack.ms in Mini Micro
// Creates: fontData.grfon + [codepoint].png files
```

**Pack** (images + GRFON → BMF):
```miniscript
// Run util/pack.ms in Mini Micro
// Reads: fontData.grfon + [codepoint].png files
// Creates: output.bmf
```

### Custom Font Modifications
1. Unpack font to edit individual glyphs as PNG images
2. Modify `fontData.grfon` for metrics (lineHeight, shifts, kerning)
3. Pack back to BMF format
4. GRFON format: human-editable, whitespace-flexible, supports maps/lists

## Project-Specific Conventions

### MiniScript Patterns
- **Map inheritance**: Use `+` operator for prototypal inheritance
  ```miniscript
  myObj = new BaseClass   // equivalent to: myObj = BaseClass + {}
  ```
- **Self references**: Instance methods access `self`, not `this`
- **Function references**: Pass functions with `@` operator: `@functionName`
- **Default parameters**: Use simple literals only; for complex defaults use `null`
  ```miniscript
  Font.method = function(options=null)
    if options == null then options = {}
  ```
- **No ternary operator**: Use `if/else` or boolean multiplication for conditionals
- **Range is inclusive**: `range(0,5)` returns `[0,1,2,3,4,5]` (includes endpoint)
- **Import paths**: Modify `env.importPaths` to include parent directories (see util/ files)
- **Character codes**: Use `char(codePoint)` and `string.code` for Unicode

### Display System (Mini Micro specific)
- Multiple display layers: `display(0)` (front) to `display(7)` (back)
- `gfx` points to `display(5)` by default - primary drawing surface for font rendering
- **Warning**: `display(3)` is the text layer for interpreter output/errors - avoid replacing
- Coordinates: Bottom-left origin (0,0), typical screen is 960×640
- Colors: Hex strings like `"#RRGGBBAA"` or `color.rgb(r, g, b)`

### Binary Data Handling
- Use `RawData` class for binary I/O
- Set `littleEndian` property before reading multi-byte values
- Methods: `byte()`, `sbyte()`, `short()`, `ushort()`, `uint()`, `utf8()`
- `BinaryStream` pattern in `Font.save()` for write operations with dynamic buffer growth

## Key Integration Points

### GRFON Parser (`grfon.ms`)
- Used by pack/unpack utilities for human-editable font metadata
- `grfon.parse(string)` → MiniScript value (map/list)
- `grfon.toGRFON(value)` → GRFON string
- Supports escape sequences, Unicode code points (`\uXXXX`)

### File System API
- `file.loadRaw(path)` / `file.saveRaw(path, data)` for binary files
- `file.loadImage(path)` / `file.saveImage(path, img)` for PNGs
- `file.children(path)` to list directory contents
- `file.child(dir, filename)` to construct paths

### Rendering Pipeline
1. `Font.charData(char)` retrieves `CharData` (with fallback to uppercase)
2. `Font.getCharImage(char)` creates/caches `Image` objects
3. `Font.printChar()` draws using `gfx.drawImage()` with positioning
4. Apply kerning via `Font.kern(c1, c2)` between characters

## Special Considerations

### Font Editing (`util/fontEdit.ms`)
- Work in progress - check GitHub issues for development status
- Complex multi-display UI with pixel editor
- Uses "fat pixels" (scaled up display) for editing

### Color Handling
- Palette-based (BMF v1.1) or alpha-channel (BMF v1.2)
- Recolor fonts via `font.palette` modification (must do before printing)
- Tinting via optional `color` parameter to `Font.print()`

### Version Differences
- v1.1: ASCII only, no alpha, basic palette
- v1.2: Unicode, kerning pairs, 8-bit alpha channel support
- Check `font.version`, `font.alphaBits` for capabilities

## Common Pitfalls
- **Import paths**: Utilities modify `env.importPaths` - necessary for cross-directory imports
- **Character caching**: Images cached after first render - palette changes ineffective after caching
- **Coordinate system**: Y-axis is bottom-to-top, not top-to-bottom
- **Reserved keywords**: Cannot use MiniScript keywords as method names (e.g., `new`, `function`, `if`)
- **String immutability**: Strings are immutable; create new strings rather than modifying indices
- **Map/list defaults**: Never use list/map literals as default parameters - use `null` and initialize inside function
- **Binary endianness**: Always set `littleEndian = true` for BMF format
