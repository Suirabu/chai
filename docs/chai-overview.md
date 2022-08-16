# Chai Programming Language Overview

## Semantics

The core of all Chai programs is the value stack, which we'll continue to call
"the stack" from here on out. The stack is a FIFO data structure which supports
two operations--pushing, and popping.

Pushing places a new value on top of the stack, whereas popping takes the value
on top of the stack--if any--returning it for use.

In Chai values can be pushed to the stack by using value literals in source
code. When literals are encountered, their values are pushed to the top of
the stack. Instructions in Chai are executed from top to bottom beginning
from the `main` procedure.

Procedures are series of instructions which can be executed in order from
anywhere else in source code. Procedures may modify the contents of the stack--
a powerful feature allowing complex operations to be abstracted away behind
elegant APIs.

Chai provides a number of built-in procedures for common operations such as
adding two numbers together, duplicating elements on the stack, dropping
unwanted elements from the stack, etc.

Putting these concepts together we get programs which look something like this:

```
# Takes an integer and returns its value squared
proc square (int -> int) {
    dup *
}

# Entry point
proc main {
    # Print string
    "5^2 = " puts

    # Square 5, printing the result
    5 square puti
}
```

## Syntax

### Comments

Comments are preceded with the pound symbol `#` and continue until the end of
the line.

```
# This is a comment
```

### Identifiers

Identifiers begin with an ASCII letter, and may contain any sequence of ASCII
letters, digits, and hyphens `-` thereafter.

```
add
to-str
pow2
```

## Language reference

### Literals

Value literals in source code are pushed onto the value stack as they are
encountered.

#### Boolean literals

```
true
false
```

#### Integer literals

Integer literals can be preceded by either the ASCII minus `-` or ASCII plus
`+` symbols to indicated signedness.

```
42
-127
+7
```

#### Float literals

Float literals must begin and end with an ASCII digit. This means that literals
such as `.7` and `1.` cannot be used in place of `0.7` and `1.0`.

```
3.14
0.577
1.0
```

#### Character literals

Character literals begin with an ASCII single-quote `'`, and end with another
ASCII single-quote.

```
'a'
'&'
'\n'
```

#### String literals

String literals begin with an ASCII double-quote `"`, and end with another
ASCII double-quote. Unlike most literals, string literals push not one but
*two* values onto the stack--the first being a pointer to the first character
in the string, and the second being the length of the string in bytes. String
literals are **not** null-terminated.

```
"This is a string"
"This is another string\n"
```

#### Extra: Escape sequences

Both string literals and character literals may contain escape sequences--a
character preceded with an ASCII backslash `\`--to represent a non-printable
ASCII character such as a newline, carriage return, horizontal tab, etc.

List of valid escape sequences:

| Sequence | Hex | Name |
|----------|-----|------|
| `\b` | 08h | Backspace |
| `\t` | 09h | Horizontal Tab |
| `\n` | 0Ah | Newline |
| `\r` | 0Dh | Carriage Return |
| `\"` | 22h | Double-quote |
| `\'` | 27h | Single-quote |
| `\\` | 5Ch | Backslash |


### Types

Chai is a statically typed programming language, meaning that the type of all
values must be known at compile-time. Chai is also strongly typed, meaning that
types cannot be used interchangeably.

The following "primitive" types are provided by default, although users can
optionally define their own types (see #Structs).

| Type | Description |
|------|-------------|
| `int` | Signed integer. Size may vary on across different platforms and architectures |
| `uint` | Unsigned integer. Size may vary across different platforms and architectures |
| `int8` | Signed 8-bit integer |
| `int16` | Signed 16-bit integer |
| `int32` | Signed 32-bit integer |
| `int64` | Signed 64-bit integer |
| `uint8` | Unsigned 8-bit integer |
| `uint16` | Unsigned 16-bit integer |
| `uint32` | Unsigned 32-bit integer |
| `uint64` | Unsigned 64-bit integer |
| `float` | 32-bit floating point value (implemented according to the IEEE 754 standard) |
| `float32` | 32-bit floating point value (implemented according to the IEEE 754 standard) |
| `float64` | 64-bit floating point value (implemented according to the IEEE 754 standard) |
| `bool` | Boolean value. Can only be `true` or `false` |
| `string` | Type alias with type specifier `(ptr uint)` |
| `ptr` | Pointer which is not associated to any data type. Equivalent to `void*` in C |

### Type specifiers

Type specifiers are used to indicate the type of a given value.

Type specifiers begin with an ASCII open-parenthesis `(`, are followed by a
type name, and end with an ASCII closing-parenthesis `)`.

```
(int)
(bool)
(float)
```

### Constants

Constant definitions begin with the `const` keyword, followed by an identifier,
an optional type specifier, and a value literal. Type specifiers can only be
omitted for primitive types, in which case the following types will
automatically be used for given value literals.

Constants can be used anywhere within the scope in which it is defined by
using its identifier in place of a value literal.

| Literal | Inferred type |
|---------|---------------|
| Boolean literal | `bool` |
| Integer literal | `int` |
| Float literal | `float` |
| Character literal | `uint8` |
| String literal | `string` |

```
const name (string) "John Doe"
const age 18

proc main {
    name puts " is " puts age puti " years old!\n" puts
}
```

### Variables

Variable definitions begin with the `var` keyword, followed by an identifier, a
type specifier, and an optional initial value. Uninitialized variables are
default-initialized to zero.

Variables are essentially constant pointers to statically allocated memory
which can be written to and read from freely using the `!` and `@` keywords
respectively.

```
const name "John Doe"
var age (int) 18

proc birthday {
    age @ 1 + age !
    name puts " is now " puts age @ puti " years old!\n" puts
}

proc main {
    name puts " is " puts age @ puti " years old!\n" puts
    birthday
}
```

### Type signatures

Type signatures are used to indicate how a given procedure will modify the
stack.

Type signatures begin with an ASCII open-parenthesis `(`, are followed by one
or more type names indicating the procedure's inputs, a type separator `->`,
one or more type names indicating the procedure's outputs, and end with an
ASCII closing-parenthesis `)`.

### Procedures

Procedures begin with the `proc` keyword, followed by an identifier, a type
signature, and a body. Type signatures can be omitted from procedures which
leave the stack unmodified after execution.

```
proc square (int -> int) {
    dup *
}

# No type signature needed
proc say-hello {
    "Hello!\n" puts
}
```

### If/Elif/Else

If statements begin with the `if` keyword and are followed by a body. If
statements can optionally be followed by infinitely many elif statements, and
a single else statement. Elif and else statements, much like if statements,
begin with the `elif` and `else` keywords respectively, and are followed by
bodies.

```
const answer 4

proc main {
    gets str-to-int

    dup answer = if {
        "You guessed it!\n" puts
    }
    dup answer > elif {
        "Your answer was too high.\n" puts
    }
    else {
        "Your answer was too low.\n" puts
    }
}
```

### While

While loop will continue to run so lang as the value on top of the stack is
true.

```
# Count backwards from 10
proc main {
    10 dup 0 = not while {
        dup puti
        1 -
        dup 10 = not
    }
}
```

### Structs

Structs are user-defined data-types which can be used in source code.

Structs begin with the `struct` keyword, followed by an identifier, and a body.
This body must contain zero or more identifier-type pairs, representing struct
members.

Struct members can be used to get the member's offset in relation to the
beginning of the struct. It is recommended to use struct members as offsets
rather than integer constants as struct members may be padded.

Statically allocated structs can be created by using the `static` keyword
followed by the name of a struct. Struct can instead be allocated at run-time
by using the `new` keyword in a similar fashion.

```
struct Account {
    username (string)
    password-hash (uint64)
}

var account (Account) static Account

proc main {
    account Account.username +      "John Doe" !
    account Account.password-hash   "password123" hash !
}
```

### Defer

The `defer` keyword can be used to defer the execution of a block of code to
the end of a given scope. This can be useful for things such as freeing
manually allocated memory, closing files, etc..

```
proc main {
    "test.txt" "r" fopen
    defer { fclose }

    dup fread puts
} # Closes file before exiting the current scope
```

### Importing external modules

External modules can be included in a source file using the `include` keyword
followed by a string literal containing a path to the external module. By
default the Chai compiler will search for external modules in your working
directory, the `src/` directory, and the `lib/` directory. The two
aforementioned directories do not need to exist for includes to work.

```
# greeter.chai
proc greet-user (string -> ) {
    "Hello, " puts puts "!\n" puts
}
```

```
# main.chai
include "greeter.chai"

proc main {
    "John Doe" greet-user
}
```

## Keyword reference

TBD...

## Memory management

All dynamically allocated values in Chai are reference counted. This means that
programmers need not concern themselves with freeing memory manually. Instead
values are automatically free'd as they go out of scope.

```
proc alloc-test {
    # Dynamically allocate int "foo"
    var foo (ptr) new int
} # foo will be free'd here as it goes out of scope

proc main {
    alloc-test
}
```

### Dangers

Reference counting does come with some dangers, however. Chai will not attempt
to resolve reference cycles. This can lead to memory leaks in specific
situations. This being the case, Chai cannot claim to be memory-safe. That
said, Chai programs which do not include cyclic references can be trusted to be
memory safe.

```
struct Foo {
    child (ptr)
}

proc alloc-test {
    # Dynamically allocate "foo"
    var foo (Foo) new Foo
    # Set foo's child to foo (self-reference)
    foo Foo.child + foo !
} # Foo cannot be free'd as foo's child (also foo) must be free'd before this can happen

proc main {
    alloc-test
}
```
