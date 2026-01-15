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