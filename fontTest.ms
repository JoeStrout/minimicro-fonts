clear
clear

Font = {}
Font.data = null
Font.chars = null   // key: character; value: charData map

Font.load = function(path)
	data = file.loadRaw(path)
	if data == null then return null
	f = new  Font
	f.data = data
	f.chars = {}
	data.littleEndian = true
	vers = data.byte(4)
	print "Font version: " + floor(vers/16) + "." + vers % 16
	lineHeight = data.byte(5)
	sizeOver = data.byte(6)
	sizeUnder = data.byte(7)
	addSpace = data.byte(8)
	sizeInner = data.byte(9)
	palSize = data.byte(16)
	f.palette = [null]  // (color 0 is transparent or don't draw)
	for i in range(0, palSize-1)
		f.palette.push color.rgb(data.byte(17+i*3)*4, data.byte(18+i*3)*4, data.byte(19+i*3)*4)
	end for
	titleLen = data.byte(17+palSize*3)
	f.title = data.utf8(18+palSize*3, titleLen)
	print f.title
	pos = 18 + palSize*3 + titleLen
	numChars = data.short(pos)
	pos = pos + 2
	print numChars + " characters"
	
	charIdx = 0
	while charIdx < numChars
		// Read one character
		charData = {}
		charData.charCode = data.byte(pos)
		charData.width = data.byte(pos+1)
		charData.height = data.byte(pos+2)
		charData.relX = data.byte(pos+3)
		charData.relY = data.byte(pos+4)
		charData.shift = data.byte(pos+5)
		charData.colors = []
		charData.image = null
		pos = pos + 6
		bytes = charData.width * charData.height
		if bytes then
			for i in range(0, bytes-1)
				charData.colors.push data.byte(pos+i)
			end for
		end if
		pos = pos + bytes
		f.chars[char(charData.charCode)] = charData
		charIdx = charIdx + 1
	end while
	return f
end function

// Get the character data for the given character
// Return null if not found.  (But if we fail to find
// a lowercase letter, automatically look for upper case.)
Font.charData = function(c)	
	if self.chars.hasIndex(c) then return self.chars[c]
	c = c.upper
	if self.chars.hasIndex(c) then return self.chars[c]
	return null	
end function

// Make an Image that represents the given character.
Font.makeCharImage = function(c)
	d = self.charData(c)
	if d == null then return null
	img = Image.create(d.width, d.height, color.clear)
	if d.width and d.height then
		i = 0
		for bitmapY in range(d.height - 1)
			for bitmapX in range(0, d.width - 1)
				c = d.colors[i]
				i = i + 1
				if not c then continue
				img.setPixel bitmapX, bitmapY, self.palette[c]
			end for
		end for		
	end if
	return img
end function

// Get an Image that represents the given character.
// This method uses a cache, so is faster after the first call.
Font.getCharImage = function(c)
	d = self.charData(c)
	if d == null then return null
	if d.image == null then d.image = self.makeCharImage(c)
	return d.image
end function

// Render (draw) the given character, and return how
// far to shift the cursor.
Font.renderChar = function(c, x=480, y=320)
	d = self.charData(c)
	if d == null then return 0
	if d.image == null then d.image = self.makeCharImage(c)
	gfx.drawImage d.image, x, y
	return d.shift
end function

Font.print = function(s, x=20, y=320)
	for c in s
		x = x + self.renderChar(c, x, y)
	end for
end function

// Load a font
f = Font.load("fonts/ming.bmf")

// Print a string in that font to gfx
f.print "Hello world!", 20, 500

// Get a character image, and make a Sprite out of it
spr = new Sprite
spr.image = f.getCharImage("R")
spr.x = 500
spr.y = 500
spr.scale = 3
spr.rotation = 30
display(4).sprites.push spr

