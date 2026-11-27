# note stack

A simple stack of notes todo app inspired by [Ratfactor's note stack](https://ratfactor.com/stack/).

Mostly because I wanted to write something in assembly. The note-store saved in `note.bin` uses a very simple binary format.
None of the notes are ever deleted. Once done, it just peels the sticky note from the top and shows you the next.

## Getting Started

### Build

If you prefer using GNU make:

```
make
```

Otherwise:

```
as -o main.o main.s
ld main.o -o notestack
```

### Usage

### Adding a Note

```sh
./notestack add 'your current priority'
```

### Peeking at the Priority Note

```
./notestack peek
```

### Marking the Priority as Done

```
./notestack done
```
