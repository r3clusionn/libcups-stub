# libcups-stub

A stand-in `libcups.so.2` that lets a prebuilt CEF (Chromium Embedded Framework) run on a system without CUPS. The prebuilt `libcef.so` links against 68 CUPS functions for printing, so it won't load without the library, even in programs that never print. This one file of C defines all 68 to report "no printers" or fail cleanly, which is what Chromium sees on a machine with no print server. It's 21.6 kB, where installing CUPS on the target laptop would build 37 packages, including the gnutls chain removed from it earlier.

**Status:** in use by media-player and mclaunch (both CEF 154) on the target laptop. Built by their build scripts, which check it against `libcef.so` on every build.

![Terminal output on a dark background: "make && make check LIBCEF=cef/Release/libcef.so" prints "libcups stub: all 68 functions present"; "ls -l" shows libcups.so.2 at 21592 bytes and libcef.so at 1455021248 bytes; "ldd libcef.so | grep cups" without the stub prints "libcups.so.2 => not found"](docs/images/check.png)

## Features

- **All 68 CUPS functions** that CEF 154 (Chromium 154.0.8037.98) imports, so the dynamic loader is satisfied.
- **Safe results:** no destinations, and NULL where NULL means "not found". It returns `""` where Chromium copies a string into a `std::string` (a NULL there would crash), and error codes where Chromium checks for them (`IPP_STATUS_ERROR_INTERNAL`, `PPD_FILE_OPEN_ERROR`).
- **`check-symbols.sh`** compares what `libcef.so` imports with what the stub exports and lists anything missing. After a CEF update it shows exactly what to add.

## How to install

Requires a C compiler, make, and binutils (`nm`).

```sh
git clone https://github.com/r3clusionn/libcups-stub
cd libcups-stub
make                                         # builds libcups.so.2
make check LIBCEF=/path/to/cef/Release/libcef.so
cp libcups.so.2 /path/to/your/app/           # next to libcef.so
```

## How to use

Put `libcups.so.2` in a directory the loader searches for your CEF program: next to `libcef.so` with an `$ORIGIN` rpath (as CEF's own samples link), or in `LD_LIBRARY_PATH`. Nothing else changes. Printing reports no printers, and print preview shows none.

If `make check` fails after a CEF update, it prints the missing functions. Add each with the macro matching its return type (`RET_NULL`, `RET_ZERO`, `RET_VOID`, `RET_EMPTY`), or a small function when an output argument must be set.

## How it works

- **Linking without prototypes:** the loader resolves symbols by name only, and on x86-64 a function that ignores its arguments works whatever arguments it's called with. So most entries are one-line macros: `void *name(void) { return NULL; }`. Only functions with output parameters that Chromium reads afterwards are written out: `cupsGetDests2` sets its list to NULL, and `ppdLastError` sets the line number.
- **What Chromium does with it:**
  - its printer enumeration (`cupsEnumDests`) returns "finished, nothing found";
  - connections (`httpConnect2`) return NULL, which Chromium treats as "no print server";
  - error strings are empty.
- **The soname** is `libcups.so.2`, matching what `libcef.so` asks for in its `DT_NEEDED` entries.

## Measurements

| | Size | Packages on the target |
|---|---|---|
| libcups-stub | 21.6 kB, one file | 0 |
| net-print/cups 2.4.19 | — | 37 to build (gnutls, libtasn1, libgcrypt, nettle, xdg-utils, w3m, docbook tooling, autotools…) |

## Verification

- `check-symbols.sh` passes against CEF 154.0.34 (`all 68 functions present`).
- media-player and mclaunch start, load pages and run through their test scripts with it. Neither has crashed in a CUPS function.
- Without it, `ldd libcef.so` reports `libcups.so.2 => not found` and the programs don't start.

## Limits

- Printing doesn't work: there are never any printers.
- Written for x86-64 and CEF 154. Another CEF version may import other functions; `make check` says which.
- Relies on calling conventions where extra arguments are harmless (true on x86-64 and arm64 Linux).

## License

MIT (see `LICENSE`).
