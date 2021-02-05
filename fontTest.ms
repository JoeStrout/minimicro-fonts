
Font = {}
Font.data = null
Font.chars = null   // key: character; value: charData map

// Helper function to load one character into the given
// charData map.  Return the next data position after
// the character has been read (i.e., position of next char).
Font.loadOneChar = function(data, pos, charData)
	charData.width = data.byte(pos)
	charData.height = data.byte(pos+1)
	charData.relX = data.byte(pos+2)
	charData.relY = data.byte(pos+3)
	charData.shift = data.byte(pos+4)
	charData.colors = []
	charData.image = null
	pos = pos + 5
	bytes = charData.width * charData.height
	if bytes then
		for i in range(0, bytes-1)
			charData.colors.push data.byte(pos+i)
		end for
	end if
	return pos + bytes
end function	

Font.load = function(path)
	data = file.loadRaw(path)
	if data == null then return null
	f = new  Font
	f.data = data
	f.chars = {}
	data.littleEndian = true
	vers = data.byte(4)
	print "Font version: " + floor(vers/16) + "." + vers % 16
	f.lineHeight = data.sbyte(5)
	f.sizeOver = data.sbyte(6)
	f.sizeUnder = data.sbyte(7)
	f.addSpace = data.sbyte(8)
	f.sizeInner = data.sbyte(9)
	f.alphaBits = 0
	f.numPalettes = 1
	if vers >= 1.2 then
		f.alphaBits = data.byte(12)
		f.numPalettes = data.byte(13) + 1
	end if
	palSize = data.byte(16)
	f.palette = []
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

	for i in range(1, numChars)
		// Read one character
		charData = {}
		charData.charCode = data.byte(pos)
		pos = pos + 1
		pos = f.loadOneChar(data, pos, charData)

		f.chars[char(charData.charCode)] = charData
	end for
	// ToDo: read non-ASCII characters too
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
	clrRange = 2^(8 - self.alphaBits)
	alphaScale = 255/(2^self.alphaBits - 1)
	baseColor = self.palette[0]
	if d.width and d.height then
		i = 0
		for bitmapY in range(d.height - 1)
			for bitmapX in range(0, d.width - 1)
				c = d.colors[i]
				i = i + 1
				if not c then continue
				if self.alphaBits then
					a = floor(c / clrRange) * alphaScale
					pixelColor = baseColor + hex2(a)
				else
					pixelColor = self.palette[c-1]
				end if
				img.setPixel bitmapX, bitmapY, pixelColor
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
	x = x + d.relX
	y = y - self.sizeOver - d.relY - d.image.height
	gfx.drawImage d.image, x, y
	//gfx.drawRect x, y, d.image.width, d.image.height, color.yellow
	return d.shift
end function

Font.print = function(s, x=20, y=320)
	for c in s
		x = x + self.renderChar(c, x, y) + self.addSpace
	end for
end function

Font.width = function(s)
	sum = 0
	for c in s
		d = self.charData(c)
		sum = sum + d.shift
	end for
	return sum
end function

if locals == globals then
	clear
	
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

	text.row = 15
	g = Font.load("fonts/arb22v12.bmf")
	//g.charData(" ").shift = 6  // (how to tweak a font)
	//g.charData("w").shift = 13
	g.print "Howdy world!", 100, 400
end if
