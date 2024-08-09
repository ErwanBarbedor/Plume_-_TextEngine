![Plume - TextEngine](logo.png)

![Version](https://img.shields.io/badge/version-0.1.0-blue.svg) [![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

## Introduction

Plume - TextEngine is a Lua-based templating engine designed for text generation and manipulation. It provides a flexible and efficient way to create dynamic content using a combination of static text and embedded Lua code.

The primary goal of Plume is to offer a powerful yet easy-to-use solution for generating text output in various contexts, such as document creation, code generation, or any scenario requiring dynamic text processing.

Plume is highly extensible with the Lua scripting language.

## Quick Start

You can test plume in [your browser](https://app.barbedor.bzh/txe.html). 

Plume requires Lua to run. It has been tested with Lua versions 5.1, 5.4, and LuaJIT. You just need to download the ```dist/txe.lua``` file.

Write the following in a file `input.txe`:

```txe
\def table[x] {
    \for {i=1, 10} {
        #x * #i = #{x*i}
    }
}
\table {3}
```

Then, in a command console, execute:

```bash
lua txe.lua -p input.txe
```

This runs the `input.txe` file and you should see the multiplication table of 3 in your console.

To save this result to the `output.txt` file, run:

```bash
lua txe.lua -o output.txt input.txe
```

You can also write your `input.txe` like this:

```txe
\table[x] {
    ...
}
\file {output.txt} {
    \table{3}
}
```

And just call:

```bash
lua txe.lua input.txe
```

_Of course, with this method you can output several files._

For a list of available options, use:

```
> lua txe.lua -h
Usage:
    txe INPUT_FILE
    txe --print INPUT_FILE
    txe --output OUTPUT_FILE INPUT_FILE
    txe --version
    txe --help

Options:
  -h, --help          Show this help message and exit.
  -v, --version       Show the version of txe and exit.
  -o, --output FILE   Write the output to FILE
  -p, --print         Display the result
```

## Documentation

The syntax is quite similar to that of LaTeX, but Plume behaves very differently.

Note: In the examples shown, superfluous spaces have been removed for clarity.

### Simple Text

You can write almost any text directly, and it will be rendered as-is.

Exceptions: the characters `\`, `#`, `{`, `}`, `[`, and `]` have special meanings. Also, `//`.

If you want to use them, escape them: `\\`, `\#`, ...

### Comments

Single-line comments are denoted by `//` and are not rendered in the output:

```txe
Hello // This is a comment
World
```
Output:
```
Hello World
```

### Call and Define Macros

Macros in Plume are prefixed with a backslash (`\`) and can take arguments enclosed in braces.

Example:

```txe
\macro {arg1} {arg2}
```

Optional arguments are inside square brackets.

Example:

```txe
\macro[foo bar=baz] {arg1} {arg2}
```

A macro is defined using `\def`:

```txe
\def greeting[name] {Hello, #name!}
\greeting {World}
```
Output:
```
Hello, World!
```

You can define arguments as optional with a default value:

```txe
\def greeting[name=you] {Hello, #name!}
\greeting
\greeting[name=me]
```
Output:
```
Hello, you!
Hello, me!
```

You can use any number of arguments, separated by spaces:

```txe
\def foo[x y z foo=bar baz=foo]{
    ...
}
```

_Note: Braces are optional if there is no space inside the argument: `\foo bar baz` is the same as `\foo {bar} {baz}`._

_Note: Spaces between args used by the same macros are ignored._

### Variables

Variables are defined using the `\set` command and accessed using the `#` symbol.

Example:

```txe
\set x 5
The value of x is #x
```
Output:
```
The value of x is 5
```

The `#` behaves almost like a macro, with one difference: whereas the macro will capture the first argument (if not in square brackets) as a single no-space, `#` will only capture a valid identifier, making writing certain expressions easier.

For example, `\foo x+1` is the same as `\foo {x+1}`, but `#x+1` is equivalent to `#{x}+1`.
If you want to apply `#` to the whole expression, use `#{x+1}`.

### Lua Integration

#### Lua Expressions

You can evaluate any Lua expression using `#{...}` (or its alias `\eval{...}`):

```txe
\set a 3
\set b 4
The sum of a and b is #{a + b}
```
Output:
```
The sum of a and b is 7
```

Example:

```txe
The os time is #{os.time()}
```
Output:
```
The os time is 701184650
```

You should notice that the syntax is the same as for variables. In fact, txe doesn't really have any variables; it simply evaluates an underlying Lua variable.

#### Lua Scripts

You can execute any Lua statement inside `\script{...}`.

Example:

```txe
\script{
    function factorial(n)
        if n == 0 then return 1 end
        return n * factorial(n - 1)
    end
}

The factorial of 5 is: #{factorial(5)}
```
Output:
```
The factorial of 5 is: 120
```

#### Require

You can execute an external Lua file with `\require {path}`.

```txe
\require {my_lib}
#{some_function ()}
```

Or with `\script`.

```txe
\script {
    require "my_lib"
}
```

### Control Structures

#### Conditional Statements

The `\if`, `\elseif`, and `\else` commands provide conditional logic:

```txe
\set x 10
\if {x > 5}
    {x is greater than 5}
\elseif {x < 5}
    {x is less than 5}
\else
    {x is equal to 5}
```
Output:
```
x is greater than 5
```

The condition may be any Lua expression.

#### Loops

Plume supports `\for` and `\while` loops.

For loop example:

```txe
\for {i=1,3} {
    Line #i
}
```
Output:
```
Line 1
Line 2
Line 3
```

```plume
\set fruits #{{apple = "red", banana = "yellow", grape = "purple"}}
\for {fruit, color in pairs(fruits)} {
    The #fruit is #color.
}
```
Output:
```
The apple is red.
The banana is yellow.
The grape is purple.
```

While loop example:

```txe
\set a 0
\while {a < 3} {
    \set a #{a+1}
    a is now #a
}
```
Output:
```
a is now 1
a is now 2
a is now 3
```

Like for `\if`, the `\while` limit may be any expression, and the `\for` iterator follows the Lua syntax.

#### Loop Limit

Plume is configured to stop loops after 1000 iterations, to prevent infinite loops. See configuration to edit this number. Lua loops are not affected

### Number Formatting

If an expression in `#{...}` returns a number, you can format it.

```txe
#{4/3}[i]
#{1/3}[.4f]
#{10000}[thousand_separator=,]
#{5/2}[decimal_separator=+0.]
```
Output:
```
1
0.3333
10,000
2+0.5
```

### Default Values

You can set default argument values for any macros.

```txe
\foo[bar=bar]{#bar}
\foo
\default foo[bar=baz]
\foo
```
Output:
```
bar
baz
```

To set '#' default value, use the alias "eval".

```txe
#{50000}
\default eval [thousand_separator={ }]
#{50000}
```
Output:
```
50000
50 000
```

### File Inclusion

You can include content from other files, which is useful for modularizing your templates.

Example:

Assuming a file named `header.txe` contains:

```txe
\def header[title] {
<header>
    <h1>#title</h1>
</header>
}
```

You can include and use it in your main file:

```txe
\include header.txe
\header{Welcome to My Website}
```
Output:

```html
<header>
    <h1>Welcome to My Website</h1>
</header>
```

If you want to include a file containing no `txe` code but potentially many characters to escape (like a CSS file), you can use the `\include[extern] {path}` option. The file will be read and directly included without being executed.

## Advanced Documentation

### Macros with Arbitrary Numbers of Arguments

You can access the table of all passed arguments in the field `__args`.

Example:

```txe
\def multiargs {
    \for {i, args in ipairs(__args)} {
        Argument #i : #args
    }
}
\multiargs[foo bar baz]
```
Gives:

```
Argument 1 : foo
Argument 2 : bar
Argument 3 : baz
```

### Tokenlist

Behind the scenes, Plume doesn't manipulate strings but custom tables named **tokenlists**. For example:

```txe
\def foo[x]{
    #{print(x)}
}
\foo{bar}
```
This will print... `table: 0x560002d8ad30` or something like that, and not `bar`.

To see the tokenlist content, you can call `tokenlist:source()`, which will return raw text, or `tokenlist:render()` to get final content.

_If x is a tokenlist, `#x` is the same as `#{x:render()}`._

Example:

```txe
\def foo[x]{
    #{x:source()}
    #{x:render()}
}
\foo{#{1+1}}
```
Gives:

```txe
#{1+1}
2
```

Plume does an implicit conversion each time you call a string method (like `gsub` or `match`) or an arithmetic method on it.

_If x and y are tokenlists, `#{x+y}` is roughly equivalent to `#{tonumber(x:render())+tonumber(y:render())}`._

### `\def`, `\redef`, and `\redef_forced`

You can define a new macro with `\def`. But if the name is already taken, you must use `\redef`. If the name is taken by a predefined macro, use `\redef_forced`.

### `\set` Behavior

When calling `\set x {value}`, Plume will render the value before saving it as a string. So:

```txe
\def foo {bar}
\set x \foo
#x
\redef foo baz
#x
```

Gives `bar bar`, and not `bar baz`.

If the value is an `\eval` block, `\set` will save it as a Lua object.

```txe
\set x 1+1
\set y #{1+1}

#{type(x)}, #{type(y)}
```

Gives `string, number`.

### Variables Scope

Variables are global by default.

```txe
\def foo {
    \set x 20
}
\set x 10
\foo
#x
```
Gives:

```
20
```

But it is possible to make them local, with `\set[local]` (or its alias `\setl`).

```txe
\def foo {
    \set[local] x 20
}
\set x 10
\foo
#x
```

Gives:

```
10
```

### Too Many Intricate Macro Calls

By default, Plume cannot handle more than 100 macros in the call stack, mainly to avoid infinite loops on things like `\def foo {\foo}`.

See configuration to edit this number.

### Lua Scope

Local variables are local to the macro script and cannot be used outside it. For global variables, if a variable with the same name exists, they share the same scope. Otherwise, they are global. To declare a variable inside a script macro but local to the current `txe` scope, use `txe.set_local (key, value)` (or its alias `txe.setl`).

Example:

```txe
\def foo {
    \script {
        local a = 0
        b = 1
        c = 2
        txe.set_local("d", 3)
    }
    a: #a, b: #b, c: #c, d: #d
}
\set d 20
\set c 30
\foo
a: #a, b: #b, c: #c, d: #d
```
Gives:

```
a: , b: 1, c: 2, d: 3
a: , b: 1, c: 2, d: 20
```

### Spacing
By default, Plume retains all spaces. If you want to remove them, use comments.
A comment deletes the line feed _and_ the indentation of the following line.

For exemple, 
```txe
foo //
    bar
```
Gives
```txe
foo bar
```

### Configuration

Plume configuration variables may be edited via
```txe
\script{
    txe.config.variable_name = value
}
```

List of variables :

| Name                  | Default value | note|
| max_callstack_size    | 100           | Maximum number of nested macros. Intended to prevent `\def foo {\foo}` kinds of error.|
| max_loop_size         | 1000          | Maximum of loop iteration for macros `\while` and `\for`.|

## Predefined Macros List

_Coming soon..._

## Warnings for LaTeX Users

In LaTeX, you can define a macro like this: `\newcommand {\foo} {bar}`, because `newcommand` will be expanded _before_ `foo`.

This doesn't work in Plume because `foo` will be expanded first.

## License