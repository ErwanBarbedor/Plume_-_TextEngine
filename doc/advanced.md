# Advanced Documentation

## Macro Parameters

A macro can have 3 kinds of parameters:

### Positional Parameters

```plume
\macro double[x y] {$x $x $y $y}
\double bar baz
```
`x` and `y` are _positional parameters_. They must follow the macro call in the same order as declared. They will not be rendered until the user decides to (In this exemple, it will be rendered twice : `$x $x`).

### Keyword Parameters

```plume
\macro hello[name=World salutation=Hello] {$salutation $name}
\hello
\hello[salutation=Greeting]
```
`name` and `salutation` are _keyword parameters_. The order doesn't matter, and you can omit them if you like. If you use them, you must employ the `=` symbol.

In `\hello[salutation=Greeting]`, `salutation` will be rendered during the macro call. However, `Greeting` will not be rendered until the user decides to. (So yes, you can use block as parameter name : `\hello[{\gen_name}=bar]`)

### Flags

```plume
\macro hello[?polite] {
    \if $polite {
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
\macro hello[polite=${false}] {
    ${polite = polite:render_lua()}
    [...]
}
\hello
\hello[polite=${true}]
```

As you can see and similarly to keyword parameters, `polite` will be rendered during the macro call.

### Other Parameters

By default, Plume will raise an error if you use unknown flags or keyword parameters, (and it is impossible to pass more positional parameters than defined, as the overflow will be treated as following blocks).

You can modify this behavior:

```plume
\macro foo[...] {
    ${__params.bar} -> baz
    ${__params.flag} -> true
}
\foo[bar=baz flag]
```

By using `...`, all unknown parameters will be stored in a table named `__params`.


## File parameters
You can supply parameters to included files. They will be stored in the `__file_params` table.

Example:
```plume
\include[foo=bar baz] lib
\-- lib.plume
${__file_params.foo}
${__file_params[1]}
```
Output:
```
bar
baz
```
## Conversion Annotations
Instead of:
```plume
\macro foo[x] {
    ${x = tonumber(x:render())}
    ...
}
```

You can write:
```plume
\macro foo[x:number] {
    ...
}
```

Available types are:
- `auto` (default behavior) : try, in this order:
    - To return a number
    - To return a Lua object
    - To return a string
- `number`: converts to a number
- `int`: converts to an integer. Rounds it if necessary.
- `string` (default behavior): converts to a string
- `lua`: tries to return a Lua value, if it fails, returns a string
- `ref`: returns a tokenlist, see the tokenlist section.

Plume doesn't do any _type checking_: with the previously defined `foo`, `\foo bar` will just convert `bar` to `nil`, without error.

You can also use any function as an annotation:

```plume
${
    plume.annotations.braced = function (x)
        return "(" .. x:render() .. ")"
    end
}
\macro foo[x:braced] {
    $x
}
\foo bar -> (bar)
```

**Warning:** in this case,

```
\macro foo[x=${1/3}[i]] ${$x}
```

`foo` will return... `0.333...`, and not `0`, because `:auto` annotation tries to return the Lua value of `${1/3}`, without formatting.

If you want the optional parameter `i` to apply, use:

```
\macro foo[x:string=${1/3}[i]] ${$x}
```


## Dynamic parameters
```plume
${i=0}
\macro repeat[x] {$x $x}
\repeat ${i=i+1 return i}
```

Will return... `1 1`, because `${i=i+1 return i}` will be rendered before being passed to `repeat`.

If you want to render `x` two times, use 
```plume
${i=0}
\macro repeat[x:ref] {$x $x}
\repeat ${i=i+1 return i}
```

## Tokenlist

Behind the scenes, Plume doesn't manipulate strings but custom tables named **tokenlists**. For example:

```plume
\macro foo[x:ref]{
    ${print(x)}
}
\foo{bar}
```
This will print... `table: 0x560002d8ad30` or something like that, and not `bar`.

To see the tokenlist content, you can call `tokenlist:source()`, which will return raw text, `tokenlist:render()` to get final content as string or `tokenlist:render_lua()` to get result as a lua object.

_If x is a tokenlist, `$x` is the same as `${x:render()}`._

Example:

```plume
\macro foo[x:ref]{
    ${x:source()}
    ${x:render()}
}
\foo{${1+1}}
```
Gives:

```plume
${1+1}
2
```

## Scopes
### Variables Scope

Each macro execution create a new scope.
Variables are global by default.

```plume
\macro foo {
    \set x 20
}
\set x 10
\foo
$x
```
Gives:

```
20
```

But it is possible to make them local, with `\local_set` (or its alias `\lset`).

```plume
\macro foo {
    \local_set x 20
}
\set x 10
\foo
$x
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
\macro foo[bar] {
    \local_set x 3
    $bar
}
\set x 1 
\foo {$x}
```

Output `1`.

### Closure

Plume implements a closure system, i.e. variables local to the block where the macro is defined remain accessible from this macro.

```plume
\macro mydef[name body] {
    \macro {$name} {$body}
}
\mydef foo bar
\foo
```

Output `bar`, even though `name` and `body` are variables local to the `mydef` block and shouldn't be accessible anywhere else.

## Too Many Intricate Macro Calls

By default, Plume cannot handle more than 100 macros in the call stack, mainly to avoid infinite loops on things like `\macro foo {\foo}`.

See [config](config.md) to edit this number.

## Spacing
By default, Plume retains all spaces. If you want to remove them, use comments.
A comment deletes the line feed _and_ the indentation of the following line.

For exemple, 
```plume
foo \--
    bar
```
Gives
```plume
foo bar
```

You can also see [spaces macros](macros.md#spaces)) to have more controls over spaces.

## Include Plume code inside Lua block

In some cases, you want to switch from _a lot of text with some Lua_ to _a lot of Lua with some text_.

Or just want to call a macro within a lua script.

To do that, you can just declare a Plume block inside the Lua script:

``` Plume
\macro bar {
    baz
}

${
    function foo ()
        return ${Call macro : \bar}
    end
}

${foo()} -> Call macro : baz
```

Limitation:
``` Plume
${
    local a = 4
    local b = ${ a is $a}
    local c =  b:render ()
    return c
}
```
Output .. `a is `, and not `a is 4`.

In fact, plume capture lua variable one time at the end of the block. So, with this syntax, you can't use local variable inside the inserted plume code.