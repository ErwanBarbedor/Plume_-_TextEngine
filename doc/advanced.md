# Advanced Documentation

## Macros with Arbitrary Numbers of Arguments

You can access the table of all passed arguments in the field `__args`.

Example:

```plume
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

You can also easily check if there is an unnamed optionnal argument with a certain value
```plume
\def foo {
    \if {__args.option_a} {
        Option A
    }
    \elseif {__args.option_b} {
        Option B
    }
}
\foo[option_b]
```
Gives:

```
Option B
```

## File arguments
You can supply arguments to included files. They will be stored in the `__file_args` table.

Example:
```plume
\include[foo=bar baz] lib
// lib.plume
#{__file_args.foo}
#{__file_args[1]}
```
Output:
```
bar
baz
```


## Tokenlist

Behind the scenes, Plume doesn't manipulate strings but custom tables named **tokenlists**. For example:

```plume
\def foo[x]{
    #{print(x)}
}
\foo{bar}
```
This will print... `table: 0x560002d8ad30` or something like that, and not `bar`.

To see the tokenlist content, you can call `tokenlist:source()`, which will return raw text, or `tokenlist:render()` to get final content.

_If x is a tokenlist, `#x` is the same as `#{x:render()}`._

Example:

```plume
\def foo[x]{
    #{x:source()}
    #{x:render()}
}
\foo{#{1+1}}
```
Gives:

```plume
#{1+1}
2
```

Plume does an implicit conversion each time you call a string method (like `gsub` or `match`) or an arithmetic method on it.

_If x and y are tokenlists, `#{x+y}` is roughly equivalent to `#{tonumber(x:render())+tonumber(y:render())}`._

## `\def`, `\redef`, and `\redef_forced`

You can define a new macro with `\def`. But if the name is already taken, you must use `\redef`. If the name is taken by a predefined macro, use `\redef_forced`.

## `\set` Behavior

When calling `\set x {value}`, Plume will render the value before saving it as a string. So:

```plume
\def foo {bar}
\set x \foo
#x
\redef foo baz
#x
```

Gives `bar bar`, and not `bar baz`.

If the value is an `\eval` block, `\set` will save it as a Lua object.

```plume
\set x 1+1
\set y #{1+1}

#{type(x)}, #{type(y)}
```

Gives `string, number`.

## Scopes
### Variables Scope

Each macro execution create a new scope.
Variables are global by default.

```plume
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

```plume
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

## `\for` and `\while` scope
Like macros, each iteration has it's own scope.

### Parameters scopes

Variables used as parameters retain the scope in which the macro was called.

```plume
\def foo[bar] {\set[local] x 3 #bar}
\set x 1 
\foo {#x}
```

Output `1`.

### Closure

Plume implements a closure system, i.e. variables local to the block where the macro is defined remain accessible from this macro.

```plume
\def mydef[name body] {
    \def {#name} {#body}
}
\mydef foo bar
\foo
```
Output `bar`, even though `name` and `body` are variables local to the `mydef` block and shouldn't be accessible anywhere else.

## Too Many Intricate Macro Calls

By default, Plume cannot handle more than 100 macros in the call stack, mainly to avoid infinite loops on things like `\def foo {\foo}`.

See `\config` macro to edit this number.

## Lua Scope

Local variables are local to the macro script and cannot be used outside it. For global variables, if a variable with the same name exists, they share the same scope. Otherwise, they are global. To declare a variable inside a script macro but local to the current `plume` scope, use `plume.set_local (key, value)` (or its alias `plume.setl`).

Example:

```plume
\def foo {
    \script {
        local a = 0
        b = 1
        c = 2
        plume.set_local("d", 3)
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

## Spacing
By default, Plume retains all spaces. If you want to remove them, use comments.
A comment deletes the line feed _and_ the indentation of the following line.

For exemple, 
```plume
foo //
    bar
```
Gives
```plume
foo bar
```

You can also edit the `ignore_spaces` parameter (see `\config` macro) to remove almost all spaces from input file.
Then, you have to add it yourself with `\n` for new line (or `\n[5]` for five new lines), `\s` for space and `\t` for tabulation.