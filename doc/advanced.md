# Advanced Documentation

## Macros with Arbitrary Numbers of Arguments

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

## Tokenlist

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

## `\def`, `\redef`, and `\redef_forced`

You can define a new macro with `\def`. But if the name is already taken, you must use `\redef`. If the name is taken by a predefined macro, use `\redef_forced`.

## `\set` Behavior

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

## Variables Scope

Each macro execution create a new scope.
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

## Too Many Intricate Macro Calls

By default, Plume cannot handle more than 100 macros in the call stack, mainly to avoid infinite loops on things like `\def foo {\foo}`.

See `\config` macro to edit this number.

## Lua Scope

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

## Spacing
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

You can also edit the `ignore_spaces` parameter (see `\config` macro) to remove almost all spaces from input file.
Then, you have to add it yourself with `\n` for new line (or `\n[5]` for five new lines), `\s` for space and `\t` for tabulation.