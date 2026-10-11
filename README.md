# png-pure

A **pure Common Lisp PNG encoder**. No FFI, no libpng. The inverse of
[pigment](../pigment)'s PNG decoder.

It takes an interleaved 8-bit octet vector and writes a PNG. The DEFLATE/zlib
stream, CRC-32 and Adler-32 come from [cram](../cram).

## API

```lisp
(asdf:load-system :png-pure)

;; PIXELS: (unsigned-byte 8) vector of WIDTH*HEIGHT*CHANNELS bytes, top row first.
(png-pure:encode-png pixels width height :channels 3)    ; -> octet vector
(png-pure:write-png-file pixels width height "out.png" :channels 4) ; -> "out.png"
```

| `:channels` | colour type |
| ----------- | ----------- |
| 1 | greyscale (0) |
| 2 | grey + alpha (4) |
| 3 | RGB (2) — the default |
| 4 | RGBA (6) |

Bit depth is always 8. Every scanline uses filter type 0 (None).

## Tests

```
sbcl --script png-pure/t/roundtrip.lisp
```

Encodes 8 images across all four channel counts, including 1x1, 1x300, 300x1 and
640x360, and decodes each with `pigment:decode-image-bytes`. It passes only if the
decoded RGBA matches exactly. Exit code 0 means pass.

The test also writes sample PNGs to `t/out-*.png`. These are generated output and are
gitignored. An independent check with Python's `zlib` confirmed the chunk CRCs, the
zlib stream, and the scanline layout on those files.

## Status

| Piece | State |
| ----- | ----- |
| Encode: greyscale, grey+alpha, RGB, RGBA, 8-bit | done, round-trip verified |
| Compression | cram's `zlib-compress` (fixed-Huffman LZ77) |
| Interlacing, palette (colour type 3), 16-bit | not implemented |
| Filters other than None | not implemented (output is valid, just not smaller) |
