![Plume - TextEngine](logo.png)

![Version](https://img.shields.io/badge/version-0.1.0-blue.svg) [![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

## Introduction

Plume - TextEngine is a Lua-based templating engine designed for text generation and manipulation. It provides a flexible and efficient way to create dynamic content using a combination of static text and embedded Lua code.

The primary goal of Plume is to offer a powerful yet easy-to-use solution for generating text output in various contexts, such as document creation, code generation, or any scenario requiring dynamic text processing.

Plume is highly extensible with the lua scripting language.

## Quick Start

Plume requires Lua to run.
It has been tested with versions Lua 5.1, Lua 5.4 and Luajit.
You just need to download the ```dist/txe.lua``` file.

Write in a file `input.txe`
```txe
\def table[x] {
    \for {i=1, 10} {
        #x * #i = #{x*i}
    }
}
\table {3}
```

Then, in a command console:

```bash
lua txe.lua -p input.txe
```
Executes the ```input.txe``` file  : you should see the multiplication table of 3 in your console.


If you want to save this result to the ```output.txt``` file,

```bash
lua txe.lua -o output.txt input.txe
```

You can also write your input.txe like this
```txe
\table[x] {
    ...
}
\file {output.txt} {
    \table{3}
}
```

And just call

```bash
lua txe.lua input.txe
```
_Of course, with this method you can output severals files_

You can access the list of available options with
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

The syntax is quite similar to that of LaTeX.

Note : In the examples shown, superfluous spaces have been removed for clarity.

### Simple text
You can write directly almost any text it will be rend as is.

Exceptions : chars `\`, `#`, `{`, `}`, `[` and `]` have a special meaning. Also `//`.

If you want to use then, escape it : `\\`, `\#`, ...

### Comments
Single-line comments are denoted by '//' and are not rendered in the output:

```txe
Hello // This is a comment
World
```
Output:
```
Hello World
```

### Call and define macros
Macros in Plume are prefixed with a backslash (`\`) and can take arguments enclosed in  braces.

Example:
```txe
\macro {arg1} {arg2}
```

Optionnal argument are inside square brackets

Example:
```txe
\macro[foo bar=baz] {arg1} {arg2}
```

A macro is defined by `\def`:

```txe
\def greeting[name] {Hello, #name!}
\greeting {World}
```
Output:
```
Hello, World!
```

You can define argument as optional with a defaut value:
```txe
\def greeting[name=you] {Hello, #name!}
\greeting
```
Output:
```
Hello, you!
```

You can use any number of arguments, separated by spaces
```txe
\def foo[x y z foo=bar baz=foo]{
    ...
}
```

_Note : Braces are optionnals if there is no space inside argument : `\foo bar baz` is the same as `\foo {bar} {baz}`_

_Note : spaces between args used by the same macros are ignored._

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

`#` behaves almost like a macro, with one difference: whereas the macro will capture the first argument (if not in square brackets) as a single no-space, "#" will only capture a valid identifier, to lighten the burden of writing certain expressions.

For example, `\foo x+1` is the same as `\foo {x+1}`, but `#x+1` is the same as `#{x}+1`.
If you want to apply `#` to the whole expression, type `#{x+1}`. 



### Lua integration

#### Lua expressions

You can eval any lua expression using `#{...}` (or its alias `\eval{...}`) :
```txe
\set a 3
\set b 4
The sum of a and b is #{a + b}
```
Output:
```
The sum of a and b is 7
```

Input:
```txe
The os time is #{os.time()}
```
Output:
```
The os time is 701184650
```

You should notice that the syntax is the same as for variables. In fact, txe doesn't really have any variables, it simply evaluates an underlying lua variable.

#### Lua scripts

You can execute any lua statement inside `\script{...}`

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

The condition may be any lua expression.

#### Loops

Plume supports `\for` and `\while` loops:

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

Like for `\if`, `\while` limit may be any expression, and `\for` iterator follow too the lua syntax.

#### Loops limit

For more than 1000 iterations, txe will crash.


### Numbers formating
If expression in `#{...}` return a number, you can format it.

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

### Defauts values
You can set defaut args value for any macros.

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

For set '#' defaut value, use alias "eval".
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

If you want to include a file containing no txe code but potentially many characters to escape, (like a css file) you can use the `\include[extern] {path}` option.
The file will be read and directly included without being executed.


## Advanced documentation

### Macro with arbitrary number of arguments

### File searching

### Tokenlist

Behind the scene, Plume doesn't manipulate string but custom tables named **tokenlists**.
For exemple,
```txe
\def foo[x]{
    #{print(x)}
}
\foo{bar}
```
will print... `table: 0x560002d8ad30` or something like that, and not `bar`.

To see the tokenlist content, you can call `tokenlist:source()`, that will return raw text, or `tokenlist:render()` to get final content.

_if x is a tokenlist, `#x` is the same as `#{x:render()}`_

Exemple:
```txe
\def foo[x]{
    #{x:source()}
    #{x:render()}
}
\foo{#{1+1}}
```

Gives
```txe
#{1+1}
2
```

Plume do an implicit conversion each time you call a string method (like `gsub` or `match`) or an arithmetic method on it.

_if x and y are tokenlists, `#{x+y}` is roughly the same as `#{tonumber(x:render())+tonumber(y:render())}`_

### Variables scope
Variables are global by default
```txe
\def foo {
    \set x 20
}
\set x 10
\foo
#x
```
Gives
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
Gives
```
10
```

### Lua scope

Any lua local variable is local to the macro script where it has been defined.

Global variables are more complicated.

## Predefined macros list

## Warnings for LaTeX users

In LaTeX, you can define a macro like this: `\newcommand {\foo} {bar}`, because `newcommand` will be expansed _before_ `foo`.

This doesn't work in Plume, because `foo` will be expansed first

## More Exemples