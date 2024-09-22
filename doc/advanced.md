# Advanced Documentation

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

## Macro Parameters

A macro can have four kinds of parameters:

### Positional Parameters

```plume
\def double[x y] {#x #x #y #y}
\double bar baz
```
`x` and `y` are _positional parameters_. They must follow the macro name in the same order as declared. They will not be rendered until the user decides to.

### Keyword Parameters

```plume
\def hello[name=World salutation=Hello] {#salutation #name}
\hello
\hello[salutation=Greeting]
```
`name` and `salutation` are _keyword parameters_. The order doesn't matter, and you can omit them if you like. If you use them, you must employ the `=` symbol.

In `\hello[salutation=Greeting]`, `salutation` will be rendered during the macro call. However, `Greeting` will not be rendered until the user decides to.

### Flags

```plume
\def hello[?polite] {
    \if #polite {
        Good morning sir.
    } \else {
        Hey bro!
    }
}
\hello -> Good morning sir.
\hello[polite] -> Hey bro!
```
`?polite` is a _flag_. It is a shorthand for:

```plume
\def hello[polite={#{false}}] {
    #{polite = polite:render()}
    [...]
}
\hello
\hello[polite={#{true}}]
```

As you can see and similarly to keyword parameters, `polite` will be rendered during the macro call.

### Other Parameters

By default, Plume will raise an error if you use unknown flags or keyword parameters, and it is impossible to pass more positional parameters than defined, as the overflow will be treated as following blocks.

You can modify this behavior:

```plume
\def foo[*] {
    #{__params.bar} -> baz
    #{__params.flag} -> true
}
\foo[bar=baz flag]
```

By using `*`, all other parameters will be stored in a table named `__params`.




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

### `\for` and `\while` scope
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

See [config](config.md) to edit this number.

## Lua Scope

Global and local _lua_ variables are seamlessly equivalent to global and local _plume_ variables.
Example:

```plume
\def foo {
    \script {
        local a = 0
        b = 1
    }
    a: #a, b: #b
}
\set a 20
\set b 30
\foo
a: #a, b: #b
```
Gives:

```
a: 0, b: 1
a: 20, b: 1
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

You can also see [spaces macros](macros.md#spaces)) to have more controls over spaces.