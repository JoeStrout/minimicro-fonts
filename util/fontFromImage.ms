// Utility to create a BMF Font by carving up a grid-based image
// of the font glyphs.
// 
// Limitations:
//	- No alpha blending (just simple transparency)
//	- Resulting font is always monospaced
//	- Each glyph is saved as a same-sized rectangular image, even if it is mostly
//	  or entirely empty -- BMF supports more compaction (trimming unused space)
//	  than this tool provides.

import "stringUtil"
import "listUtil"
import "bmfFonts"
import "textUtil"
printAt = @textUtil.printAt
printCenteredAt = @textUtil.printCenteredAt
textCol = @textUtil.textCol
textRow = @textUtil.textRow

// Constants
IMAGE_LEFT = 300
IMAGE_TOP = 600
IMAGE_MINY = 150
IMAGE_BGCOLOR = "#555555"
LABEL_COLOR = "#888888"
FIELD_BGCOLOR = "#333388"
FIELD_COLOR = "#AAAAFF"
SELFIELD_COLOR = "#FFFF44"
PROMPT_COLOR = "#8888AA"
BUTTON_COLOR = FIELD_COLOR

// Global variables
image = null
sourcePath = ""
imageScale = 0
imageBottom = IMAGE_MINY
leftMargin = 0
topMargin = 0
cellWidth = 16
cellHeight = 16
fixedRows = null
fixedCols = null
rows = null  // (calculated from other vars)
cols = null
charMap = list.init2d(64, 64, "")  // generous enough for any grid, I hope!
lastRow = -1
lastCol = -1

//----------------------------------------------------------------------
// TextField class

TextField = {}
TextField.onChange = null
TextField.Instances = []
TextField.LastUsed = null

TextField.Make = function(col, row, label, width, value, numeric=true)
	noob = new self
	noob.column = col
	noob.row = row
	noob.label = label
	noob.width = width
	noob.value = value
	noob.numeric = true
	noob.draw
	TextField.Instances.push noob
	return noob
end function

TextField.HandleKey = function(k)
	if k.code == 9 then  // Tab
		dir = 1
		if key.pressed("left shift") or key.pressed("right shift") then dir = -1
		idx = TextField.Instances.indexOf(TextField.LastUsed)
		if idx == null then
			if dir > 0 then idx = 0 else idx = -1
		else
			idx = (idx + TextField.Instances.len + dir) % TextField.Instances.len
		end if
		TextField.Instances[idx].handleClick true
		return true
	end if
	return false
end function		

TextField.draw = function
	text.color = LABEL_COLOR
	text.backColor = color.clear
	printAt self.column - self.label.len - 2, self.row, self.label + ": "
	text.backColor = FIELD_BGCOLOR
	text.color = FIELD_COLOR
	printAt self.column, self.row, str(self.value).pad(self.width)
	text.backColor = color.clear
end function
	
TextField.hitByColRow = function(col, row)
	if row != self.row then return false
	return self.column - self.label.len - 2 <= col <= self.column + self.width
end function

TextField.hitByXYPos = function(xyPos)
	return self.hitByColRow(textCol(xyPos.x), textRow(xyPos.y))
end function	

TextField.handleClick = function(startWithCurrentValue = false)
	TextField.LastUsed = self
	text.backColor = FIELD_BGCOLOR
	text.color = SELFIELD_COLOR
	text.row = self.row; text.column = self.column
	validation = null
	if self.numeric then
		validation = function(c); return "0" <= c <= "9"; end function
	end if
	if startWithCurrentValue then key.put str(self.value)
	self.value = limitedInput(self.width, "", @validation)
	if self.numeric then self.value = val(self.value)
	self.draw
	self.onChange
end function

TextField.HandleClick = function
	for fld in TextField.Instances
		if fld.hitByXYPos(mouse) then
			fld.handleClick
			return true
		end if
	end for
	return false
end function

//----------------------------------------------------------------------
// AutoTextField class -- TextField that shows "(AUTO)" when empty

AutoTextField = new TextField
AutoTextField.Make = function(col, row, label, width, value)
	noob = super.Make(col, row, label, width, value)
	return noob
end function

AutoTextField.draw = function
	if not self.value then
		self.value = "(AUTO)"
		super.draw
		self.value = null
	else
		super.draw
	end if
end function

//----------------------------------------------------------------------
// TextButton class

TextButton = {}
TextButton.onClick = null
TextButton.Instances = []

TextButton.Make = function(col, row, label, width=12)
	noob = new self
	noob.column = col
	noob.row = row
	noob.label = label
	noob.width = width
	noob.draw
	TextButton.Instances.push noob
	return noob
end function

TextButton.draw = function(pressed=false)
	if pressed then
		text.color = color.lerp(BUTTON_COLOR, color.black, 0.25)
	else
		text.color = BUTTON_COLOR
	end if
	text.backColor = color.clear
	padChars = self.width - self.label.len
	caption = (" " * (padChars/2) + self.label).pad(self.width)
	text.row = self.row; text.column = self.column
	textUtil.drawButton caption
end function
	
TextButton.hitByColRow = function(col, row)
	if row != self.row then return false
	return self.column <= col <= self.column + self.width
end function

TextButton.hitByXYPos = function(xyPos)
	return self.hitByColRow(textCol(xyPos.x), textRow(xyPos.y))
end function	

TextButton.handleClick = function
	while mouse.button
		yield
		self.draw self.hitByXYPos(mouse)
	end while
	if self.hitByXYPos(mouse) then self.onClick
	self.draw
end function

TextButton.HandleClick = function
	for fld in TextButton.Instances
		if fld.hitByXYPos(mouse) then
			fld.handleClick
			return true
		end if
	end for
	return false
end function


//----------------------------------------------------------------------
// ImagePanel class -- draws input image with overlaid grid, etc.
// (There's only one of these, so we just use it directly.)

ImagePanel = {}
ImagePanel.left = IMAGE_LEFT
ImagePanel.top = IMAGE_TOP

ImagePanel.draw = function
	outer.imageScale = calcScale
	gfx.clear
	w = image.width * imageScale
	h = image.height * imageScale
	imageBottom = IMAGE_TOP - h
	gfx.fillRect IMAGE_LEFT, imageBottom, w, h, IMAGE_BGCOLOR
	gfx.drawImage image, IMAGE_LEFT, imageBottom, w, h
	
	if fixedRows == null then
		outer.rows = floor((image.height-topMargin) / cellHeight)
	else
		outer.rows = fixedRows
	end if
	if fixedCols == null then
		outer.cols = floor((image.width-leftMargin) / cellWidth)
	else
		outer.cols = fixedCols
	end if
	gfx.color = "#FFFFAA"
	left = self.left + leftMargin*imageScale
	right = left + cellWidth*imageScale*cols
	top = self.top - topMargin*imageScale
	bottom = top - cellHeight * imageScale * rows
	for x in range(0, cols*cellWidth*imageScale, cellWidth * imageScale)
		gfx.line left+x, top, left+x, bottom
	end for
	baseline = baselineField.value
	for y in range(0, rows*cellHeight*imageScale, cellHeight * imageScale)
		gfx.line left, top-y, right, top-y
		if y > 0 and baseline > 0 then
			gfx.line left, top-y + baseline*imageScale, right, 
			  top-y + baseline*imageScale, "#AAAA55"
		end if
	end for
	for row in range(0, rows-1)
		for col in range(0, cols-1)
			if charMap[row][col] then
				y = top - row * cellHeight*imageScale - 13
				x = left + col * cellWidth*imageScale + 2
				gfx.print charMap[row][col], x+1, y-1, "#000000AA", "small"
				gfx.print charMap[row][col], x, y, gfx.color, "small"
			else
				y = top - row * cellHeight*imageScale
				x = left + col * cellWidth*imageScale
				gfx.line x, y, x+cellWidth*imageScale, y-cellHeight*imageScale
				gfx.line x, y-cellHeight*imageScale, x+cellWidth*imageScale, y
			end if
		end for
	end for
end function

ImagePanel.handleClick = function
	cw = cellWidth * imageScale
	ch = cellHeight * imageScale
	left = self.left + leftMargin * imageScale
	right = left + cw * cols
	top = self.top - topMargin * imageScale
	bottom = top - ch * rows
	if not (left <= mouse.x <= right and bottom <= mouse.y <= top) then return false
	col = floor((mouse.x - left) / cw)
	row = floor((top - mouse.y) / ch)
	while true
		gfx2.fillRect left + col * cw, top - (row+1) * ch, cw, ch, "#00FFFFAA"
		gfx2.drawRect left + col * cw, top - (row+1) * ch, cw, ch, "#FFFF00"
		text.color = PROMPT_COLOR
		textUtil.clearRow range(0,5)
		printCenteredAt 34, 5, "Type character for column {col}, row {row}".fill(locals)
		printCenteredAt 34, 4, "(Esc to cancel)"
		while not key.available and not mouse.button
			yield
		end while
		gfx2.clear color.clear
		if mouse.button then break
		k = key.get
		if k.code == 27 then break
		if k.code == 8 or k.code == 127 then k = ""
		charMap[row][col] = k
		globals.lastCol = col
		globals.lastRow = row
		ImagePanel.draw
		col += 1
		if col >= cols then
			col = 0; row += 1
			if row >= rows then row = 0
		end if
	end while
	showInstructions
	return true
end function

//----------------------------------------------------------------------
// Global functions

alert = function(title, msg)
	dlog = textUtil.Dialog.make(title, msg)
	dlog.show
end function

// limitedInput: like regular Input, but limits the input to a certain width
// and optionally to certain characters.
// ToDo: move this into textUtil.
limitedInput = function(width=10, prompt="", charValidationFunc=null)
	print prompt, ""
	col = text.column
	fgc = text.color; bgc = text.backColor
	inp = ""
	pos = 0
	text.column = col; print inp.pad(width), ""
	text.column = col + pos
	cursorOn = false; cursorChangeTime = 0
	done = false
	while not done
		yield
		if time > cursorChangeTime then
			cursorOn = not cursorOn
			r = text.row; c = text.column - (pos == width)
			if cursorOn then
				text.setCellColor c, r, bgc
				text.setCellBackColor c, r, fgc
				cursorChangeTime = time + 0.75
			else
				text.setCellColor c, r, fgc
				text.setCellBackColor c, r, bgc
				cursorChangeTime = time + 0.25
			end if
		end if
		if not key.available then continue
		k = key.get
		if charValidationFunc and not charValidationFunc(k) then continue
		if k >= " " and k.code != 127 and len(inp) < width then
			inp += k
			pos += 1
		else if k.code == 8 and pos > 0 then  // backspace
			inp = inp[:pos-1] + inp[pos:]
			pos -= 1
		else if k.code == 127 and pos < inp.len then  // forward-delete
			inp = inp[:pos] + inp[pos+1:]
		else if k.code == 17 and pos > 0 then  // left-arrow
			pos -= 1
		else if k.code == 18 and pos < inp.len then  // right-arrow
			pos += 1
		else if k.code == 21 then  // cmd-U (cut to beginning)
			inp = inp[pos:]
			pos = 0
		else if k.code == 11 then  // cmd-K (cut to end)
			inp = inp[:pos]
		else if k.code == 1 then   // cmd-A (jump to beginning)
			pos = 0
		else if k.code == 5 then   // cmd-E (jump to end)
			pos = inp.len
		else if k.code == 3 or k.code == 10 or k.code == 13 then // return/enter
			done = true
		else if k.code == 9 then
			done = true
			key.put k
		end if
		text.column = col; print inp.pad(width), ""
		text.column = col + pos
		cursorOn = false; cursorChangeTime = 0
	end while
	return inp
end function


loadImage = function(path)
	image = file.loadImage(path)
	if image == null then
		alert "Image Not Found",
		"Could not load image at: " + char(13) + path
		return
	end if
	outer.image = image
	outer.sourcePath = path
	text.color = LABEL_COLOR
	printCenteredAt 42, 25, path
end function

calcScale = function
	w = image.width
	h = image.height
	availW = 960 - IMAGE_LEFT
	availH = IMAGE_TOP - IMAGE_MINY
	scale = 2
	while w * scale <= availW and h * scale <= availH
		scale += 1
	end while
	return scale - 1
end function

fillCharMap = function
	if lastCol < 0 then
		col = 0; row = 0
		charCode = 32
	else
		col = lastCol; row = lastRow
		charCode = charMap[row][col].code
	end if
	while row < rows
		charMap[row][col] = char(charCode)
		charCode += 1
		col += 1
		if col >= cols then
			col = 0; row += 1
		end if
	end while
	ImagePanel.draw	
end function

showInstructions = function
	textUtil.clearRow range(0, 5)
	text.color = PROMPT_COLOR
	printCenteredAt 34, 5, "Adjust grid parameters using fields above."
	printCenteredAt 34, 4, "Click on grid to assign a character."
	printCenteredAt 34, 2, "Use the Fill button to fill the rest of the grid"
	printCenteredAt 34, 1, "from the last-assigned grid cell."
end function

makeFont = function(forExport = false)
	font = new bmfFonts.Font
	font.version = 1.2
	font.chars = {}
	font.relY = cellHeight
	font.lineHeight = cellHeight
	font.sizeOver = -font.lineHeight
	font.sizeUnder = baselineField.value
	font.addSpace = 1
	font.sizeInner = 0
	font.alphaBits = 0
	font.numPalettes = 0
	for row in range(0, rows-1)
		y = image.height - topMargin - (row+1) * cellHeight
		for col in range(0, cols-1)
			c = charMap[row][col]
			if c == "" then continue
			x = leftMargin + col * cellWidth
			img = image.getImage(x, y, cellWidth, cellHeight)
			cd = new bmfFonts.CharData
			cd.width = img.width
			cd.height = img.height
			cd.relX = 0
			cd.relY = 0
			cd.shift = img.width
			cd.image = img
			font.chars[c] = cd
		end for
	end for
	if forExport then
		font.title = sourcePath.split("/")[-1] - ".png"
		// gather palette
		palette = {}
		for cd in font.chars.values
			img = cd.image
			for y in range(0, img.height-1)
				for x in range(0, img.width-1)
					palette.push img.pixel(x,y)
				end for
			end for
		end for
		font.palette = palette.indexes
		for i in font.palette.indexes
			font.palette[i] = font.palette[i][:7]
		end for
	end if
	return font
end function

showPreview = function
	textUtil.clearRow range(0,5)
	text.color = PROMPT_COLOR
	printAt 2, 5, "Font preview:"
	font = makeFont
	
	y = 80
	s = "The Quick Brown Fox Jumped Over the Lazy Dog."
	gfx.line 50, y, 50 + font.width(s), y, "#FFFF0088"
	font.print s, 50, y
	
	y -= font.lineHeight
	s = "0123456789!@#$%^&*()?"
	gfx.line 50, y, 50 + font.width(s), y, "#FFFF0088"
	font.print s, 50, y
	
	printCenteredAt 34, 0, "(Press any key to continue.)"
	key.get
	ImagePanel.draw
	showInstructions
end function

exportFont = function
	textUtil.clearRow range(0,5)
	text.color = PROMPT_COLOR
	printCenteredAt 34, 4, "Preparing font..."
	font = makeFont(true)
	textUtil.clearRow range(0,5)
	printAt 2, 5, "Export .bmf to path (relative to {curDir}):".fill(file)
	path = input(" >")
	if not path then return
	if not path.endsWith(".bmf") then path += ".bmf"
	err = font.save(path)
	if err then print "Error: " + err else print "Font saved."
	printCenteredAt 34, 0, "(Press any key to continue.)"
	key.get
	showInstructions
end function	

setupUI = function
	outer.leftMarginField = TextField.Make(13, 24, "Left Margin", 6, leftMargin)
	leftMarginField.onChange = function
		globals.leftMargin = leftMarginField.value
		ImagePanel.draw
	end function
	outer.topMarginField  = TextField.Make(13, 22, "Top Margin", 6, topMargin)
	topMarginField.onChange = function
		globals.topMargin = topMarginField.value
		ImagePanel.draw
	end function
	outer.cellWidthField  = TextField.Make(13, 20, "Cell Width", 6, cellWidth)
	cellWidthField.onChange = function
		globals.cellWidth = cellWidthField.value
		ImagePanel.draw
	end function
	outer.cellHeightField = TextField.Make(13, 18, "Cell Height", 6, cellHeight)
	cellHeightField.onChange = function
		globals.cellHeight = cellHeightField.value
		ImagePanel.draw
	end function
	outer.columnsField = AutoTextField.Make(13, 16, "Columns", 6, fixedCols)
	columnsField.onChange = function
		globals.fixedCols = columnsField.value
		ImagePanel.draw
	end function
	outer.rowsField = AutoTextField.Make(13, 14, "Rows", 6, fixedRows)
	rowsField.onChange = function
		globals.fixedRows = rowsField.value
		ImagePanel.draw
	end function
	outer.baselineField = TextField.Make(13, 12, "Baseline", 6, 0)
	baselineField.onChange = function
		ImagePanel.draw
	end function

	outer.loadButton = TextButton.Make(1, 10, "Load", 7)
	loadButton.onClick = function
		dlog = textUtil.FileDialog.make("Select .png file of font glyphs")
		hit = dlog.show
		if hit == dlog.okBtn then loadImage dlog.selection
	end function

	outer.fillButton = TextButton.Make(11, 10, "Fill→", 7)
	fillButton.onClick = @fillCharMap

	outer.previewButton = TextButton.Make(1, 8, "Preview", 7)
	previewButton.onClick = @showPreview

	outer.exportButton = TextButton.Make(11, 8, "Export", 7)
	exportButton.onClick = @exportFont

	showInstructions
end function

// Main Program
clear
display(4).mode = displayMode.pixel
gfx2 = display(4)
gfx2.clear color.clear
//loadImage "/usr2/sonic_asalga.png"
//loadImage "/usr2/JROB774 Font 18x32.png"
loadImage "/usr2/gnsh-bitmap-5x12.png"
setupUI
ImagePanel.draw

while true
	yield
	if mouse.button then
		if TextButton.HandleClick then continue
		while mouse.button; yield; end while
		TextField.HandleClick
		ImagePanel.handleClick
	end if
	if key.available then
		k = key.get
		if k == char(27) then break
		TextField.HandleKey k
	end if
end while

text.color = color.orange
text.row = 0
