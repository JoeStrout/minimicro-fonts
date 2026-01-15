import "bmfFonts"

clear

// Test 1: Basic load
f1 = bmfFonts.Font.load("/usr/fonts/amiga-ks10-topaz-08.yaff")
f1.print "YAFF:", 10, 150, 2  // Scale 2x for visibility
f1.print "The quick brown fox jumps over the lazy dog.", 10, 130, 2

f2 = bmfFonts.Font.load("/usr/fonts/minimicro-pro-12.bmf")
f2.print "BMF:", 10, 50, 2  // Scale 2x for visibility
f2.print "The quick brown fox jumps over the lazy dog.", 10, 30, 2

f1.save("test_output.yaff")
f2.save("test_output2.yaff")

f1 = null
f2 = null

yield
key.get
clear

// Test 2: Reload saved fonts
f3 = bmfFonts.Font.load("test_output.yaff")
f3.print "Reloaded YAFF:", 10, 150, 2
f3.print "The quick brown fox jumps over the lazy dog.", 10, 130, 2

f4 = bmfFonts.Font.load("test_output2.yaff")
f4.print "Reloaded BMF:", 10, 50, 2
f4.print "The quick brown fox jumps over the lazy dog.", 10, 30, 2

key.get
clear

// Test 3: Save YAFF font as BMF
f3.save("test_output_converted.bmf")
f5 = bmfFonts.Font.load("test_output_converted.bmf")
f5.print "Converted to BMF:", 10, 100, 2
f5.print "The quick brown fox jumps over the lazy dog.", 10, 80, 2