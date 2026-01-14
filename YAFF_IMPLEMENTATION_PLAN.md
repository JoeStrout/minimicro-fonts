# YAFF Font Format Support - Implementation Plan

## Overview

Add support for loading YAFF (Yet Another Font Format) text-based bitmap fonts to the existing BMF binary font loader. The YAFF loader will parse text files and convert them to the internal `Font` and `CharData` structures used by existing rendering functions (`Font.print()`, `Font.width()`, etc.). No changes to rendering code are required.

**Key constraint**: YAFF is converted to BMF v1.1 at load time. All existing print functions work without modification.

**Location**: Implement in [bmfFonts.ms](bmfFonts.ms#L121-L123) `Font.loadYAFF(path)` function (currently a stub).

---

## High-Level Architecture

### Current Flow
```
Font.load(path)
  ├─ .bmf extension → Font.loadBMF(path) [EXISTING]
  ├─ .yaff extension → Font.loadYAFF(path) [NEW]
  └─ unsupported → return null + error message
```

### New Implementation: Two-Pass Parser
```
Font.loadYAFF(path)
  ├─ Pass 1: Parse global properties (key-value) until first glyph label
  │   ├─ Handle multi-line property values (indented continuation)
  │   ├─ Extract: name, direction, spacing, line-height, ascent, descent
  │   └─ Store in temporary properties map
  │
  ├─ Pass 2: Parse all glyph definitions (file order, first label wins)
  │   ├─ For each glyph: label(s) → bitmap lines → per-glyph properties
  │   ├─ Validate bitmap: consistent widths, only `.`/`@` characters
  │   ├─ Convert ASCII art to pixel arrays (reverse row order)
  │   ├─ Create CharData objects → store in Font.chars
  │   └─ Parse kerning (right-kerning single-line format)
  │
  ├─ Calculate font metrics from glyphs + YAFF properties
  │   ├─ lineHeight, sizeOver, sizeUnder
  │   └─ Infer monospace cellWidth if needed
  │
  └─ Return initialized Font object (or null on error)
```

---

## Detailed Steps

### Step 1: Two-Pass YAFF Text Parser

#### Implementation Location
File: [bmfFonts.ms](bmfFonts.ms#L121-L123)  
Function: `Font.loadYAFF = function(path)`

#### Pass 1: Global Properties Parsing

**Input**: `file.readLines(path)` returns array of strings

**Algorithm**:
1. Initialize global properties map: `globalProps = {}`
2. Initialize line counter: `lineNum = 0` (for error reporting, 1-based)
3. Iterate through lines until first glyph label or EOF:
   - Skip comment lines (start with `#`)
   - Skip blank lines (empty or whitespace-only)
   - If line matches property key pattern (start of line with `key:`):
     - Extract key and value (same line)
     - If no value on same line, check next indented lines (multi-line continuation)
     - Strip quotes from multi-line values if surrounded by `"..."`
     - Store in `globalProps[key_lowercase] = value`
   - If line starts with label pattern (u+, 0x, ', "), stop (first glyph found)
4. Return `globalProps` map and `firstGlyphLineNum` for Pass 2

**Property Key Format**: Must match regex `^[a-zA-Z0-9_.-]+:` (letters, digits, underscore, dash, dot)

**Multi-line Value Handling**:
```
name: Short Name
author:
    John Doe
    Copyright 2024

# Parsed as:
# name = "Short Name"
# author = "John Doe\nCopyright 2024"
```

**Error Handling**:
- Invalid UTF-8 in file: return null, print "YAFF file is not valid UTF-8"
- Cannot read file: return null, print "Unable to read YAFF file at [path]"

#### Pass 2: Glyph Definition Parsing

**Input**: Remaining lines after first glyph label

**Algorithm**:
1. Initialize `Font.chars = {}` (empty, will be populated)
2. Initialize `cellWidth = null` (for monospace inference)
3. For each remaining line group (glyph definition):
   - Parse label line(s) until `:` separator found
     - Extract label type: `u+XXXX`, `0xNN`, `NN`, `'char'`, `"tag"`
     - For first label: convert to character string (store as Font.chars key)
     - For additional labels: silently skip with TODO comment (multi-label aliasing)
   - Parse bitmap (indented lines with consistent indent):
     - Collect all consecutive indented lines with `.` and `@` only
     - Validate each line width consistency → error if inconsistent
     - Validate each line has only `.` and `@` → error if invalid character found
     - Store bitmap lines temporarily
   - Parse per-glyph properties (after blank line, same indent as bitmap):
     - Extract: `left-bearing`, `right-bearing`, `shift-up`, `right-kerning`
     - Default all metrics to 0 if not specified
   - Create CharData object:
     - Convert bitmap to `colors[]` array (reverse row order)
     - Set `width`, `height` from bitmap dimensions
     - Set `charCode` from Unicode codepoint (0 for tags)
     - Set `relX`, `relY`, `shift` using per-glyph metrics (see Step 6)
     - Store in `Font.chars[character]` (if first label was valid)
   - Track first non-empty glyph width for monospace cell inference

**Label Parsing**:
```
u+0041:      → char(0x41) = "A"
u+0061:      → char(0x61) = "a"
0x41:        → char(0x41) = "A"
65:          → char(65) = "A"
'A':         → "A"
"latin_a":   → "latin_a" (tag key)
'é':         → char(0xE9) = "é"
```

**Error Messages** (return null, print message):
- "Malformed glyph label at line N: expected ':' separator"
- "Invalid hex codepoint u+XXXX at line N"
- "Inconsistent glyph width at line N (expected W, got W)"
- "Invalid bitmap character at line N: only '.' and '@' allowed"
- "No bitmap data found for glyph at line N"

### Step 2: Initialize Font Properties from YAFF Globals

#### Properties to Initialize

```miniscript
f = new Font
f.version = 1.1                    // Always v1.1 (YAFF has no version)
f.title = globalProps["name"] or "YAFF Font"
f.palette = ["#FFFFFF"]            // White for monochrome tinting support
f.alphaBits = 0                    // No alpha channel
f.chars = {}                       // Populated in Pass 2
f.kernMap = null                   // Populated from right-kerning if present
f.addSpace = 0                     // Not in YAFF spec
f.sizeInner = 0                    // Not in YAFF spec
f.usedColors = 1
f.highestUsedColor = 1
f.numPalettes = 1
f.data = null                      // No binary data for text-loaded fonts
f.direction = globalProps["direction"] or null    // Store for future use
f.spacing = globalProps["spacing"] or null       // Used for metric calculation
f.lineHeight = null                // Calculated in Step 4
f.sizeOver = null                  // Calculated in Step 4
f.sizeUnder = null                 // Calculated in Step 4
```

#### Global Property Value Processing

- `name`: String (can be multi-line)
- `spacing`: One of: `monospace`, `proportional`, `character-cell`, `multi-cell`
- `direction`: One of: `left-to-right`, `right-to-left`, `top-to-bottom`
- `cell-size`: Integer (width in pixels for monospace)
- `line-height`: Integer (pixels, overrides calculated value)
- `ascent`: Integer (pixels, overrides calculated sizeOver)
- `descent`: Integer (pixels, overrides calculated sizeUnder)

### Step 3: Parse Global Multi-Line Properties

#### Algorithm

When property value is not on same line as key:
1. Collect all following lines that start with whitespace (spaces or tabs)
2. For each continuation line: remove leading/trailing whitespace
3. If line is surrounded by `"..."`, remove outer quotes
4. Join lines with `char(10)` (newline)
5. Store result in properties map

#### Example

```
notice:
    "Copyright 2024 Test Inc."
    "All rights reserved."

# Parsed as: notice = "Copyright 2024 Test Inc.\nAll rights reserved."
```

### Step 4: Calculate Font-Level Metrics

#### After Pass 2 (all glyphs loaded)

**Input**: 
- Populated `Font.chars` map (CharData objects with width, height, shift_up)
- Global properties map (may contain line-height, ascent, descent)

**Algorithm**:

1. Collect glyph metrics from all non-empty glyphs:
   ```
   heights = []
   shiftUps = []
   for each CharData in Font.chars:
       if width > 0:
           heights.push height
           shiftUps.push shift_up (default 0 if not specified)
   ```

2. Calculate `sizeOver`:
   ```
   if globalProps.hasIndex("ascent"):
       Font.sizeOver = globalProps["ascent"]
   else if heights.len > 0:
       Font.sizeOver = max(shiftUp + height for each glyph)
   else:
       Font.sizeOver = 10  // default for empty font
   ```

3. Calculate `sizeUnder`:
   ```
   if globalProps.hasIndex("descent"):
       Font.sizeUnder = globalProps["descent"]
   else if shiftUps.len > 0:
       Font.sizeUnder = max(0 - min(shiftUps), 1)  // minimum 1
   else:
       Font.sizeUnder = 2  // default for empty font
   ```

4. Calculate `lineHeight`:
   ```
   if globalProps.hasIndex("line-height"):
       Font.lineHeight = globalProps["line-height"]
   else if heights.len > 0:
       maxHeight = max(height for each glyph)
       minShiftUp = min(shiftUp for each glyph, default 0)
       Font.lineHeight = maxHeight + (0 - minShiftUp) + 1  // +1 pixel leading
   else:
       Font.lineHeight = 12  // default for empty font
   ```

**Coordinate System**:
- `shift-up` in YAFF: distance from baseline *upward* to raster bottom
- Negative `shift-up`: raster extends below baseline
- Example: if glyph height=10, shift-up=8, raster bottom is 8 pixels above baseline

### Step 5: Convert ASCII Art Bitmaps to CharData

#### Bitmap Format (YAFF)

```
u+0041:
    .@@.
    @..@
    @@@.
    @..@
```

Rows are top-to-bottom (visual representation).

#### Conversion Algorithm

1. Parse bitmap lines (indented, same indent level)
2. Extract width from first line length
3. Validate all lines have same width → error if inconsistent
4. Create pixel array:
   - Total pixels = width × height
   - Iterate bottom-to-top through bitmap rows (reverse order)
   - For each row, left-to-right: `.`→0, `@`→1, push to colors array
5. Store final `colors[]` array with length = width × height

#### Example

```
Input lines (top-to-bottom):
  ".@@."     ← line 0 (top)
  "@..@"     ← line 1
  "@@@."     ← line 2
  "@..@"     ← line 3 (bottom)

Processing (reverse order for BMF):
  Reverse to: [line3, line2, line1, line0]
  Convert each: "@..@" → [1,0,0,1], "@@@." → [1,1,1,0], "@..@" → [1,0,0,1], ".@@." → [0,1,1,0]
  Flatten: [1,0,0,1, 1,1,1,0, 1,0,0,1, 0,1,1,0]
  
Result: colors = [1,0,0,1, 1,1,1,0, 1,0,0,1, 0,1,1,0]
        width = 4, height = 4
```

#### Empty Glyph Handling

Single-line bitmap of just `-`:
```
"empty":
    -
```

Convert to: `width=0, height=0, colors=[]`

### Step 6: Calculate Per-Glyph Positioning Offsets

#### Mapping YAFF metrics to CharData

**YAFF metrics** (all default to 0 if not specified):
- `left-bearing`: pixels from glyph origin leftward before raster starts
- `right-bearing`: pixels from raster rightward to cursor advance
- `shift-up`: pixels from baseline upward to raster bottom

**CharData fields** (used by [Font.printChar()](bmfFonts.ms#L450-L480)):
- `relX`: horizontal offset from cursor to glyph origin
- `relY`: vertical offset from baseline to glyph origin
- `shift`: pixels to advance cursor after drawing

#### Calculation Logic

```miniscript
relX = left_bearing  // default 0

relY = -(shift_up + height)  // convert baseline offset to raster bottom
       // default: -(0 + height) = -height

// shift depends on spacing type:
if Font.spacing == "monospace" or Font.spacing == "character-cell" or Font.spacing == "multi-cell":
    // Monospace: uniform advance width
    if cellWidth == null:
        cellWidth = YAFF.cell-size property OR
                   first_non_empty_glyph.width OR
                   8  // default
    shift = cellWidth
else:
    // Proportional: individual advance widths
    shift = left_bearing + width + right_bearing
    if no left_bearing and no right_bearing:
        shift = width  // fallback

// Ensure shift is positive
if shift <= 0:
    shift = width  // minimum usable advance
```

#### Example

```
Glyph "A" (width=5, height=6):
  left-bearing: 0
  right-bearing: 1
  shift-up: 6
  
Calculations:
  relX = 0
  relY = -(6 + 6) = -12
  shift = 0 + 5 + 1 = 6  (proportional)
  
For monospace (cellWidth=8):
  shift = 8  (uniform)
```

### Step 7: Parse and Apply Kerning

#### Per-Glyph `right-kerning` Property

**Format**: Single-line, comma-separated label-value pairs

```
right-kerning: u+0042 -2, u+0043 -1
```

**Parsing Algorithm**:
1. Split by comma to get pairs
2. For each pair:
   - Split by whitespace to get label and value
   - Parse label using glyph label logic → get character
   - Parse value as signed integer
   - Call `Font.setKern(thisGlyph, targetChar, kernAmount)`
3. Skip invalid labels silently (TODO: add debug warning mode)

**Kerning Application** (in [Font.kern()](bmfFonts.ms#L101-L105)):
- Negative kerning brings glyphs closer
- Applied during `Font.print()` → `Font.printChar()` → kerning offset added to x

#### Example

```
u+0041:  // Glyph "A"
    .@@.
    @..@
    @@@@
    @..@
    
    right-kerning: u+0056 -2

# Result: Font.setKern("A", "V", -2)
# When printing "AV", tight kerning applied
```

---

## Data Structure Mappings

### YAFF Properties → Font Class

| YAFF Property | Font Field | Default | Notes |
|---|---|---|---|
| `name` | `title` | "YAFF Font" | Multi-line capable |
| `direction` | `direction` | null | Stored for future use |
| `spacing` | `spacing` | null | Used for metric calculation |
| `line-height` | `lineHeight` | Calculated | Computed from glyphs if absent |
| `ascent` | `sizeOver` | Calculated | Computed from glyphs if absent |
| `descent` | `sizeUnder` | Calculated | Computed from glyphs if absent |
| `cell-size` | — | Inferred | Used to determine monospace advance width |

### YAFF Glyph Metrics → CharData

| YAFF Property | CharData Field | Formula | Default |
|---|---|---|---|
| `left-bearing` | `relX` | `left_bearing` | 0 |
| — | `relY` | `-(shift_up + height)` | `-height` |
| Advance width | `shift` | See Step 6 | Monospace: cellWidth, Proportional: width |
| — | `width`, `height` | From bitmap dimensions | Extracted from bitmap |
| Label | `charCode` | From Unicode codepoint | 0 (for tags) |
| `.`/`@` bitmap | `colors[]` | Pixel array (reversed rows) | Required |

---

## Error Handling Strategy

### Return Value
- **Success**: Fully initialized `Font` object (ready for `Font.print()`)
- **Failure**: `null` (with error message printed)

### Error Messages
Print format: `print "Font.loadYAFF: [error message]"`

| Error | Message | Example |
|---|---|---|
| File read failure | "Unable to read YAFF file at [path]" | — |
| Invalid UTF-8 | "YAFF file is not valid UTF-8" | — |
| Malformed label | "Malformed glyph label at line N: expected ':' separator" | Line 42 |
| Invalid hex | "Invalid hex codepoint u+XXXX at line N" | Line 15, u+GGGG |
| Inconsistent bitmap width | "Inconsistent glyph width at line N (expected W, got W)" | Line 28, expected 5, got 4 |
| Invalid bitmap character | "Invalid bitmap character at line N: only '.' and '@' allowed" | Line 26, found 'X' |
| No bitmap | "No bitmap data found for glyph at line N" | Line 20 |

### Error Line Numbers
- **1-based** (match text editor convention)
- Report actual file line number from `file.readLines()` array index
- Include in all error messages for easy debugging

### Silent Skips (with TODO)
- Multi-label glyphs: skip additional labels after first (multi-label aliasing TODO)
- Unrecognized per-glyph properties: skip unknown keys (log for debugging TODO)
- Invalid kerning label references: skip non-existent target glyphs (debug warning TODO)

---

## Testing Strategy

### Test Phase 1: Basic Parser Validation (Minimal YAFF File)

**Test File**: `test_yaff_simple.yaff`

```
yaff: 1.0
name: Test Font 8px
line-height: 10

u+0041:
    .@@.
    @..@
    @@@.
    @..@

u+0042:
    @@@@
    @...
    @@@.
    @...

u+0043:
    .@@@
    @...
    @...
    .@@@
```

**Validation**:
- File loads without error
- `Font.title` = "Test Font 8px"
- `Font.lineHeight` = 10
- `Font.chars` contains 3 glyphs (A, B, C)
- Each glyph: width=4, height=4
- `Font.palette` = ["#FFFFFF"]
- Rendering works with `font.print("ABC", 10, 100)`

### Test Phase 2: Metrics and Positioning (With Properties)

**Test File**: `test_yaff_metrics.yaff`

```
yaff: 1.0
name: Metrics Test
spacing: proportional
ascent: 6
descent: 2

u+0041:
    .@@.
    @..@
    @@@.
    @..@
    @...
    @...
    
    left-bearing: 1
    right-bearing: 1
    shift-up: 4
```

**Validation**:
- `Font.sizeOver` = 6 (from ascent property)
- `Font.sizeUnder` = 2 (from descent property)
- CharData for A: `relX=1`, `relY=-10`, `shift=6`
- Rendering positions correctly with offset

### Test Phase 3: Monospace and Kerning (Advanced)

**Test File**: `test_yaff_monospace.yaff`

```
yaff: 1.0
name: Monospace Test
spacing: monospace
cell-size: 8

u+0041:
    .@@.
    @..@
    @@@.
    @..@

u+0056:
    @...@
    @...@
    .@.@.
    ..@..
    
    right-kerning: u+0041 -1
```

**Validation**:
- All glyphs use `shift=8` (cell width)
- `Font.kern("V", "A")` returns -1
- "AV" renders with tight kerning

### Test Execution

**Location**: Run in Mini Micro interpreter

```miniscript
import "bmfFonts"

// Test 1: Basic load
f1 = bmfFonts.Font.load("test_yaff_simple.yaff")
if f1 then
    print "Test 1 PASS: Basic YAFF loaded"
    f1.print "ABC", 10, 100
else
    print "Test 1 FAIL: Load returned null"
end if

// Test 2: With metrics
f2 = bmfFonts.Font.load("test_yaff_metrics.yaff")
if f2 and f2.sizeOver == 6 then
    print "Test 2 PASS: Metrics calculated correctly"
else
    print "Test 2 FAIL: Metrics incorrect"
end if

// Test 3: Monospace + kerning
f3 = bmfFonts.Font.load("test_yaff_monospace.yaff")
if f3 and f3.kern("V", "A") == -1 then
    print "Test 3 PASS: Kerning applied"
else
    print "Test 3 FAIL: Kerning missing"
end if
```

---

## Implementation Checklist

### Parser Infrastructure
- [ ] Implement `Font.loadYAFF(path)` stub replacement
- [ ] Implement `file.readLines()` wrapper (if needed)
- [ ] Implement line-by-line parsing state machine
- [ ] Implement error reporting with line numbers (1-based)

### Pass 1: Global Properties
- [ ] Skip comments and blank lines
- [ ] Parse property keys (letters/digits/underscore/dash/dot format)
- [ ] Handle single-line values
- [ ] Handle multi-line values (indented continuation + quote stripping)
- [ ] Extract spacing, direction, metrics (line-height, ascent, descent)
- [ ] Stop at first glyph label

### Pass 2: Glyph Definitions
- [ ] Parse glyph labels (u+, 0x, ', ") with error on invalid hex
- [ ] Handle multi-label glyphs (store first, skip others with TODO)
- [ ] Parse indented bitmap lines
- [ ] Validate bitmap: consistent widths, only `.`/`@` characters
- [ ] Convert ASCII art to `colors[]` array (reverse row order)
- [ ] Parse per-glyph properties (left/right bearing, shift-up)
- [ ] Track first non-empty glyph width for monospace inference
- [ ] Create CharData objects and store in `Font.chars`
- [ ] Parse kerning (right-kerning single-line format)

### Metric Calculation
- [ ] Calculate `Font.sizeOver` (ascent or max shift_up + height)
- [ ] Calculate `Font.sizeUnder` (descent or max negative shift_up, min 1)
- [ ] Calculate `Font.lineHeight` (line-height property or inferred)
- [ ] Handle empty font defaults

### Per-Glyph Positioning
- [ ] Calculate `CharData.relX` from left-bearing
- [ ] Calculate `CharData.relY` from shift-up
- [ ] Infer monospace cellWidth (cell-size property, first glyph, or default 8)
- [ ] Calculate `CharData.shift` based on spacing type

### Kerning
- [ ] Parse right-kerning property (comma-separated pairs)
- [ ] Convert kerning labels to characters
- [ ] Call `Font.setKern()` for each valid pair
- [ ] Handle invalid label references silently

### Integration & Testing
- [ ] Update `Font.load()` dispatch (handle .yaff extension)
- [ ] Create test YAFF files (3 phases as described)
- [ ] Test basic load without error
- [ ] Test metrics calculation
- [ ] Test rendering with `Font.print()`
- [ ] Test monospace vs proportional
- [ ] Test kerning application

### Documentation & Comments
- [ ] Add TODO comments for future enhancements (multi-label, debug mode, etc.)
- [ ] Document coordinate system conversions
- [ ] Add inline comments for complex parsing logic
- [ ] Update `.github/copilot-instructions.md` with YAFF support info

---

## Future Enhancements (TODO)

1. **Multi-label glyph aliasing**: Support storing CharData under multiple labels
2. **Debug/verbose mode**: Log skipped labels, invalid kerning references
3. **Multi-line kerning**: Support `right-kerning:` with newline and indented pairs
4. **Greyscale YAFF**: Convert multi-level (2/4/16/256) to alpha channel support
5. **Left-kerning**: Support `left-kerning` property symmetrically
6. **Unrecognized properties**: Log all ignored per-glyph properties
7. **Encoding hints**: Use YAFF encoding/default-char properties for fallback handling

---

## Code Location Reference

| Component | File | Line Range | Notes |
|---|---|---|---|
| Font class definition | [bmfFonts.ms](bmfFonts.ms#L88) | 88-597 | Main Font class |
| Font.load() | [bmfFonts.ms](bmfFonts.ms#L114-L124) | 114-124 | Dispatcher (edit here) |
| Font.loadBMF() | [bmfFonts.ms](bmfFonts.ms#L127-L203) | 127-203 | Binary loader (reference) |
| Font.loadYAFF() | [bmfFonts.ms](bmfFonts.ms#L121-L123) | 121-123 | Stub to implement |
| CharData class | [bmfFonts.ms](bmfFonts.ms#L9-L71) | 9-71 | Glyph data structure |
| Font.printChar() | [bmfFonts.ms](bmfFonts.ms#L450-L480) | 450-480 | Rendering function (verify compatibility) |
| Font.print() | [bmfFonts.ms](bmfFonts.ms#L482-L491) | 482-491 | Main print function |

---

## Summary

This plan converts YAFF text files to BMF v1.1 Font objects at load time. The two-pass parser extracts properties and glyphs, calculates metrics from bitmap data, and applies positioning/kerning offsets. Rendering functions require no changes. Error handling uses null return + printed messages with line numbers for debugging. Testing validates parser, metrics, rendering, and kerning in three phases.
