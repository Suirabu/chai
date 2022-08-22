# Chai

Chai is a low-level stack-oriented programming language.

## Dependencies

Chai currently only targets x86_64-based Linux systems.

The following programs are required to build an executable using the compiler:

- [YASM assembler](https://yasm.tortall.net/)
- ld GNU linker

## Build Instructions

To build the Chai compiler, you will first need to have a copy of the
[Zig compiler](https://ziglang.org/) installed on your computer.

Build and run the compiler with the following command:

```
$ zig build run -- [ args ]
```

## Language Reference

Read the [official language overview](docs/chai-overview.md).

## License

This project is licensed under the permissive MIT license, which can be seen
[here](LICENSE).
