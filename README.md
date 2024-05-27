# Term

A low level library for pure [Zig](https://github.com/ziglang/zig) terminal interactions. The goal of the library isn't to output formatted text, but instead to write to the terminal, and read from the terminal.

### Features

- Terminal context that manages buffered stdin, stdout, and stderr
- Reading stdin
- Writing to either stdout or stderr
- Raw terminal mode: great for tui applications
