
# ZDP 📦

ZDP is a lightweight Zig library to serialize structured scientific data (slices/arrays) into `.txt` or `.bin` files, designed to be easily read from Python using `readDATA_bin.py`. Perfect for simulations, numerical models, and exporting multi-dimensional arrays.

---

## ✨ Features

- Serialize Zig `struct`s containing `[]`, `[][]`, `[][][]`, or fixed-size arrays.
- Output formats: `.txt` (human-readable) and `.bin` .
- Automatically stores:
  - Field names
  - Dimensionality & shape
  - Element size
  - Flattened data

---

## 🛠️ Build & Run

```bash
zig build-exe src/multiple-slice-entries.zig
./multiple-slice-entries
```

---

## 🗂 File Format

### Header

```
DATA.*01
```

### For Each Field

```
[field_name_len: usize]
[field_name: []u8]
[dim: usize]
[shape_len: usize]
[shape: [shape_len]usize]
[element_size: usize]
[values: flat data]
```

---

## 🧪 Zig Usage

```zig
const DataWriter = @import("root.zig").DataWriter;

const MyStruct = struct {
    x: []f64,
    y: []f64,
    z: []f64,
    allocator: std.mem.Allocator,
};

var data = try MyStruct.init(allocator, 1000);
defer data.deinit();
data.fillLorenz(0.001);

const Writer = DataWriter(MyStruct);
var writer = Writer.init(&data, allocator);
try writer.write("out/MSE", .binary);
```

Full example in `src/multiple-slice-entries.zig`.

---

## 🐍 Python Reader

```python
from readDATA_bin import loadData

fields = loadData("out/MSE.bin")
x = fields[0].values
y = fields[1].values
z = fields[2].values
```

---

## ✅ Supported Types

- `[]T`, `[][]T`, `[][][]T`, etc.
- Fixed-size arrays: `[N]T`, `[N][M]T`, etc.
- Base types: `f64`, `i32`, etc.

🚫 Unsupported (for now):

- Nested structs
- Optionals
- Array and Slice Pointers

---

## 🧠 Design Highlights

- Clean separation of metadata and data
- Auto-recursive shape detection
- Flattened slices for efficient I/O
- Little-endian binary format

---

## 🤝 Contributions Welcome

- Struct-in-struct support
- Optional field handling
- Smarter flattening for more types
