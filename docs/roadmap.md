# Chai Language Roadmap

## >> v0.1

This compiler iteration should offer support for essential language constructs,
such as

- Integer, float, string, and character literals
- Untyped pointers
- Stack, arithmetic, bitwise, and boolean logic operators
- Procedures, conditional operations, and loops
- Basic type-checking
    Type safety should be guarenteed, with the exception of pointers which
    should remain untyped until `v0.3`

- Global variables and constants
- Static memory allocation

## v0.2

This compiler iteration should offer support for more advanced language
constructs, such as

- Typed pointers
- Structures
- Local variables and constants
- Deferring expressions
- Importing external modules

## v0.3

This compiler iteration should come with a basic standard library offering
idiomatic support for only essential operations, such as

- Access to command-line arguments
- Date and time operations
- Type conversions
- Unmanaged memory allocation

TODO: This list is incomplete, and should be expanded in the future

## v0.4

This compiler iteration should offer support for dynamic memory allocation and
automatic memory management through reference counting. This may require
rewritting significant parts of the standard library to use dynamic memory
allocation as opposed to static memory allocation.

## v0.5

This compiler iteration should offer many user-experience improvements, as well
as other compilation improvements, such as

- Improved error messages ans sugguestions
- Type-checking only mode
- Project templates
- Optimization level specification
- Incremental compilation
