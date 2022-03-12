// This program unpacks a BMF font into a GRFON data file
// plus a little image for every glyph.

if env.importPaths.indexOf("..") == null then env.importPaths.push ".."
import "bmfFonts"
import "grfon"

if globals.hasIndex("srcPath") and globals.hasIndex("destPath") then
	// swap these if they appear to have come directly from pack
	if destPath.endsWith(".bmf") then
		temp = srcPath; srcPath = destPath; destPath = temp
	end if
end if


if not globals.hasIndex("srcPath") or not srcPath then
	srcPath = input("Path to .bmf file: ")
else
	inp = input("Path to .bmf file [" + srcPath + "]: ")
	if inp then srcPath = inp
end if

font = bmfFonts.Font.load(srcPath)
if font == null then
	print "Unable to read font file at " + srcPath
	exit
end if

if not globals.hasIndex("destPath") or not destPath then
	destPath = input("Path to output folder: ")
else
	inp = input("Path to output folder [" + destPath + "]: ")
	if inp then destPath = inp
end if

if not file.exists(destPath) then
	print "Creating output folder"
	file.makedir destPath
end if

// Generate the GRFON file representing the font,
// by simply removing the keys that are troublesome.
f = font + {}
f.remove "__isa"
f.remove "chars"
f.remove "data"
f.chars = {}
for kv in font.chars
	character = kv.key
	charCode = character.code
	// Do something similar for the chars...
	c = kv.value + {}
	c.remove "__isa"
	c.remove "colors"
	c.remove "image"
	f.chars[charCode] = c
	// ...and while we're at it, save out the image too
	img = font.getCharImage(character)
	if img == null then continue
	imgFile = file.child(destPath, charCode + ".png")
	file.saveImage imgFile, img
	print "Wrote " + img.width + "x" + img.height + " image for " + character + " to " + imgFile
end for
grfonFile = file.child(destPath, "fontData.grfon")
file.writeLines grfonFile, grfon.toGRFON(f).split(char(10))
print "Wrote font data to " + grfonFile
