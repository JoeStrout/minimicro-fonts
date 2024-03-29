// This file takes a folder containing fontData.grfon and a bunch of
// little image files (in the format produced by unpack.ms), and 
// packs them up into a .bmf file.

if env.importPaths.indexOf("..") == null then env.importPaths.insert 0, ".."
import "bmfFonts"
import "stringUtil"
import "grfon"

clear; text.row = 20

if globals.hasIndex("srcPath") and globals.hasIndex("destPath") then
	// swap these if they appear to have come directly from unpack
	if srcPath.endsWith(".bmf") then
		temp = srcPath; srcPath = destPath; destPath = temp
	end if
end if

if not globals.hasIndex("srcPath") or not srcPath then
	srcPath = input("Path to source folder: ")
else
	inp = input("Path to source folder [" + srcPath + "]: ")
	if inp then srcPath = inp
end if

if not file.children(srcPath) then
	print "Unable to read any files at " + srcPath
	exit
end if

// Read the GRFON data
grfonFile = file.child(srcPath, "fontData.grfon")
if not file.exists(grfonFile) then
	print "Unable to read " + grfonFile
	exit
end if
grfonData = grfon.parse(file.readLines(grfonFile).join(char(10)))
print "Read " + grfonFile + ", a version " + grfonData.version
print "file containing " + grfonData.chars.len + " characters"

// construct a Font out of the data from the file, plus the images
font = new bmfFonts.Font
font = font + grfonData
font.chars = {}
for codePoint in grfonData.chars.indexes
	charData = new bmfFonts.CharData + grfonData.chars[codePoint]
	charData.image = file.loadImage(file.child(srcPath, codePoint + ".png"))
	font.chars[char(codePoint)] = charData
end for

gfx.clear
font.print "the quick brown fox jumps over the lazy dog.", 0, 640+font.sizeOver
font.print "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG.", 0, 590
font.print "Little women, eminem, Molly Williams… ain't nothin'!", 0, 564
//font.print "Axis 0+, 1-, 2+2=4, 8-5-3.", 0, 564

x = 500; y = 600
for i in range(5)
	gfx.line x-10, y, 900, y, color.gray
	font.print "lineHeight " + font.lineHeight + ", a joy at y="+y, x, y
	y = y - font.lineHeight
end for

if not globals.hasIndex("destPath") or not destPath then
	destPath = input("Path to output .bmf file: ")
else
	inp = input("Path to output .bmf file [" + destPath + "]: ")
	if inp then destPath = inp
end if

font.save destPath
print "Wrote BMF file to " + destPath
