# Plume API
_Generated from source._

Méthodes et variables Lua accessibles in any `#` macro.

## Variables

| Name |  Description |
| ----- | ----- |
| `__args` | When inside a macro, contain all macro-given parameters, use `ipairs` to iterate over them. Contain also provided flags as keys.|
| `__file_args` | Work as `__args`, but inside a file imported by using `\include` |
| `plume._VERSION` |  Version of plume. |
| `plume._LUA_VERSION` |  Lua version compatible with this plume distribution. |
| `plume.input_file` |  If use in command line, path of the input file. |
| `plume.output_file` |  Name of the file to output execution result. If set to none, don't print anything. Can be set by command line. |

## Methods



### capture_local

**Usage :** `plume.capture_local()`

**Description:**  Capture the local _lua_ variable and save it in the _plume_ local scope. This is automatically called by plume at the end of `#` block in statement-mode.

**Note:** Mainly internal use, you shouldn't use this function.

### open

**Usage :** `file, founded_path = plume.open(path, open_mode, silent_fail)`

**Description:**  Searches for a file using the [plume search system](macros.md#include) and open it in the given mode. Return the opened file and the full path of the file.

**Parameters :**
- `path` _string_  The path where to search for the file.
- `open_mode` _string_ Mode to open the file. _(optional, default `"r"`)_
- `silent_fail` _boolean_ If true, the search will not raise an error if no file is found. _(optional, default `false`)_

**Return:**
- `file`The file found during the search, opened in the given mode.
- `founded_path`The path of the file founded.

### get

**Usage :** `value = plume.get(key)`

**Description:**  Get a variable value by name in the current scope.

**Parameters :**
- `key` _string_  The variable name.

**Return:** `value`The required variable.

**Note:** `plume.get` may return a tokenlist, so may have to call `plume.get (name):render ()` or `plume.get (name):renderLua ()`. See [get_render](#get_render) and [get_renderLua](#get_renderLua).

### get_render

**Usage :** `value = plume.get_render(key)`

**Description:**  Get a variable value by name in the current scope. If the variable has a render method (see [render](#tokenlist.render)), call it and return the result. Otherwise, return the variable.

**Parameters :**
- `key` _string_  The variable name

**Return:** `value`The required variable.

**Alias :** `plume.getr`

### lua_get

**Usage :** `value = plume.lua_get(key)`

**Description:**  Get a variable value by name in the current scope. If the variable has a renderLua method (see [renderLua](#tokenlist.renderLua)), call it and return the result. Otherwise, return the variable.

**Parameters :**
- `key` _string_  The variable name

**Return:** `value`The required variable.

**Alias :** `plume.lget`

### require

**Usage :** `lib = plume.require(path)`

**Description:**  Works like Lua's require, but uses Plume's file search system.

**Parameters :**
- `path` _string_  Path of the lua file to load

**Return:** `lib`The require lib

### export

**Usage :** `plume.export(name, arg_number)`

**Description:**  Create a macros from a lua function.

**Parameters :**
- `name` _string_  Name of the macro
- `arg_number` _Number_  of arguments to capture

## Tokenlist

Tokenlists are Lua representations of Plume structures. `plume.get` will often return `tokenlists`, and macro arguments are also `tokenlists`.