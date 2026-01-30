// This module defines a Font class which can read fonts in BMF format
// version 1.1 or 1.2.  Reference: https://bmf.wz.cz/index.php?page=format
//
// Example of basic usage:
//	 f = Font.load(fontFilePath)
//	 w = f.width("Hello world!")
//   f.print "Hello world!", 480 - w/2, 320

// Helper function to expand a list description such as:
//    1,3-5,null*2,12,'A'-'C'
// into a full list such as:
//    [1, 3, 4, 5, null, null, 12, 65, 66, 67]
// Each element of the comma-delimited description string can be one of:
//	- a number, e.g. 42
//  - a Unicode (hexadecimal) value, e.g. U+2611
//  - a range of numbers, e.g. 40-43
//  - null (by itself, represents a single null entry)
//  - null times a quantity, e.g. null*3 (represents three nulls)
//  - a character in single quotes, e.g. 'A'
//  - a range of characters, e.g. 'A'-'Z'
//  - or even a range defined by a character and number, e.g. 'A'-127 or 32-'Z'
//  Note that you can't represent the single-quote itself by putting it in single
//  quotes; instead just use its Unicode value: 39.
expandList = function(desc)
	result = []	
	rangeStarted = false
	
	reportError = function(msg)
		st = stackTrace[:]
		print "expandList error: " + msg + " at " + i
		print desc
		print " " * i + char(8593)  // (up-arrow)
		print
		for entry in st; print "- " + entry; end for
		exit
	end function
	
	addValue = function(value)
		if rangeStarted then
			if result.len == 0 or result[-1] == null then reportError "invalid range syntax"
			outer.result += range(result.pop, value)
			outer.rangeStarted = false
		else
			result.push value
		end if
	end function

	i = -1
	while i+1 < desc.len
		i += 1
		c = desc[i]
		if c == " " then continue
		if c == "'" then
			// Character literal: must be a single character, followed by a close '
			if i+2 >= desc.len or desc[i+2] != "'" then reportError "bad character syntax"
			value = desc[i+1].code
			addValue value
			i += 2
		else if "0" <= c <= "9" then
			// Numeric literal
			value = c.val
			while i+1 < desc.len and "0" <= desc[i+1] <= "9"
				i += 1
				value = value * 10 + desc[i].val
			end while
			addValue value
		else if c == "," then
			// ToDo
		else if c == "-" then
			// Range indicator
			rangeStarted = true
		else if c == "n" and desc[i:i+4] == "null" then
			// null
			result.push null
			i += 3
		else if c == "U" or c == "u" then
			// Unicode: U+ followed by a hex number
			if i+2 >= desc.len or desc[i+1] != "+" then reportError "bad Unicode syntax"
			hexStr = ""
			i += 2
			while i < desc.len and "0123456789abcdefABCDEF".indexOf(desc[i]) != null
				hexStr += desc[i]
				i += 1
			end while
			print "Got unicode: " + hexStr
			addValue hexVal(hexStr)
		else if c == "*" then
			// after a star should be a number, then comma or EOL
			commaPos = desc.indexOf(",", i)
			if i == null then i = desc.len
			count = desc[i+1:commaPos].val
			result += [result[-1]] * (count - 1)
			i = commaPos-1
		end if
	end while
	return result
end function


// Helper method to cut an image up into a bunch of smaller images, by a regular grid.
// Cells are assumed to be arranged in row order, starting at top left.
splitByGrid = function(image, cellWidth=16, cellHeight=16, leftMargin=0, topMargin=0)
	result = []
	y = image.height - topMargin
	while y - cellHeight >= 0
		x = leftMargin
		while x + cellWidth <= image.width
			result.push image.getImage(x, y - cellHeight, cellWidth, cellHeight)
			x += cellWidth
		end while
		y -= cellHeight
	end while
	return result
end function

// CharData class, storing data about just one character in a particular font.
CharData = {}
CharData._name = "bmfFonts.CharData";

// Helper function to load one character into the given
// charData map.  Return the next data position after
// the character has been read (i.e., position of next char).
CharData.load = function(data, pos)
	self.width = data.byte(pos)
	self.height = data.byte(pos+1)
	self.relX = data.sbyte(pos+2)
	self.relY = data.sbyte(pos+3)
	self.shift = data.sbyte(pos+4)
	self.colors = []
	self.image = null
	pos = pos + 5
	bytes = self.width * self.height
//	print "For " + self.charCode + " (" + char(self.charCode) + ") " + self.width+"x"+self.height + " char at " + pos + ", expecting " + bytes + " bytes of data"
	if pos + bytes > data.len then
		print "ERROR: unexpected end of data"
		return pos + bytes
	end if
	if bytes then
		for i in range(0, bytes-1)
			self.colors.push data.byte(pos+i)
		end for
	end if
	return pos + bytes
end function

CharData.FromImage = function(image, relX=0, relY=0, shift=null)
	cd = new CharData
	cd.image = image
	cd.width = image.width
	cd.height = image.height
	cd.relX = relX
	cd.relY = relY
	if shift == null then cd.shift = image.width else cd.shift = shift
	return cd
end function	

hexStrToInt = {}
for i in range(0,255); hexStrToInt[hex2(i)] = i; end for

// Find the colors array from our image and the given palette map,
// which maps each usable color to an index (1 to number of colors).
// Note that an index of 0 always means "don't draw" (transparent).
// Also, this function has no effect if self.image is null.
CharData.findColorsFromImage = function(paletteMap, alphaBits)
	// YAFF-loaded fonts don't have an image property, only colors array
	if not self.hasIndex("image") or not self.image then return
	self.colors = []
	for bitmapY in range(self.height - 1)
		for bitmapX in range(0, self.width - 1)
			c = self.image.pixel(bitmapX, bitmapY)
			alpha = c[-2:]; c = c[:-2]
			if paletteMap.hasIndex(c) then
				colorIdx = paletteMap[c]
			else
				colorIdx = 0
			end if
			if alphaBits == 8 then
				// when alphaBits is 8, ignore the actual color
				// and just store the alpha instead.
				colorIdx = hexStrToInt[alpha]
			else if alphaBits == 0 then
				// and when it's 0, still skip (use index 0 for) any transparent pixel
				if alpha == "00" then colorIdx = 0
			end if
			self.colors.push colorIdx
		end for
	end for
end function

// Write the data for this character out to a binary stream (defined
// in Font.save, below).  This is a helper method for Font.save.
CharData.save = function(stream, paletteMap, alphaBits)
	stream.writeByte self.width
	stream.writeByte self.height
	stream.writeByte self.relX
	stream.writeByte self.relY
	stream.writeByte self.shift
	if self.width or self.height then
		self.findColorsFromImage paletteMap, alphaBits
		for c in self.colors
			stream.writeByte c
		end for
	end if
end function

// Font class, storing all data about a particular font.
Font = {}
Font._name = "bmfFonts.Font";
Font.data = null	// raw data from file
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

// Font.load: Main entry point for reading a font from disk.
// Call this on the Font class itself (i.e. not an instance).
// Pass in the path to the font file; get back a new Font object.
Font.load = function(path)
	ext = path.split(".")[-1].lower
	if ext == "bmf" then
		return Font.loadBMF(path)
	else if ext == "yaff" then
		return Font.loadYAFF(path)
	end if
	print "Font.load: unrecognized font file extension: " + ext
	return null
end function


Font.loadYAFF = function(path)
	// Load a YAFF font file (Yet Another Font Format).
	// https://github.com/robhagemans/monobit/blob/master/YAFF.md
	
	// Read file as UTF-8 text
	lines = file.readLines(path)
	if lines == null then
		print "Font.loadYAFF: Unable to read YAFF file at " + path
		return null
	end if
	
	// Helper: Check if line is blank or whitespace-only
	isBlank = function(line)
		if not line then return true
		for i in range(0, line.len - 1)
			c = line[i]
			if c != " " and c != char(9) then return false
		end for
		return true
	end function
	
	// Helper: Check if line is comment (starts with #)
	isComment = function(line)
		if not line then return false
		for i in range(0, line.len - 1)
			c = line[i]
			if c == "#" then return true
			if c != " " and c != char(9) then return false
		end for
		return false
	end function
	
	// Helper: Get leading whitespace indent level
	getIndent = function(line)
		if not line then return 0
		indent = 0
		for i in range(0, line.len - 1)
			c = line[i]
			if c == " " or c == char(9) then
				indent = indent + 1
			else
				return indent
			end if
		end for
		return indent
	end function
	
	// Helper: Strip leading/trailing whitespace
	strip = function(s)
		if not s then return ""
		start = 0
		while start < s.len and (s[start] == " " or s[start] == char(9))
			start = start + 1
		end while
		if start >= s.len then return ""
		endPos = s.len - 1
		while endPos >= start and (s[endPos] == " " or s[endPos] == char(9))
			endPos = endPos - 1
		end while
		return s[start:endPos + 1]
	end function
	
	// Helper: Check if string is property key format (letters, digits, underscore, dash, dot)
	isPropertyKey = function(s)
		if not s then return false
		for i in range(0, s.len - 1)
			c = s[i]
			isValid = (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or
			          (c >= "0" and c <= "9") or c == "_" or c == "-" or c == "."
			if not isValid then return false
		end for
		return true
	end function
	
	// Helper: Parse a glyph label and return character string (or null on error)
	// Returns map: {char: "A", code: 65, lineNum: N}
	parseLabel = function(label, lineNum)
		label = strip(label)
		if not label then return null
		
		result = {}
		
		// Check for u+XXXX format
		if label.len > 2 and (label[:2] == "u+" or label[:2] == "U+") then
			hexPart = label[2:]
			codepoint = hexVal(hexPart) //hexToInt(hexPart)
			if codepoint == null then
				print "Font.loadYAFF: Invalid hex codepoint " + label + " at line " + lineNum
				return null
			end if
			result.char = char(codepoint)
			result.code = codepoint
			result.lineNum = lineNum
			return result
		end if
		
		// Check for 0xXX format
		if label.len > 2 and (label[:2] == "0x" or label[:2] == "0X") then
			hexPart = label[2:]
			codepoint = hexVal(hexPart) // hexToInt(hexPart)
			if codepoint == null then
				print "Font.loadYAFF: Invalid hex codepoint " + label + " at line " + lineNum
				return null
			end if
			result.char = char(codepoint)
			result.code = codepoint
			result.lineNum = lineNum
			return result
		end if
		
		// Check for 0oXX octal format (parse as decimal for simplicity, rare)
		if label.len > 2 and (label[:2] == "0o" or label[:2] == "0O") then
			// Simplified: treat as decimal for now (octal is rare)
			codepoint = label[2:].val
			if codepoint == null then
				print "Font.loadYAFF: Invalid octal codepoint " + label + " at line " + lineNum
				return null
			end if
			result.char = char(codepoint)
			result.code = codepoint
			result.lineNum = lineNum
			return result
		end if
		
		// Check for decimal number
		if label[0] >= "0" and label[0] <= "9" then
			codepoint = label.val
			if codepoint == null then
				print "Font.loadYAFF: Invalid decimal codepoint " + label + " at line " + lineNum
				return null
			end if
			result.char = char(codepoint)
			result.code = codepoint
			result.lineNum = lineNum
			return result
		end if
		
		// Check for 'char' format (single quotes)
		if label[0] == "'" and label[-1] == "'" and label.len >= 2 then
			content = label[1:-1]
			if content.len == 0 then return null
			// Use first character only for multi-char sequences
			result.char = content[0]
			result.code = content[0].code
			result.lineNum = lineNum
			return result
		end if
		
		// Check for "tag" format (double quotes)
		if label[0] == char(34) and label[-1] == char(34) and label.len >= 2 then
			content = label[1:-1]
			if content.len == 0 then return null
			// Tag: use string as-is, charCode = 0
			result.char = content
			result.code = 0
			result.lineNum = lineNum
			return result
		end if
		
		// Check for bare word tag (alphanumeric, underscore, hyphen)
		// e.g., "default", "placeholder_d7"
		isValidBareWord = true
		for i in range(0, label.len - 1)
			c = label[i]
			isAlphaNum = (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9")
			if not isAlphaNum and c != "_" and c != "-" then
				isValidBareWord = false
				break
			end if
		end for
		if isValidBareWord and label.len > 0 then
			// Bare word tag
			result.char = label
			result.code = 0
			result.lineNum = lineNum
			return result
		end if
		
		return null
	end function
	
	// PASS 1: Parse global properties
	globalProps = {}
	lineNum = 0
	firstGlyphLine = -1
	
	while lineNum < lines.len
		line = lines[lineNum]
		lineNum = lineNum + 1
		
		// Skip blank lines and comments
		if isBlank(line) or isComment(line) then continue
		
		// Check if this is a glyph label (starts parsing in Pass 2)
		if line.indexOf(":") != null then
			colonPos = line.indexOf(":")
			beforeColon = line[:colonPos]
			
			// Check if this looks like a glyph label
			beforeStripped = strip(beforeColon)
			if beforeStripped and (beforeStripped[0] == "u" or beforeStripped[0] == "U" or
			   beforeStripped[0] == "0" or (beforeStripped[0] >= "1" and beforeStripped[0] <= "9") or
			   beforeStripped[0] == "'" or beforeStripped[0] == char(34)) then
				// This is a glyph label, stop Pass 1
				firstGlyphLine = lineNum - 1
				break
			end if
			
			// Check if this is a property key
			if isPropertyKey(beforeStripped) then
				key = beforeStripped.lower  // case-insensitive
				valueStart = colonPos + 1
				value = ""
				
				// Check if value is on same line
				if valueStart < line.len then
					value = strip(line[valueStart:])
				end if
				
				// If no value or value is empty, check for multi-line continuation
				if not value then
					valueLines = []
					while lineNum < lines.len
						nextLine = lines[lineNum]
						if isBlank(nextLine) then
							lineNum = lineNum + 1
							break
						end if
						nextIndent = getIndent(nextLine)
						if nextIndent == 0 then break
						// This is a continuation line
						lineNum = lineNum + 1
						stripped = strip(nextLine)
						// Strip surrounding quotes if present
						if stripped.len >= 2 and stripped[0] == char(34) and stripped[-1] == char(34) then
							stripped = stripped[1:-1]
						end if
						valueLines.push stripped
					end while
					value = valueLines.join(char(10))
				end if
				
				globalProps[key] = value
			end if
		end if
	end while
	
	// Initialize Font object with global properties
	f = new Font
	f.version = 1.1
	if globalProps.hasIndex("name") then
		f.title = globalProps["name"]
	else
		f.title = "YAFF Font"
	end if
	f.palette = ["#FFFFFF"]
	f.alphaBits = 0
	f.chars = {}
	f.kernMap = null
	f.aliases = null  // Maps CharData -> list of all character keys (for multi-label glyphs)
	f.addSpace = 0
	f.sizeInner = 0
	f.usedColors = 1
	f.highestUsedColor = 1
	f.numPalettes = 1
	f.data = null
	
	if globalProps.hasIndex("direction") then
		f.direction = globalProps["direction"]
	else
		f.direction = null
	end if
	
	if globalProps.hasIndex("spacing") then
		f.spacing = globalProps["spacing"]
	else
		f.spacing = null
	end if
	
	// PASS 2: Parse glyph definitions
	if firstGlyphLine < 0 then
		// No glyphs, just return font with defaults
		f.lineHeight = 12
		f.sizeOver = -10
		f.sizeUnder = 2
		return f
	end if
	
	lineNum = firstGlyphLine
	cellWidth = null  // For monospace inference
	firstNonEmptyWidth = null
	
	// Track metrics for calculation
	allHeights = []
	allShiftUps = []
	
	while lineNum < lines.len
		line = lines[lineNum]
		
		// Skip blank lines and comments
		if isBlank(line) or isComment(line) then
			lineNum = lineNum + 1
			continue
		end if
		
		// Check for glyph label line (must contain ':')
		colonPos = line.indexOf(":")
		if colonPos == null then
			lineNum = lineNum + 1
			continue
		end if
		
		// Parse label(s) - supports both comma-separated and multi-line indented
		labelPart = line[:colonPos]
		labels = []
		
		// Handle multiple labels separated by commas on same line
		if labelPart.indexOf(",") != null then
			parts = labelPart.split(",")
			for part in parts
				labelInfo = parseLabel(part, lineNum + 1)
				if labelInfo then labels.push labelInfo
			end for
		else
			labelInfo = parseLabel(labelPart, lineNum + 1)
			if labelInfo then labels.push labelInfo
		end if
		
		lineNum = lineNum + 1
		
		// Check for additional label lines (multi-line indented format)
		// Keep reading consecutive label lines until we hit an indented line (bitmap)
		while lineNum < lines.len
			nextLine = lines[lineNum]
			// Skip blank lines and comments
			if isBlank(nextLine) or isComment(nextLine) then
				lineNum = lineNum + 1
				continue
			end if
			// If indented, this is the start of bitmap/properties
			if getIndent(nextLine) > 0 then break
			// Check if this is another label line
			nextColonPos = nextLine.indexOf(":")
			if nextColonPos == null then break
			// Parse this additional label
			nextLabelPart = nextLine[:nextColonPos]
			if nextLabelPart.indexOf(",") != null then
				parts = nextLabelPart.split(",")
				for part in parts
					labelInfo = parseLabel(part, lineNum + 1)
					if labelInfo then labels.push labelInfo
				end for
			else
				labelInfo = parseLabel(nextLabelPart, lineNum + 1)
				if labelInfo then labels.push labelInfo
			end if
			lineNum = lineNum + 1
		end while
		
		if labels.len == 0 then
			print "Font.loadYAFF: Malformed glyph label at line " + (lineNum + 1) + ": expected valid label"
			return null
		end if
		
		// Select canonical charCode: first numeric label (skip tags with code=0)
		glyphCode = 0
		glyphChar = null
		for label in labels
			if not label or not label.hasIndex("char") then continue
			if label.code != 0 and glyphCode == 0 then
				glyphCode = label.code
				glyphChar = label.char
				break
			end if
			end for
		// If all labels are tags, use first tag
		if glyphChar == null then
			if labels[0] and labels[0].hasIndex("char") then
				glyphChar = labels[0].char
				glyphCode = 0
			else
				print "Font.loadYAFF: Invalid label structure at line " + (lineNum + 1)
				return null
			end if
		end if
		
		lineNum = lineNum + 1
		
		// Parse bitmap lines (indented)
		bitmapLines = []
		bitmapIndent = -1
		
		while lineNum < lines.len
			line = lines[lineNum]
			if isBlank(line) then
				lineNum = lineNum + 1
				break
			end if
			if isComment(line) then
				lineNum = lineNum + 1
				continue
			end if
			
			indent = getIndent(line)
			if indent == 0 then break
			
			if bitmapIndent < 0 then bitmapIndent = indent
			
			stripped = strip(line)
			
			// Check for empty glyph marker
			if stripped == "-" then
				lineNum = lineNum + 1
				bitmapLines = []
				break
			end if
			
			// Check if this might be a per-glyph property instead (BEFORE validating bitmap)
			if stripped.indexOf(":") != null then
				colonPos = stripped.indexOf(":")
				possibleKey = strip(stripped[:colonPos])
				if isPropertyKey(possibleKey) then
					// This is a property line, stop bitmap parsing
					break
				end if
			end if
			
			// Validate bitmap characters (only . and @)
			for i in range(0, stripped.len - 1)
				c = stripped[i]
				if c != "." and c != "@" then
					print "Font.loadYAFF: Invalid bitmap character at line " + (lineNum + 1) + ": only '.' and '@' allowed"
					return null
				end if
			end for
			
			bitmapLines.push stripped
			lineNum = lineNum + 1
		end while
		
		// Parse per-glyph properties (skip any leading blank lines first)
		while lineNum < lines.len and isBlank(lines[lineNum])
			lineNum = lineNum + 1
		end while
		
		glyphProps = {}
		while lineNum < lines.len
			line = lines[lineNum]
			if isBlank(line) then
				lineNum = lineNum + 1
				continue
			end if
			if isComment(line) then
				lineNum = lineNum + 1
				continue
			end if
			
			indent = getIndent(line)
			if indent == 0 then break
			
			stripped = strip(line)
			colonPos = stripped.indexOf(":")
			if colonPos == null then break
			
			key = strip(stripped[:colonPos])
			if not isPropertyKey(key) then break
			
			value = strip(stripped[colonPos + 1:])
			glyphProps[key.lower] = value
			lineNum = lineNum + 1
		end while
		
		// Create CharData from bitmap
		cd = new CharData
		cd.charCode = glyphCode
		
		if bitmapLines.len == 0 then
			// Empty glyph
			cd.width = 0
			cd.height = 0
			cd.colors = []
		else
			// Validate consistent width
			cd.width = bitmapLines[0].len
			cd.height = bitmapLines.len
			
			for i in range(0, bitmapLines.len - 1)
				if bitmapLines[i].len != cd.width then
					print "Font.loadYAFF: Inconsistent glyph width at line " + (lineNum - bitmapLines.len + i + 1) + " (expected " + cd.width + ", got " + bitmapLines[i].len + ")"
					return null
				end if
			end for
			
			// Convert bitmap to colors array (reverse row order: bottom-to-top)
			cd.colors = []
			for row in range(0, cd.height - 1)
				lineStr = bitmapLines[row]
				for col in range(0, cd.width - 1)
					if lineStr[col] == "@" then
						cd.colors.push 1
					else
						cd.colors.push 0
					end if
				end for
			end for
			
			// Track first non-empty glyph width for monospace inference
			if firstNonEmptyWidth == null and cd.width > 0 then
				firstNonEmptyWidth = cd.width
			end if
		end if
		
		// Parse positioning metrics
		leftBearing = 0
		rightBearing = 0
		shiftUp = 0
		
		if glyphProps.hasIndex("left-bearing") then
			leftBearing = glyphProps["left-bearing"].val
			if leftBearing == null then leftBearing = 0
		end if
		
		if glyphProps.hasIndex("right-bearing") then
			rightBearing = glyphProps["right-bearing"].val
			if rightBearing == null then rightBearing = 0
		end if
		
		if glyphProps.hasIndex("shift-up") then
			shiftUp = glyphProps["shift-up"].val
			if shiftUp == null then shiftUp = 0
		end if
		
		// Calculate CharData positioning
		cd.relX = leftBearing
		cd.relY = shiftUp
		
		// Calculate shift (advance width) - will be refined after we know if monospace
		cd.shift = leftBearing + cd.width + rightBearing
		if cd.shift <= 0 and cd.width > 0 then cd.shift = cd.width
		
		// Store temporary shift-up for metric calculation
		cd._tempShiftUp = shiftUp
		
		// Track metrics
		if cd.height > 0 then
			allHeights.push cd.height
			allShiftUps.push shiftUp
		end if
		
		// Parse kerning
		if glyphProps.hasIndex("right-kerning") then
			kernStr = glyphProps["right-kerning"]
			// Split by comma
			pairs = kernStr.split(",")
			for pair in pairs
				pair = strip(pair)
				if not pair then continue
				// Split by whitespace - filter out empty parts
				allParts = pair.split(" ")
				parts = []
				for p in allParts
					if p then parts.push p
				end for
				if parts.len >= 2 then
					targetLabel = strip(parts[0])
					kernValueStr = strip(parts[1])
					if not targetLabel or not kernValueStr then continue
					kernValue = kernValueStr.val
					if kernValue != null then
						targetInfo = parseLabel(targetLabel, lineNum)
						if targetInfo and targetInfo.hasIndex("char") then
							f.setKern glyphChar, targetInfo.char, kernValue
						end if
					end if
				end if
			end for
		end if
		
		// Store CharData under all labels (multi-label aliasing)
		if labels.len > 1 then
			// Multiple labels - initialize aliases map if needed
			if f.aliases == null then f.aliases = {}
			aliasList = []
			for label in labels
				if not label or not label.hasIndex("char") then continue
				f.chars[label.char] = cd
				aliasList.push label.char
			end for
			// Store reverse mapping: CharData -> list of all keys
			f.aliases[cd] = aliasList
		else
			// Single label - store normally
			f.chars[glyphChar] = cd
		end if
	end while
	
	// Calculate font-level metrics
	if globalProps.hasIndex("line-height") then
		f.lineHeight = globalProps["line-height"].val
		if f.lineHeight == null then f.lineHeight = 12
	else if allHeights.len > 0 then
		maxHeight = 0
		minShift = 0
		for h in allHeights
			if h > maxHeight then maxHeight = h
		end for
		for s in allShiftUps
			if s < minShift then minShift = s
		end for
		f.lineHeight = maxHeight + (0 - minShift) + 1
	else
		f.lineHeight = 12
	end if
	
	if globalProps.hasIndex("ascent") then
		f.sizeOver = -globalProps.ascent.val
		if f.sizeOver == null then f.sizeOver = -10
	else if allShiftUps.len > 0 and allHeights.len > 0 then
		maxValue = 0
		for i in range(0, allShiftUps.len - 1)
			value = allShiftUps[i] + allHeights[i]
			if value > maxValue then maxValue = value
		end for
		f.sizeOver = -maxValue
	else
		f.sizeOver = -10
	end if
	
	if globalProps.hasIndex("descent") then
		f.sizeUnder = globalProps.descent.val
		if f.sizeUnder == null then f.sizeUnder = 2
	else if allShiftUps.len > 0 then
		minShift = 0
		for s in allShiftUps
			if s < minShift then minShift = s
		end for
		f.sizeUnder = 0 - minShift
		if f.sizeUnder < 1 then f.sizeUnder = 1
	else
		f.sizeUnder = 2
	end if
	
	// Determine monospace cellWidth and update shifts
	if f.spacing == "monospace" or f.spacing == "character-cell" or f.spacing == "multi-cell" then
		// Monospace: use uniform advance width
		if globalProps.hasIndex("cell-size") then
			cellWidth = globalProps["cell-size"].val
			if cellWidth == null then cellWidth = 8
		else if firstNonEmptyWidth != null then
			cellWidth = firstNonEmptyWidth
		else
			cellWidth = 8
		end if
		
		// Update all glyphs to use uniform shift
		for kv in f.chars
			kv.value.shift = cellWidth
		end for
	end if
	
	// Clean up temporary properties
	for kv in f.chars
		if kv.value.hasIndex("_tempShiftUp") then
			kv.value.remove "_tempShiftUp"
		end if
	end for
	
	return f
end function

Font.loadBMF = function(path)
	data = file.loadRaw(path)
	if data == null then return null
	
	f = new  Font
	f.data = data
	f.chars = {}
	data.littleEndian = true
	vers = data.byte(4)
	f.version = floor(vers/16) + 0.1 * (vers % 16)
	f.lineHeight = data.sbyte(5) // from highest to lowest reach; should be >= (sizeUnder - sizeOver)
	f.sizeOver = data.sbyte(6)   // negative value, baseline to top of capital letters
	f.sizeUnder = data.sbyte(7)  // positive or zero, baseline to lowest extends
	f.addSpace = data.sbyte(8)   // extra space to add after each character (can be + or -)
	f.sizeInner = data.sbyte(9)  // negative height of small letters
	f.usedColors = data.byte(10)
	f.highestUsedColor = data.byte(11)
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
	
	for i in range(1, numAsciiChars, 1)
		// Read one character
		p0 = pos
		charData = new CharData
		charData.charCode = data.byte(pos)
		pos = pos + 1
		pos = charData.load(data, pos)
		
		f.chars[char(charData.charCode)] = charData
	end for
	if f.version < 1.2 or pos >= data.len then return f
	
	// Read non-ASCII characters
	numOtherChars = data.uint(pos)
	pos = pos + 4
	for i in range(1, numOtherChars, 1)
		// Read one character
		charData = new CharData
		charData.charCode = data.uint(pos)
		pos = pos + 4
		pos = charData.load(data, pos)
		
		f.chars[char(charData.charCode)] = charData
	end for
	
	// Read kerning info
	if pos >= data.len then return f
	kernCount = data.ushort(pos)
	//print kernCount + " kerning pairs"
	if kernCount > 0 then
		pos = pos + 2
		for i in range(1, kernCount, 1)
			c1 = data.uint(pos)
			c2 = data.uint(pos+4)
			k = data.short(pos+8)
			f.setKern char(c1), char(c2), k
			pos = pos + 10
		end for
	end if
	return f
end function

// Load a font from an image containing characters in a regular grid.
// Specify the width and height of each character (cell), the baseline
// (i.e. how many pixels of each cell should appear below the baseline),
// and optionally, a left/top margin.  Also provide a list description
// of the character code points found in the grid (see expandList).
Font.loadImageGrid = function(imageOrPath, cellWidth=16, cellHeight=16, codePoints=null, baseLine=null, leftMargin=0, topMargin=0)
	// baseLine: default to 1/4 of the cell height
	if baseLine == null then baseLine = floor(cellHeight/4)
	if imageOrPath isa string then imageOrPath = file.loadImage(imageOrPath)
	if not imageOrPath isa Image then
		print "Font.loadImageGrid: unable to load image"
		return null
	end if
	cells = splitByGrid(imageOrPath, cellWidth, cellHeight, leftMargin, topMargin)
	// codePoints: if not specified, assume characters starting at 32 (space)
	if codePoints == null then
		codePoints = range(32, 32+cells.len-1)
	else if codePoints isa string then
		codePoints = expandList(codePoints)
	end if
	if not codePoints isa list then
		print "Font.loadImageGrid: expected list or list description for codePoints"
		return null
	end if
	
	f = new Font
	f.version = 1.2
	f.palette = ["#FFFFFF"]
	f.alphaBits = 0
	f.kernMap = null
	f.title = imageOrPath.name - ".png"
	f.chars = {}
	f.aliases = null  // Maps CharData -> list of all character keys (for multi-label glyphs)
	f.lineHeight = cellHeight
	f.sizeOver = -cellHeight + baseLine
	f.sizeUnder = baseLine
	f.addSpace = 0
	f.sizeInner = -cellHeight/2
	f.usedColors = 1
	f.highestUsedColor = 1
	f.numPalettes = 1

	for i in cells.indexes
		if i >= codePoints.len then break
		cd = CharData.FromImage(cells[i])
		f.chars[char(codePoints[i])] = cd
	end for
	
	return f
end function

Font.save = function(path)
	ext = path.split(".")[-1].lower
	if ext == "bmf" then
		self.saveBMF path
	else if ext == "yaff" then
		self.saveYAFF path
	else
		print "Font.save: unrecognized font file extension: " + ext
	end if
end function

Font.saveYAFF = function(path)
    // Save this font in YAFF format (Yet Another Font Format).
    // https://github.com/robhagemans/monobit/blob/master/YAFF.md
    
    // Helper: Format a character label for YAFF output
    formatLabel = function(charCode, charStr)
        // Check if this is a preserved tag
        if charCode == 0 then
            // Tag - return bare word or quoted
            isBarWord = true
            for i in range(0, charStr.len - 1)
                c = charStr[i]
                isAlphaNum = (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or (c >= "0" and c <= "9")
                if not isAlphaNum and c != "_" and c != "-" then
                    isBarWord = false
                    break
                end if
            end for
            if isBarWord then return charStr else return char(34) + charStr + char(34)
        end if
        
        // For high Unicode, use u+XXXX format
        if charCode > 255 then return "u+" + hex2(charCode)
        
        // For ASCII range, use 0xXX format
        return "0x" + hex2(charCode)
    end function
    
    // Helper: Convert BMF colors array to YAFF bitmap lines
    bitmapToLines = function(colors, width, height)
        if width == 0 or height == 0 then return []
        lines = []
        // Reverse row order: BMF is bottom-to-top, YAFF is top-to-bottom
        for row in range(0, height - 1)
            line = ""
            for col in range(0, width - 1)
                idx = row * width + col
                if idx < colors.len then
                    c = colors[idx]
                    if c == 0 then
                        line = line + "."
                    else
                        line = line + "@"
                    end if
                else
                    line = line + "."
                end if
            end for
            lines.push line
        end for
        return lines
    end function
    
    // Helper: Detect if font is monospace
    detectMonospace = function(font, chars)
        // Check preserved spacing property first
        if font.hasIndex("spacing") and font.spacing != null then
            if font.spacing == "monospace" or font.spacing == "character-cell" or font.spacing == "multi-cell" then
                // Return cell size if available, otherwise detect
                if font.chars.len == 0 then return 8
                for cd in font.chars.values
                    if cd.width > 0 then return cd.shift
                end for
                return 8
            end if
            if font.spacing == "proportional" then return null
        end if
        
        // Analyze shift values
        if chars.len == 0 then return null
        firstShift = null
        for cd in chars.values
            if cd.width == 0 then continue
            if firstShift == null then
                firstShift = cd.shift
            else if cd.shift != firstShift then
                return null  // Variable shifts = proportional
            end if
        end for
        return firstShift
    end function
    
    // Build output line by line
    output = []
    
    // Header
    output.push "yaff: 1.0"
    
    // Global properties
    if self.hasIndex("title") and self.title then
        output.push "name: " + self.title
    end if
    
    // Detect spacing mode
    cellSize = detectMonospace(self, self.chars)
    isMonospace = (cellSize != null)
    
    if isMonospace then
        output.push "spacing: monospace"
        output.push "cell-size: " + cellSize
    else
        output.push "spacing: proportional"
    end if
    
    // Font metrics
    if self.hasIndex("lineHeight") then
        output.push "line-height: " + self.lineHeight
    end if
    if self.hasIndex("sizeOver") then
        output.push "ascent: " + (-self.sizeOver)
    end if
    if self.hasIndex("sizeUnder") then
        output.push "descent: " + self.sizeUnder
    end if
    
    // Optional properties
    if self.hasIndex("direction") and self.direction != null then
        output.push "direction: " + self.direction
    end if
    
    // Blank line after global properties
    output.push ""
    
    // Sort characters by charCode for consistent output
    charList = []
    for c in self.chars.indexes
        charList.push c
    end for
    // Sort by character code
    for i in range(0, charList.len - 2)
        for j in range(i + 1, charList.len - 1)
            if charList[i].code > charList[j].code then
                temp = charList[i]
                charList[i] = charList[j]
                charList[j] = temp
            end if
        end for
    end for
    
	// Track written CharData to avoid duplicates in multi-label case
	writtenGlyphs = {}
	
	// Write each glyph
	for c in charList
		cd = self.chars[c]
		
		// Skip if already written (multi-label aliasing)
		if writtenGlyphs.hasIndex(cd) then continue
		writtenGlyphs[cd] = true
		
		// Format label(s) - check for aliases
		if self.aliases != null and self.aliases.hasIndex(cd) then
			// Multi-label glyph
			labelParts = []
			for aliasChar in self.aliases[cd]
				aliasCd = self.chars[aliasChar]
				if aliasCd.hasIndex("yaffTag") then
					labelParts.push formatLabel(0, aliasCd.yaffTag)
				else
					labelParts.push formatLabel(aliasChar.code, aliasChar)
				end if
			end for
			label = labelParts.join(", ")
		else
			// Single label
			label = formatLabel(cd.charCode, c)
			if cd.hasIndex("yaffTag") then label = formatLabel(0, cd.yaffTag)
		end if
        
        // Write positioning properties (skip if standard for monospace)
        if not isMonospace or leftBearing != 0 then
            if leftBearing != 0 then
                output.push "    left-bearing: " + leftBearing
            end if
        end if
        
        if not isMonospace or rightBearing != 0 then
            if rightBearing != 0 then
                output.push "    right-bearing: " + rightBearing
            end if
        end if
        
        if shiftUp != 0 then
            output.push "    shift-up: " + shiftUp
        end if
        
        // Write kerning for this character
        if self.kernMap != null and self.kernMap.hasIndex(c) then
            kernPairs = []
            kernMap = self.kernMap[c]
            for c2 in kernMap.keys
                kernValue = kernMap[c2]
                c2Label = formatLabel(c2.code, c2)
                kernPairs.push c2Label + " " + kernValue
            end for
            if kernPairs.len > 0 then
                output.push "    right-kerning: " + kernPairs.join(", ")
            end if
        end if
        
        // Blank line after each glyph
        output.push ""
    end for
    
    // Write to file
    err = file.writeLines(path, output)
    if err then
        print "Font.saveYAFF: Error writing file: " + err
        return err
    end if
    
    print "Saved YAFF font with " + self.chars.len + " glyphs to " + path
    return null
end function

// Font.save: Save this font to disk, in either version 1.1
// or version 1.2 format (depending on self.version).  Note
// that this method ignores self.data, and creates new data
// from the current font attributes and character data.
Font.saveBMF = function(path)
	// We'll need a little BinaryStream class wrapping a RawData,
	// to make it easier.  This just expands the RawData buffer as we go.
	BinaryStream = {}
	BinaryStream.littleEndian = true
	BinaryStream.buffer = null
	BinaryStream.pos = 0
	BinaryStream.ensure = function(bytesNeeded=4)
		if self.buffer == null then
			self.buffer = new RawData
			self.buffer.resize 256
			self.buffer.littleEndian = self.littleEndian
		end if		
		while self.pos + bytesNeeded > self.buffer.len
			self.buffer.resize(self.buffer.len * 2)
		end while
	end function
	BinaryStream.writeByte = function(byteVal)
		self.ensure 1
		self.buffer.setByte self.pos, byteVal
		self.pos = self.pos + 1
	end function
	BinaryStream.writeSbyte = function(sbyteVal)
		self.ensure 1
		self.buffer.setSbyte self.pos, sbyteVal
		self.pos = self.pos + 1
	end function
	BinaryStream.writeUshort = function(ushortVal)
		self.ensure 2
		self.buffer.setUshort self.pos, ushortVal
		self.pos = self.pos + 2
	end function
	BinaryStream.writeUint = function(uintVal)
		self.ensure 4
		self.buffer.setUint self.pos, uintVal
		self.pos = self.pos + 4
	end function
	BinaryStream.writeUtf8 = function(utf8Str)
		// It's hard to know how many bytes to ensure.  But most UTF-8
		// characters require 3 bytes or less, so this is probably safe:
		self.ensure utf8Str.len*3
		bytesUsed = self.buffer.setUtf8(self.pos, utf8Str)
		self.pos = self.pos + bytesUsed
		return bytesUsed
	end function
	BinaryStream.writeLenPrefixedString = function(s)
		if s.len > 255 then s = s[:255]
		self.ensure s.len*3 + 1
		bytesUsed = self.buffer.setUtf8(self.pos + 1, s)
		self.buffer.setByte(self.pos, bytesUsed)
		self.pos = self.pos + bytesUsed + 1
	end function
	
	// Gather statistics we will need later.
	lowCharCount = 0
	highCharCount = 0
	for c in self.chars.indexes
		// Skip YAFF tags (charCode=0) - BMF doesn't support tags
		if self.chars[c].charCode == 0 then continue
		if c.code < 256 then lowCharCount = lowCharCount + 1 else highCharCount = highCharCount + 1
	end for
	if not self.hasIndex("usedColors") then self.usedColors = self.palette.len
	if not self.hasIndex("highestUsedColor") then self.highestUsedColor = self.palette.len
	
//	print "Saving version " +self.version + " file with " + highCharCount + " high chars"
	
	paletteMap = {}  // key: color (sans alpha); value: color index + 1
	for i in self.palette.indexes
		paletteMap[self.palette[i]] = i + 1
	end for
	
	// Now we can use that to write out our BMF data.
	data = new BinaryStream
	data.littleEndian = true
	
	// magic header
	data.writeUint 450225889
	
	// version
	if self.version <= 1.1 then
		data.writeByte 17  // 0x11
	else
		data.writeByte 18  // 0x12
	end if
	
	// various font attributes
	data.writeByte self.lineHeight
	data.writeSbyte self.sizeOver
	data.writeSbyte self.sizeUnder
	data.writeSbyte self.addSpace
	data.writeSbyte self.sizeInner
	data.writeByte self.usedColors
	data.writeByte self.highestUsedColor
	if self.version > 1.1 then
		data.writeByte self.alphaBits
		data.writeByte self.numPalettes - 1
	else
		data.pos = data.pos + 2
	end if
	data.pos = data.pos + 2
	data.writeByte self.palette.len
	for p in self.palette
		pl = color.toList(p)
		data.writeByte pl[0]/4		// red (0-63)
		data.writeByte pl[1]/4		// green
		data.writeByte pl[2]/4		// blue
	end for
	data.writeLenPrefixedString(self.title)
	print "Writing " + lowCharCount + " low chars"
	data.writeUshort lowCharCount
	
	// write out the low characters (Unicode < 256) first
	for c in self.chars.indexes
		// Skip YAFF tags (charCode=0)
		if self.chars[c].charCode == 0 then continue
		if c.code > 255 then continue
		p0 = data.pos
		data.writeByte c.code
		self.chars[c].save data, paletteMap, self.alphaBits
		//print "Wrote " + c.code + " (" + c + ") with " + (data.pos-p0) + " bytes at " + p0
	end for
	
	if self.version > 1.1 then
		// write the high characters (Unicode > 255) next
		data.writeUint highCharCount
		for c in self.chars.indexes
			// Skip YAFF tags (charCode=0)
			if self.chars[c].charCode == 0 then continue
			if c.code < 256 then continue
			data.writeUint c.code
			self.chars[c].save data, paletteMap, self.alphaBits
		end for
		
		// write the kern map
		kernCount = 0
		if self.kernMap then
			for submap in self.kernMap.values
				kernCount = kernCount + submap.len
			end for
			data.writeUshort kernCount
			print "Writing " + kernCount + " kern entries"
			for k1 in self.kernMap.keys
				k1Map = self.kernMap[k1]
				for k2 in k1Map.keys
					data.writeUint k1.code
					data.writeUint k2.code
					data.writeShort k1Map[k2]
				end for
			end for
		else
			data.writeUshort kernCount
		end if
	end if
	
	// Finally, write this to a file.
	print "Saving " + data.pos + " bytes of data to " + path
	data.buffer.resize data.pos
	err = file.saveRaw(path, data.buffer)
	return err
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

// Add a new character to this font.  Parameters are as follows:
//	c: character (string) to add
//	image: image of the character glyph
//	relX, relY: where to draw this image relative to the baseline cursor
//  shift: how much to move the baseline cursor after drawing;
//		if null, this defaults to image.width
Font.addChar = function(c, image, relX=0, relY=0, shift=null)
	if shift == null then shift = image.width
	cd = new CharData
	cd.charCode = c.code
	cd.image = image
	cd.width = image.width; cd.height = image.height
	cd.relX = relX; cd.relY = relY
	cd.shift = shift
	self.chars[c] = cd
end function

// Render the given character into any drawing context 'g'
// which has setPixel method.  This includes both Image
// and PixelDisplay.  Note that for character 'c' you can
// either pass in a string (the character), or a CharData object.
// (Most users will use print or printChar, below.)
Font.renderChar = function(c, g, destX=0, destY=0)
	if c isa string then d = self.charData(c) else d = c
	if d == null then return null
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
				if self.alphaBits == 8 then
					a = floor(c / clrRange) * alphaScale
					pixelColor = baseColor + hex2(a)
				else if self.alphaBits > 0 then
					// ToDo: handle this case.
					// Seems like we should be looking in self.palette
					// with the remaining bits of c, rather than using
					// baseColor.				
				else
					pixelColor = self.palette[c-1]
				end if
				g.setPixel destX + bitmapX, destY + bitmapY, pixelColor
			end for
		end for		
	end if
end function

// Make and return an Image of the given character.
Font.makeCharImage = function(c)
	d = self.charData(c)
	if d == null then return null
	img = Image.create(d.width, d.height, color.clear)
	self.renderChar d, img
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

// Render (draw) the given character to gfx, and return how
// far to shift the cursor.  This uses the image cache, so
// it gets faster after the first drawing of each character.
Font.printChar = function(c, x=480, y=320, scale=1, tint="#FFFFFF")
	d = self.charData(str(c))
	if d == null then return 0
	if not d.hasIndex("image") or d.image == null then
		if d.width > 0 then d.image = self.makeCharImage(c)
	end if
	x = x + d.relX
	if d.hasIndex("image") and d.image != null then
		if scale == 1 then
			y = y - self.sizeOver - d.relY - d.image.height
			gfx.drawImage d.image, x, y, d.image.width, d.image.height,
			  0, 0, d.image.width, d.image.height, tint
		else
			y = y + scale * (-self.sizeOver - d.relY - d.image.height)
			gfx.drawImage d.image, x, y, d.image.width*scale, d.image.height*scale,
			  0, 0, d.image.width, d.image.height, tint
		end if
	end if
	return d.shift * scale
end function

// Print the given string to gfx at the given location.
Font.print = function(s, x=20, y=320, scale=1, tint="#FFFFFF")
	s = str(s)
	lastc = ""
	for c in s
		x = x + self.kern(lastc, c) * scale
		x = x + self.printChar(c, x, y, scale, tint) + self.addSpace * scale
		lastc = c
	end for
end function

// Print the given string to gfx, centered horizontally on the given x.
Font.printCentered = function(s, x=480, y=320, scale=1, tint="#FFFFFF")
	s = str(s)
	self.print s, x - self.width(s, scale)/2, y, scale, tint
end function

// Print the given string to gfx, right-aligned on x.
Font.printRight = function(s, x=940, y=320, scale=1, tint="#FFFFFF")
	s = str(s)
	self.print s, x - self.width(s, scale), y, scale, tint
end function

// Print the given string to gfx, fully justified within the given width,
// by inserting a little extra space between the words.
Font.printJustified = function(s, x, y, width=500, scale=1, tint="#FFFFFF")
    words = s.split
    w = 0
    for word in words; w += self.width(word, scale); end for
    ew = width - w // ("extra width")
    ewPerWord = floor(ew/(words.len-1))
    for i in words.indexes
        self.print words[i], x, y, scale, tint
        if i == words.len-2 then ewPerWord = ew
        x += self.width(words[i], scale) + ewPerWord
        ew -= ewPerWord
    end for
end function

// Return the width of the given string in this font.
Font.width = function(s, scale=1)
	s = str(s)
	sum = 0
	lastc = ""
	for c in s
		d = self.charData(c)
		if d == null then continue
		sum = sum + (d.shift + self.addSpace + self.kern(lastc, c)) * scale
		lastc = c
	end for
	return sum
end function

// Return the number of characters of the given string that
// fit a given width.
Font.lenToFit = function(s, width=100)
	if not s or not (s isa string) then return 0
	if self.width(s) <= width then return s.len
	lo = 1
	hi = s.len
	while lo + 1 < hi
		mid = floor((lo + hi) / 2)
		if self.width(s[:mid]) <= width then
			lo = mid
		else
			hi = mid
		end if
	end while
	return lo
end function

boxesSample = [
"┌─┬┐  ╔═╦╗  ╓─╥╖  ╒═╤╕",
"│ ││  ║ ║║  ║ ║║  │ ││",
"├─┼┤  ╠═╬╣  ╟─╫╢  ╞═╪╡",
"└─┴┘  ╚═╩╝  ╙─╨╜  ╘═╧╛",
"┌───────────────────┐",
"│  ╔═══╗ Some Text  │▒",
"│  ╚═╦═╝ in the box │▒",
"╞═╤══╩══╤═══════════╡▒",
"│ ├──┬──┤           │▒",
"│ └──┴──┘           │▒",
"└───────────────────┘▒",
" ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒",
]

runUnitTests = function
	check = function(actual, expected)
		if actual == expected then return
		print "Unit test failure."
		print "Expected: " + expected
		print "  Actual: " + actual
		exit
	end function

	check expandList("'$', null, U+2611, '""', ',', '-', 39"),
	  [36, null, 9745, 34, 44, 45, 39]
	check expandList("1,3-5,null*2,12,'A'-'C'"),
	  [1, 3, 4, 5, null, null, 12, 65, 66, 67]
	check expandList("U+2191 - u+2194"),
	  [8593, 8594, 8595, 8596]
end function

// Demo program: find the fonts directory, then load and display
// every font found therein.
demo = function
	clear; text.row = 10
	
	fontsFolder = "fonts"
	if not file.exists(fontsFolder) then fontsFolder = "/usr/fonts"
	if not file.exists(fontsFolder) then fontsFolder = "/sys/fonts"
	if not file.exists(fontsFolder) then
		print "Unable to locate fonts folder."
		return
	end if
	
	scrollGfx = function(dy=1)
		gfx.drawImage gfx.getImage(0, 0, 960, 640-dy), 0, dy
		gfx.fillRect 0, 0, 960, dy, color.black
	end function

	y = 640
	fontFiles = file.children(fontsFolder)
	fontFiles.sort
	for fontFile in fontFiles
		path = file.child(fontsFolder, fontFile)
		f = null
		if fontFile == "AppleII_24x24.png" then
			f = Font.loadImageGrid(path, 24, 24, "0-127", 2)
			f.addSpace = -2  // push cells 2 pixels closer together for this font
			globals.a2f = f
		else if fontFile[-4:] == ".bmf" or fontFile[-5:] == ".yaff" then
			f = Font.load(path)
		end if
		if f == null then continue
		if y - f.lineHeight < 0 then
			dy = f.lineHeight + 4
			scrollGfx dy
			y += dy
		end if
		s = fontFile + ": " + f.title
		w = f.width(s)
		baseY = y + f.sizeOver
		gfx.line 10, baseY, 10+w, baseY, "#FF00FF"
		f.print s, 10, baseY
		y -= f.lineHeight + 4
	end for
	scrollGfx 24
	text.row = 0
	
	boxes = []
	for c in range(9472, 9727)
		boxes.push char(c)
	end for
	
	for fontFile in ["fonts/minimicro-mono-boxes-12.bmf", "fonts/minimicro-mono-boxes-16.bmf", "fonts/minimicro-mono-boxes-20.bmf"]
		fnt = Font.load(fontFile)
		if fnt == null then continue
		input "[Press Return]"
		clear
		print fontFile
		charsPerLine = floor(960 / fnt.chars.A.width / 2)
		y = 550
		for i in range(0, boxes.len, charsPerLine)
			line = boxes[i : i + charsPerLine].join(" ")
			y -= (fnt.chars.A.height + 10)
			fnt.print line, 0, y, 1, color.rgb(rnd*250, rnd*250, rnd*250)
		end for
		y -= 50
		clr = color.rgb(100+rnd*150, 100+rnd*150, 100+rnd*250)
		for i in boxesSample.indexes
			fnt.print boxesSample[i], 100, y - i * fnt.chars.A.height, 1, clr
		end for
	end for
end function

if locals == globals then
	runUnitTests
	demo
end if
