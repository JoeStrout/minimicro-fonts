
# MiniScript + Mini Micro Reference (Concise)

> **Drop-in reference** for prompts about MiniScript or Mini Micro. Curated from the MiniScript Manual, Mini Micro Cheat Sheet, and community idioms. Updated with important gotchas (incl. `range` behavior).

---

## 0) High‑priority gotchas

- **Default parameter values must be simple literals.** Do not use a list/map literal as a default. Use `null` and initialize inside.
  ```miniscript
  f = function(a = null)
    if a == null then a = {}
    // ...
  end function
  ```
- **Keywords are reserved**—they cannot be used as identifiers or method names (e.g., `new`, `function`, `if`, `end`, `for`, etc.). Prefer `create`, `make`, `spawn`, `ctor`, etc.
- **No ternary operator (`?:`).** Use short-form `if` or boolean-multiply/string tricks.
  ```miniscript
  if x>=0 then sign="+" else sign="-"
  label = "neg" * (x<0) + "pos" * (x>=0)
  ```
- **Passing functions:** assign to a variable, pass the **reference** with `@` (address-of). Or bundle a function + data into a map.
  ```miniscript
  triple = function(n=1); return n*3; end function
  apply = function(lst, f)
    r = lst[:]
    for i in indexes(r); r[i] = f(r[i]); end for
    return r
  end function
  print apply([1,2,3], @triple)
  ```
- **Functions are declared by assignment; no inline/lambda literal syntax.** Define a named function, then pass `@name` where needed.
- **Mini Micro display layers:**
  - `display(5)` is a **pixel** layer; `gfx` points to `display(5)` by default.
  - **Layer 3** is the **text** layer used for interpreter output/errors. Avoid replacing it or you’ll hide errors.
- **`range` is inclusive when reachable:** `range(from, to, step)` includes `from` and **includes `to` if the step lands on it** (default step is `1` or `-1`). This is a common off‑by‑one gotcha for Python users.
  ```miniscript
  range(0,5)      // [0,1,2,3,4,5]
  range(10,1)     // [10,9,8,7,6,5,4,3,2,1]
  range(0,5,2)    // [0,2,4]  (5 not hit)
  range(2,2)      // [2]
  ```

---

## 1) Syntax & basics
- One statement per line (semicolon `;` only to combine multiple on one line).
- Blocks: `if/else/while/for/function` … `end if/while/for/function`.
- Comments: `//` to end of line.
- Parentheses only for grouping, call arguments (when call is not the whole statement), and parameter lists. No parens around `if`/`while` conditions.
- Case-sensitive. Avoid leading `_` in globals (host may use).

## 2) Variables & scope
- Assignment creates variables. **Local by default** inside functions; globals exist at top level.
- If a local shadows a global, access the global via `globals.name`. Math‑assignment supported: `+= -= *= /= %= ^=`.
- `true` and `false` are `1` and `0`. In boolean contexts: empty string/list/map → false; nonempty → true; `null` → false.

## 3) Data types & operators
- Types: **number, string, list, map**, plus `function` and `null`. `isa` checks type: `x isa list`.
- Operators (highlights): `+ - * / % ^`, comparisons `== != > >= < <=`, logical `and or not`, unary `-`, `new`, `@f`, indexing/slicing `a[i]`, `a[i:j]`, call `f(...)`, dot `a.b`.

## 4) Control flow
- `if / else if / else / end if` and **short‑form**: `if cond then stmt` or `if cond then s1 else s2`.
- `for i in list ... end for` (lists, strings, maps). Iterating a **map** yields small maps: `kv.key`, `kv.value`.
- `while cond ... end while`; `break`, `continue` supported.
- **Ranges:** `range(from, to, step?)` defaults step to `1` if `to>from`, else `-1`. Sequence includes `to` if step reaches it.

## 5) Strings, lists, maps
### Strings
- Literals use `"..."`; double the quote to escape: `"He said ""Hi"""`.
- Operators: `+` concat, `-` chop suffix, `*` replicate, `/` shrink, slicing `s[i]`, `s[:n]`, `s[n:]`, `s[n:m]`.
- Methods: `.len .lower .upper .indexOf(s,after?) .replace(old,new,max?) .remove(s) .split(delim,max?) .values .code .val`.
- **Immutable** (assign new strings; cannot assign `s[i] = ...`).

### Lists
- Literals `[1,2,3]`; slicing like strings; negative indexes allowed. **Mutable**.
- Copy idiom: `b = a[:]` to avoid aliasing.
- Methods: `.len .push .pop .pull .remove(i) .insert(i,x) .sort(key?) .shuffle .sum .indexOf(x,after?) .indexes .hasIndex(i) .join(delim)`.

### Maps
- Literals `{key:value,...}`. Access `m["k"]` or dot `m.k` (identifier-like keys only). Order unspecified.
- Iteration: `for kv in m ... kv.key ... kv.value ... end for`.
- Methods: `.len .values .indexes .hasIndex(k) .indexOf(v) .remove(k) .replace(...) .push(k) .pop .shuffle .sum`.

## 6) Functions & OOP
### Functions
- Define with `function(params)` … `end function`; assign to a name; invoke via that name. Use `return`.
- **Pass by reference** with `@name`; otherwise using a function name as a value will invoke it.
- Nested functions allowed; inner can read outer locals; to **assign** outer variable use `outer.var`.

### Prototype‑based OOP
- Classes/objects are maps; `new Base` creates a map with `__isa=Base`.
- Dot‑invoked functions receive `self` (the object map). Use `super.method` to call base implementation while keeping `self`.
- Extend built‑in types by adding methods to `string`, `list`, `map`, `number` maps (note: you can’t use dot on numeric **literals** like `42.method`).

## 7) Intrinsics (selected)
- **Numeric:** `abs acos asin atan ceil floor log(base=10) round rnd(seed?) sign sin cos tan sqrt str char pi`
- **Sequence:** `range(from,to,step?)`, `.indexes` on strings/lists/maps.
- **System:** `print(x,delim?) time wait(sec=1) yield globals locals intrinsics refEquals(a,b) stackTrace`

## 8) Mini Micro runtime
### Displays (8 layers; 0 = front, 7 = back)
- Modes: `displayMode.off | solidColor | text | pixel | tile | sprite` via `display(n).mode = ...`.
- **Text display** (68×26); global `text` is used by `print`/`input`. Key props/methods: `.color .backColor .row .column .inverse .delimiter .clear .cell(x,y) .setCell ... .cellColor/.setCellColor .cellBackColor/.setCellBackColor .print(s)`.
  - Default `text.delimiter` is `char(13)` (newline). Set to `""` to suppress.
- **Pixel display** (960×640); global `gfx` references default pixel layer (by default `display(5)`).
  - Props: `.color .width .height .scrollX .scrollY .scale`
  - Methods: `.clear([clr,w,h]) .pixel(x,y) .setPixel ... .line .drawRect/.fillRect .drawEllipse/.fillEllipse .drawPoly/.fillPoly .drawImage .getImage .print(str,x,y,color,font="normal")`
- **Tile display:** `.clear([toIndex]) .extent [cols,rows] .tileSet .tileSetTileSize .cellSize .overlap .oddRowOffset/.oddColOffset (hex) .scrollX/.scrollY .cell/.setCell .cellTint/.setCellTint`.
- **Sprite display:** `display(n).sprites` list; `Sprite` has `.image .x .y .scale .rotation .tint .localBounds .worldBounds .contains(pt) .overlaps(other)`.

### Input
- `input(prompt)`; `key.available/get/clear/pressed(name) key.axis(name)`; `mouse.x/y`, `mouse.button(which=0)`, `mouse.visible`.

### Files & paths
- Prompt commands: `pwd cd dir mkdir delete view` (quote paths!).
- `file` module: `.curdir .setdir .makedir .children .name .parent .exists .info .child .delete .move .copy .readLines .writeLines .loadImage .saveImage .loadSound .export .import .open` (file handle: `.isOpen .position .atEnd .write .writeLine .read .readLine .close`).

### Sound
- `Sound` class: set `.duration .freq (or list) .envelope (or list) .waveform (sine/triangle/sawtooth/square/noise) .fadeIn .fadeOut .loop`.
- Methods: `.init(dur,freq,env,wave) .mix(s2,lvl) .play(vol, pan, speed) .stop .isPlaying`; `Sound.stopAll()`. `noteFreq(n)` (60 = middle C).

### HTTP
- `http.get(url, headers?)`, `.post(url,data,headers?)`, `.put(...)`, `.delete(...)`.

### Import modules
- `import "name"` (typically loads from `/sys/lib`). Common helpers: `importUtil.ensureImport`, `qa.assert`, `listUtil.map/filter/reduce/...`, `tileUtil`, `pathUtil.findPath`, `spriteControllers` (wander/bounce/keyboardControl/follow/etc.).

## 9) Common idioms
- **Main loop:**
  ```miniscript
  while not key.pressed("escape")
    updateGame
    yield
  end while
  ```
- **Map iteration:**
  ```miniscript
  for kv in person
    print kv.key + ": " + kv.value
  end for
  ```
- **Click handler pattern:**
  ```miniscript
  onBtn = function; print "clicked"; end function
  btn.onClick = @onBtn
  ```
- **Text-to-pixel conversion (if needed):** use `gfx.print` for pixel text; keep `text` for console/status to avoid losing error output.

## 10) Quick recipes
```miniscript
// Safe optional map arg
defaultMapArg = function(m=null); if m==null then m={} end if; return m; end function

// Clamp
clamp = function(x, lo, hi); if x<lo then return lo else if x>hi then return hi else return x end if end function

// Join list to CSV
asCsv = function(xs); return xs.join(","); end function

// Capitalize first letter of a string
string.capitalized = function; if self.len<2 then return self.upper; return self[0].upper + self[1:]; end function

// Shallow copy of a map
copyMap = function(m); n={}; for kv in m; n[kv.key]=kv.value; end for; return n; end function
```

---

**Note on `range`:** MiniScript includes the `to` value when it is exactly reachable by the step (default `±1`), e.g., `range(0,5)->[0..5]` and `range(10,1)->[10..1]`. If the step doesn’t land on `to` (e.g., `range(0,5,2)`), the last element is the largest value **before** passing `to`.

