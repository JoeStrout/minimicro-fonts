// This module defines a Font class which can read fonts in BMF format
// version 1.1 or 1.2.  Reference: https://bmf.php5.cz/index.php?page=format
//
// Example of basic usage:
//	 f = Font.load(fontFilePath)
//	 w = f.width("Hello world!")
//   f.print "Hello world!", 480 - w/2, 320


Font = {}
Font.data = null
Font.chars = null   // key: character; value: charData map
Font.kernMap = null  // key: char1; value: map from char2->kern
Font.setKern = function(c1, c2, kern)
	if self.kernMap == null then self.kernMap = {}
	if not self.kernMap.hasIndex(c1) then self.kernMap[c1] = {}
	self.kernMap[c1][c2] = kern
end function
Font.kern = function(c1, c2)
	if self.kernMap == null then return 0
	if not self.kernMap.hasIndex(c1) then return 0
	km = self.kernMap[c1]
	if not km.hasIndex(c2) then return 0
	return km[c2]
end function

// Helper function to load one character into the given
// charData map.  Return the next data position after
// the character has been read (i.e., position of next char).
Font.loadOneChar = function(data, pos, charData)
	charData.width = data.byte(pos)
	charData.height = data.byte(pos+1)
	charData.relX = data.sbyte(pos+2)
	charData.relY = data.sbyte(pos+3)
	charData.shift = data.sbyte(pos+4)
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
	//print "Font version: " + floor(vers/16) + "." + vers % 16
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
	//print f.title
	pos = 18 + palSize*3 + titleLen
	
	// Read ASCII characters
	numAsciiChars = data.short(pos)
	pos = pos + 2
	//print numAsciiChars + " ASCII characters"
	
	for i in range(1, numAsciiChars)
		// Read one character
		charData = {}
		charData.charCode = data.byte(pos)
		pos = pos + 1
		pos = f.loadOneChar(data, pos, charData)
		
		f.chars[char(charData.charCode)] = charData
	end for
	if pos >= data.len then return f
	
	// Read non-ASCII characters
	numOtherChars = data.uint(pos)
	pos = pos + 4
	//print numOtherChars + " non-ASCII characters"
	for i in range(1, numOtherChars)
		// Read one character
		charData = {}
		charData.charCode = data.uint(pos)
		pos = pos + 4
		pos = f.loadOneChar(data, pos, charData)
		
		f.chars[char(charData.charCode)] = charData
	end for
	
	// Read kerning info
	if pos >= data.len then return f
	kernCount = data.ushort(pos)
	//print kernCount + " kerning pairs"
	pos = pos + 2
	for i in range(1, kernCount)
		c1 = data.uint(pos)
		c2 = data.uint(pos+4)
		k = data.short(pos+8)
		f.setKern char(c1), char(c2), k
		pos = pos + 10
	end for
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
	if d.image == null and d.width > 0 then d.image = self.makeCharImage(c)
	x = x + d.relX
	if d.image != null then
		y = y - self.sizeOver - d.relY - d.image.height
		gfx.drawImage d.image, x, y
		//gfx.drawRect x, y, d.image.width, d.image.height, color.yellow
	end if
	return d.shift
end function

Font.print = function(s, x=20, y=320)
	lastc = ""
	kernCount = 0
	for c in s
		if self.kern(lastc, c) then
			//print lastc + c + ": " + self.kern(lastc, c)
			kernCount = kernCount + 1
		end if
		x = x + self.kern(lastc, c)
		x = x + self.renderChar(c, x, y) + self.addSpace
		lastc = c
	end for
	//print "Kern applied to " + kernCount + "/" + (s.len-1) + " pairs"
end function

Font.width = function(s)
	sum = 0
	lastc = ""
	for c in s
		d = self.charData(c)
		sum = sum + d.shift + self.addSpace + self.kern(lastc, c)
		lastc = c
	end for
	return sum
end function

demo = function()
	clear; text.row = 0
	
	fontsFolder = "fonts/fonts"
	if not file.exists(fontsFolder) then fontsFolder = "fonts"
	if not file.exists(fontsFolder) then
		print "Unable to locate fonts folder."
		return
	end if
	
	y = 640
	for fontFile in file.children(fontsFolder)
		if fontFile[-4:] != ".bmf" then continue
		f = Font.load(file.child(fontsFolder, fontFile))
		if f == null then	continue
		f.print fontFile + ": " + f.title, 10, y + f.sizeOver
		y = y - f.lineHeight - 4
	end for
end function

if locals == globals then demo
