# minimicro-fonts
Bytemap screen font support for Mini Micro


## Purpose

This repo provides code to read and render bitmap fonts in the "ByteMap Font" (BMF) format, as described here: https://bmf.php5.cz/?page=format

It also includes some sample font files that I believe to be in the public domain.  You can find thousands more at the web site above.

## Usage

Use this code with [Mini Micro](https://miniscript.org/MiniMicro).  Mini Micro is a fun, free, retro-style virtual computer based on [MiniScript](https://miniscript.org/), which is itself a clean, simple, modern scripting language.

Load up `fontTest.ms` to see the code in action.  Sample usage:

```
// Load a font
f = Font.load("fonts/ming.bmf")

// Print a string in that font to gfx
f.print "Hello world!", 20, 500

// Get a character image, and make a Sprite out of it
spr = new Sprite
spr.image = f.getCharImage("R")
spr.x = 400
spr.y = 500
spr.scale = 3
spr.rotation = 30
display(4).sprites.push spr
```

## Limitations

This code supports version 1.1 of the BMF format, which has the following limitations:

1. It only supports characters up to char(255), and even within that range, the meaning of characters above char(127) is ill-defined.  No Unicode support.

2. The colors do not support an alpha channel; every pixel is either opaque or fully transparent.

I'm currently in discussions with the creator of the BMF format to possibly remove these limitations, but for now they still apply.


