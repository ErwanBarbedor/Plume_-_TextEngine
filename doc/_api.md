# Predefined functions


## `plume` functions

`plume` is a global table containing the following functions :

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

### `plume.lua_get ()`
**Description:** If the variable has a renderLua method, call it and return the result. Otherwise, return the variable.

**Parameters:**
- _name_: Variable name

**Alias** : `plume.lget`

### `plume.getl ()`
**Description:** Alias to `plume.get_renderLua`

### `plume.require ()`

**Description:**  Works like Lua's require, but uses Plume's file search system.

**Parameters:**
- _name_: Name of the lua file to load.

### `plume.open ()`

**Description:**  Searches for a file using the plume search system and open it in the given mode. Return the opened file and the full path of the file.

**Parameters:**
_path (string)_ : The path where to search for the file.
_safe_mode (boolean)_ : If true, the search will not raise an error if no file is found.
_open_mode (boolean)_ : Defaut "r". Mode to open the file.

### `plume.capture_local ()`

**Description:** Capture the local _lua_ variable and save it in the _plume_ local scope. This is automatically called by plume at the end of `\script`.

**Notes:** Mainly internal use, you shouldn't use this function.

### `plume.export()`

**Description:** Export a lua function as a macro. If not name provided, try to get it using debug.

**Parameters:**
_name (string)_ Name of the macro
_arg_number (number)_Number of arguments to capture
_f (function)_
```
\script{
    function add(x, y)
        return x+y
    end

    plume.export("add", 2, add)
}

\add{1}{2}
```

Output `3`

## `plume` variables

| Name                   |  Notes |
| ---------------------  | ----------- |
| input_file             | input path given to plume, if any |
| output_file            | output path given to plume, if any |
| _VERSION               | plume version |
| _LUA\_VERSION          | lua version. |

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

## `tokenlist:[method] ()`
If tokenlist doesn't have the requested method, it implicitly calls tokenlist:renderLua () and tries to call the method on the result. This is particularly useful for calling string methods directly, such as gsub or others.

If `x` is a tokenlist `#{x:gsub ("a", "b")}` is the same as `#{x:render():gsub ("a", "b")}`

## `tokenlist+tokenlist`, `tokenlist-tokenlist`, ...

For all calculation metamethods (including concatenation), Plume will implicitly call `:render()` on each operand and attempt to convert them before performing the calculation.

If `x` and `y` are tokenlists, this allows you to write `#{x+y}` instead of `#{tonumber(x:render()) + tonumber(y:render())}`.

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


## `tokenlist:is_empty ()`

**Description:** Renders token list and checks if its length is 0.