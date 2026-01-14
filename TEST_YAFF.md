# YAFF Font Format Testing

This directory contains test files for validating the YAFF (Yet Another Font Format) loader implementation in bmfFonts.ms.

## Test Files

### test_yaff_simple.yaff
Basic test with 3 ASCII glyphs (A, B, C) to validate:
- File loading
- Global properties (name, line-height)
- Basic glyph parsing
- Bitmap conversion (4×4 glyphs)
- Rendering with `Font.print()`

### test_yaff_metrics.yaff
Tests metric calculation and positioning with:
- Explicit ascent/descent properties
- Per-glyph positioning metrics (left-bearing, right-bearing, shift-up)
- Proportional spacing
- Coordinate system conversion (YAFF shift-up → BMF relY)

### test_yaff_monospace.yaff
Tests monospace fonts and kerning with:
- Monospace spacing type
- cell-size property for uniform advance width
- right-kerning property (V,A pair with -1 kern)
- Kerning application in Font.print()

## Running Tests

To test the YAFF implementation in Mini Micro:

```miniscript
// Option 1: Run the test script
run "test_yaff.ms"

// Option 2: Manual testing
import "bmfFonts"
f = bmfFonts.Font.load("test_yaff_simple.yaff")
if f then
    print "Loaded: " + f.title
    f.print "ABC", 100, 300
end if
```

## Expected Results

### Test 1: Basic Load
- Font loads without error
- `Font.title` = "Test Font 8px"
- `Font.lineHeight` = 10
- 3 glyphs in `Font.chars` (A, B, C)
- Each glyph: 4×4 pixels
- Renders "ABC" on screen

### Test 2: Metrics
- `Font.sizeOver` = 6 (from ascent property)
- `Font.sizeUnder` = 2 (from descent property)
- Char A: `relX=1`, `relY=-10`, `shift=6`

### Test 3: Monospace + Kerning
- All glyphs use `shift=8` (uniform cell width)
- `Font.kern("V", "A")` returns -1
- "AVA" renders with tight kerning between V and A

## YAFF Format Reference

For full YAFF specification, see:
https://github.com/robhagemans/monobit/blob/master/YAFF.md

### Minimal Example

```yaff
yaff: 1.0
name: My Font

u+0041:
    .@@.
    @..@
    @@@.
    @..@
```

### With Metrics

```yaff
yaff: 1.0
name: Custom Font
spacing: proportional
ascent: 8
descent: 2

u+0041:
    .@@.
    @..@
    @@@.
    @..@
    
    left-bearing: 1
    right-bearing: 1
    shift-up: 6
```

### With Kerning

```yaff
u+0041:
    .@@.
    @..@
    @@@.
    @..@
    
    right-kerning: u+0056 -2, u+0057 -1
```

## Implementation Notes

- YAFF files are converted to BMF v1.1 at load time
- White palette (`#FFFFFF`) used for tinting support
- Monospace fonts: uniform `shift` from `cell-size` or first glyph width
- Proportional fonts: individual `shift` from bearings + width
- Bitmap rows reversed during parsing (YAFF top-to-bottom → BMF bottom-to-top)
- Multi-label glyphs: first label stored, others skipped (TODO: aliasing support)
