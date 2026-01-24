import "bmfFonts"

clear

// Test multi-line indented label format with Athens_18.yaff
print "Loading Athens_18.yaff (multi-line indented labels)..."
f = bmfFonts.Font.load("fonts/Athens_18.yaff")

if f == null then
    print "ERROR: Failed to load Athens_18.yaff"
    exit
end if

print "Font loaded successfully!"
print "Font name: " + f.title
print "Line height: " + f.lineHeight
print "Characters loaded: " + f.chars.len

// Test multi-label aliasing with actual aliased characters
// In Athens_18.yaff, u+00a0 (160) and 0xca (202) are defined together as aliases
nbsp = char(160)   // u+00a0 (no-break space)
char202 = char(202)  // 0xca

print "Testing multi-label aliasing:"
if f.chars.hasIndex(nbsp) then
    print "  Found 0xa0 (160): width=" + f.chars[nbsp].width
else
    print "  ERROR: Missing char 160"
end if

if f.chars.hasIndex(char202) then
    print "  Found 0xca (202): width=" + f.chars[char202].width
else
    print "  ERROR: Missing char 202"
end if

// Check if they're aliased (same CharData object)
if f.chars.hasIndex(nbsp) and f.chars.hasIndex(char202) then
    if f.chars[nbsp] == f.chars[char202] then
        print "  SUCCESS: 0xa0 and 0xca are aliased (same CharData object)"
    else
        print "  ERROR: 0xa0 and 0xca are not aliased (should be)"
    end if
end if

// Render sample text
print ""
print "Rendering sample text..."
f.print "Testing Athens 18pt Font", 20, 300
f.print "ABCDEFGHIJKLMNOPQRSTUVWXYZ", 20, 280
f.print "abcdefghijklmnopqrstuvwxyz", 20, 260
f.print "0123456789", 20, 240

print ""
print "Test complete. Check display for rendered text."
