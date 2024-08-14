# Predefined functions


## `plume` functions

`plume` is a global table containing the following functions :

### `plume.set_local ()`

**Description:** Set a variable locally

**Parameters:**
- _name_: Variable name.
- _value_: Variable value.

**Example:**

```plume
\def foo {
    \script{
        plume.set_local("a", 1)
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

### `plume.get ()`

**Description:** Get a variable value from current scope by name.

**Parameters:**
- _name_: Variable name

**Note** : `plume.get` may return a tokenlist, so may have to call `plume.get (name):render ()` or `plume.get (name):renderLua ()`. See `plume.get_render` and `plume.get_renderLua`

```plume
\script{
    a = 1
    return plume.get "a"
}
```
Output
```
1
```

### `plume.get_render ()`
**Description:** If the variable has a render method, call it and return the result. Otherwise, return the variable.

**Parameters:**
- _name_: Variable name

**Alias** : `plume.getr`

### `plume.getr ()`
**Description:** Alias to `plume.get_render`

### `plume.get_lua`
**Description:** If the variable has a renderLua method, call it and return the result. Otherwise, return the variable.

**Parameters:**
- _name_: Variable name

**Alias** : `plume.getl`

### `plume.getl ()`
**Description:** Alias to `plume.get_renderLua`

### `plume.require ()`

**Description:**  Works like Lua's require, but uses Plume's file search system.

**Parameters:**
- _name_: Name of the lua file to load.

## `plume` variables

| Name                   |  Notes |
| ---------------------  | ----------- |
| input_file             | input path given to plume, if any |
| output_file            | input path given to plume, if any |

## `tokenlist`


`tokenlist` are Lua representations of Plume structures. You can access them in a macro call via variables named after arguments.

Example:
```plume
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
```plume
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

**Description:** If the tokenlist starts with `#`, `eval` or `script`, evaluate this macro and return the result as a lua object, without conversion to string.
Otherwise, render the tokenlist.

```plume
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
```plume
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