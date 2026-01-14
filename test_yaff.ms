// Test script for YAFF font loading
// Run this in Mini Micro to validate the YAFF implementation

import "bmfFonts"

output = file.open("test_yaff_output.txt", "w")

oldPrint = @print
print = function(msg)
    oldPrint(msg)
    // Flush output to screen immediately
    outer.output.writeLine(msg)
end function

print "="*60
print "YAFF Font Loader Tests"
print "="*60
print ""

// Test 1: Basic load
print "Test 1: Basic YAFF loading..."
f1 = bmfFonts.Font.load("test_yaff_simple.yaff")
if f1 then
    print "  ✓ PASS: Basic YAFF loaded"
    print "  Title: " + f1.title
    print "  LineHeight: " + f1.lineHeight
    print "  Chars: " + f1.chars.len
    print "  Palette: " + f1.palette[0]
    if f1.chars.hasIndex("A") then
        cd = f1.chars.A
        print "  Char A: width=" + cd.width + ", height=" + cd.height + ", shift=" + cd.shift
        print "  Char A: colors.len=" + cd.colors.len + ", first 10 colors=" + cd.colors[:10]
        print "  Char A: relX=" + cd.relX + ", relY=" + cd.relY
        print "  Font: alphaBits=" + f1.alphaBits + ", sizeOver=" + f1.sizeOver + ", sizeUnder=" + f1.sizeUnder
    end if
    print ""
    print "  Rendering 'ABC' at (10, 100)..."
    gfx.clear color.clear
    f1.print "ABC", 10, 100
    print "  Check screen for rendered text"
    print "  Testing direct renderChar to Image..."
    if f1.chars.hasIndex("A") then
        testImg = f1.makeCharImage("A")
        if testImg then
            print "  Created image: " + testImg.width + "x" + testImg.height
            print "  Sample pixels: " + testImg.pixel(0,0) + ", " + testImg.pixel(1,1)
        else
            print "  makeCharImage returned null!"
        end if
    end if
else
    print "  ✗ FAIL: Load returned null"
end if
print ""

// Test 2: With metrics
print "Test 2: Metrics calculation..."
f2 = bmfFonts.Font.load("test_yaff_metrics.yaff")
if f2 then
    print "  ✓ Font loaded"
    print "  sizeOver: " + f2.sizeOver + " (expected 6)"
    print "  sizeUnder: " + f2.sizeUnder + " (expected 2)"
    if f2.chars.hasIndex("A") then
        cd = f2.chars.A
        print "  Char A: relX=" + cd.relX + " (expected 1)"
        print "          relY=" + cd.relY + " (expected -10)"
        print "          shift=" + cd.shift + " (expected 6)"
    end if
    if f2.sizeOver == 6 and f2.sizeUnder == 2 then
        print "  ✓ PASS: Metrics calculated correctly"
    else
        print "  ✗ FAIL: Metrics incorrect"
    end if
else
    print "  ✗ FAIL: Load returned null"
end if
print ""

// Test 3: Monospace + kerning
print "Test 3: Monospace and kerning..."
f3 = bmfFonts.Font.load("test_yaff_monospace.yaff")
if f3 then
    print "  ✓ Font loaded"
    print "  Spacing: " + f3.spacing
    if f3.chars.hasIndex("A") then
        print "  Char A shift: " + f3.chars.A.shift + " (expected 8)"
    end if
    if f3.chars.hasIndex("V") then
        print "  Char V shift: " + f3.chars.V.shift + " (expected 8)"
    end if
    print "  KernMap exists: " + str(f3.kernMap != null)
    if f3.kernMap then print "  KernMap has V: " + str(f3.kernMap.hasIndex("V"))
    kernValue = f3.kern("V", "A")
    print "  Kern(V,A): " + kernValue + " (expected -1)"
    if kernValue == -1 then
        print "  ✓ PASS: Kerning applied correctly"
    else
        print "  ✗ FAIL: Kerning incorrect"
    end if
    print ""
    print "  Rendering 'AVA' at (10, 50)..."
    f3.print "AVA", 10, 50, 2  // Scale 2x for visibility
else
    print "  ✗ FAIL: Load returned null"
end if
print ""

print "="*60
print "Tests complete. Check screen for rendered output."
print "="*60

output.close()
print = @oldPrint