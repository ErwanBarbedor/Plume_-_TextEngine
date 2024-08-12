# Predefined functions


## `txe`

`txe` is a global table containing the following functions.

### `txe.set_local`

**Description:** Set a variable locally

**Parameters:**
- _name_: Variable name.
- _value_: Variable value.

**Example:**

```txe
\def foo {
    \script{
        txe.set_local("a", 1)
        b = 2
    }
    #a #b
}
\foo
#a #b
```
Output:
```
1 2
2
```

### `txe.require`

**Description:**  Works like Lua's require, but uses Plume's file search system.
**Parameters:**
- _name_: Name of the lua file to load.

## `tokenlist`


`tokenlist` are Lua representations of Plume structures. You can access them in a macro call via variables named after arguments.

Example:
```txe
\def foo[x] {
    #{x.__type}
}
\foo 5
```
Output:
```
tokenlist
```

## `tokenlist:render ()`

**Description:**  Renders tokenlist
Example:
```txe
\def foo[x] {
    x=#{x:render()}
}
\foo 5
```
Output:
```
x=5
```

## `tokenlist:renderLua ()`

**Description:** If the tokenlist starts with `#`, ``eval` or ``script`, evaluate this macro and return the result as a lua object, without conversion to string.
Otherwise, render the tokenlist.

```txe
\def foo[x] {
    Render : #{type(x:render())}
    RenderLua : #{type(x:renderLua())}
}

\foo #{{}}
```
Output :
```
Render : string
RenderLua : table
```

## `tokenlist:source ()`

**Description:** Get tokenlist string representation
Example:
```txe
\def foo[x] {
    Source   : #{x:source ()}
    Rendered : #{x:render()}
}
\foo #{1+1}
```
Output:
```
Source   : #{1+1}
Rendered : 2
```