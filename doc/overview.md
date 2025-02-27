# Overview

Here's an overview of Plume's main features.

Note: In the examples shown, superfluous spaces have been removed for clarity.

## Simple Text

You can write almost any text directly, and it will be rendered as-is.

Exceptions: the characters `\`, `$`, `{`, `}`, `[`, and `]` have special meanings. Also, `\--`.

If you want to use them, escape them: `\\`, `\$`, ...

## Comments

Single-line comments are denoted by `\--` and are not rendered in the output:

```plume
Hello \-- This is a comment
World
```
Output:
```
Hello World
```

## Call and Define Macros

Macros in Plume are prefixed with a backslash (`\`) and can take arguments enclosed in braces.

Example:

```plume
\macro {arg1} {arg2}
```

Optional arguments are inside square brackets.

Example:

```plume
\macro[foo bar=baz] {arg1} {arg2}
```

A macro is defined using `\macro`:

```plume
\macro greeting[name] {Hello, $name!}
\greeting {World}
```
Output:
```
Hello, World!
```

You can define arguments as optional with a default value:

```plume
\macro greeting[name=you] {Hello, $name!}
\greeting
\greeting[name=me]
```
Output:
```
Hello, you!
Hello, me!
```

You can use any number of arguments, separated by spaces:

```plume
\macro foo[x y z foo=bar baz=foo]{
    ...
}
```

_Note: Braces are optional if there is no space inside the argument: `\foo bar baz` is the same as `\foo {bar} {baz}`._

_Note: Spaces between args used by the same macros are ignored._

## Variables

Variables are defined using the `\set` command and accessed using the `$` symbol.

Example:

```plume
\set x 5
The value of x is $x
```
Output:
```
The value of x is 5
```

The `$` behaves almost like a macro, with one difference: whereas the macro will capture the first argument (if not in brace) as a single no-space, `$` will only capture a valid identifier, making writing certain expressions easier.

For example, `\foo x+1` is the same as `\foo {x+1}`, but `$x+1` is equivalent to `${x}+1`.
If you want to apply `$` to the whole expression, use `${x+1}`.

You can also define variable with Lua:

```plume
${x = 5}
```


## `\set k {v}` vs `${k = v}` vs `\macro k {v}`
These three methods produce similar results. But there are nuances to the way they work.

`macro k {v}` is the only one capable of defining a dynamic content. So you shouldn't use it to save a value.

`${k = v}` is the only one that lets you save lua objects. Use it with numbers, tables, ...

Unlike `${k = v}`, `set k {...}` can save a block.


## Lua Integration

### Lua Expressions

You can evaluate any Lua expression using `${...}` (or its alias `\eval{...}`):

```plume
\set a 3
\set b 4
The sum of a and b is ${a + b}
```
Output:
```
The sum of a and b is 7
```

Example:

```plume
The os time is ${os.time()}
```
Output:
```
The os time is 701184650
```

You should notice that the syntax is the same as for variables. In fact, plume doesn't really have any variables; it simply evaluates an underlying Lua variable.

### Lua Scripts

You can execute any Lua statement with `${...}`.

Example:

```plume
${
    function factorial(n)
        if n == 0 then return 1 end
        return n * factorial(n - 1)
    end
}

The factorial of 5 is: ${factorial(5)}
```
Output:
```
The factorial of 5 is: 120
```

You can return values :

```plume
${
    a = 1+1
    a = a * 2
    return a
}
```
Output:
Output:
```
4
```

### Require

You can execute an external Lua file with `\require {path}`.

```plume
\require {my_lib}
${some_function ()}
```

Or with `plume.require` inside an eval block :

```plume
${
    plume.require "my_lib"
}
```

## Control Structures

### Conditional Statements

The `\if`, `\elseif`, and `\else` commands provide conditional logic:

```plume
\set x 10
\if ${x > 5}
    {x is greater than 5}
\elseif ${x < 5}
    {x is less than 5}
\else
    {x is equal to 5}
```
Output:
```
x is greater than 5
```

The condition may be any Lua expression.

### Loops

Plume supports `\for` and `\while` loops.

For loop example:

```plume
\for ${i=1,3} {
    Line $i
}
```
Output:
```
Line 1
Line 2
Line 3
```

```plume
${fruits = {apple = "red", banana = "yellow", grape = "purple"}}
\for ${fruit, color in pairs(fruits)} {
    The $fruit is $color.
}
```
Output:
```
The apple is red.
The banana is yellow.
The grape is purple.
```

While loop example:

```plume
\set a 0
\while ${a < 3} {
    \set a ${a+1}
    a is now $a
}
```
Output:
```
a is now 1
a is now 2
a is now 3
```

Like for `\if`, the `\while` limit may be any expression, and the `\for` iterator follows the Lua syntax.

### Loop Limit

Plume is configured to stop loops after 1000 iterations, to prevent infinite loops. See [config](config.md) to edit this number. Lua loops are not affected

## Number Formatting

If an expression in `${...}` returns a number, you can format it.

```plume
${4/3}[i]
${1/3}[.4f]
${10000}[thousand_separator=,]
${5/2}[decimal_separator=+0.]
${5327}[%.2s]
```
Output:
```
1
0.3333
10,000
2+0.5
5.32E3
```

## Default Values

You can set default argument values for any macros.

```plume
\foo[bar=bar]{$bar}
\foo
\default foo[bar=baz]
\foo
```
Output:
```
bar
baz
```

To set '$' default value, use the alias "eval".

```plume
${50000}
\default eval [thousand_separator={ }]
${50000}
```
Output:
```
50000
50 000
```

## File Inclusion

You can include content from other files, which is useful for modularizing your templates.

Example:

Assuming a file named `header.plume` contains:

```plume
\macro header[title] {
<header>
    <h1>$title</h1>
</header>
}
```

You can include and use it in your main file:

```plume
\include header
\header{Welcome to My Website}
```
Output:

```html
<header>
    <h1>Welcome to My Website</h1>
</header>
```

If you want to include a file containing no `plume` code but potentially many characters to escape (like a CSS file), use `\extern {path}`. The file will be read and directly included without being executed.
