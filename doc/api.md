# Plume API
_Generated from source._

Méthodes et variables Lua accessibles in any `$` macro.

## Variables

| Name |  Description |
| ----- | ----- |
| `__file_params` | Work as `__params`, but inside a file imported by using `\\include` |
| `__params` | When inside a macro with a variable paramter count, contain all excedents parameters, use `pairs` to iterate over them. Flags are both stocked as key=value (`__params.some_flag = true`) and table indice. (`__params[1] = "some_flag"`| |
| `__message` | Used to implement if-like behavior. If you give a value to `__message.send`, the next macro to be called (in the same block) will receive this value in `__message.content`, and the name for the last macro in `__message.sender`  |
| `_G` | Globale table of variables. |
| `_L` | Local table of variables. |
| `plume._VERSION` |  Version of plume. |
| `plume._LUA_VERSION` |  Lua version compatible with this plume distribution. |
| `plume.input_file` |  If use in command line, path of the input file. |
| `plume.output_file` |  Name of the file to output execution result. If set to none, don't print anything. Can be set by command line. |

## Methods



### capture_local

**Usage :** `plume.capture_local()`

**Description:**  Capture the local _lua_ variable and save it in the _plume_ local scope. This is automatically called by plume at the end of `$` block in statement-mode.

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

**Description:**  Get a variable value by name in the current scope. If the variable has a render method (see [render](#render)), call it and return the result. Otherwise, return the variable.

**Parameters :**
- `key` _string_  The variable name

**Return:** `value`The required variable.

**Alias :** `plume.getr`

### lua_get

**Usage :** `value = plume.lua_get(key)`

**Description:**  Get a variable value by name in the current scope. If the variable has a renderLua method (see [renderLua](#renderLua)), call it and return the result. Otherwise, return the variable.

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

**Usage :** `plume.export(name, arg_number, is_local)`

**Description:**  Create a macro from a lua function.

**Parameters :**
- `name` _string_  Name of the macro
- `arg_number` _Number_  of paramters to capture
- `is_local` _bool_  Is the new macro local?

### export_local

**Usage :** `plume.export_local(name, arg_number, is_local)`

**Description:**  Create a local macro from a lua function.

**Parameters :**
- `name` _string_  Name of the macro
- `arg_number` _Number_  of paramters to capture
- `is_local` _bool_  Is the new macro local?

### check_inside

**Usage :** `bool = plume.check_inside(name)`

**Description:**  Check if we are inside a given macro

**Parameters :**
- `name` _string_  the name of the macro

**Return:** `bool`True if we are inside a macro with the given name, false otherwise.

### __newindex

**Usage :** `file, founded_path, value, value, value, lib, bool = plume.__newindex(path, key, key, key, path, name, arg_number, is_local, name, arg_number, is_local, name, open_mode, silent_fail)`

**Description:**  Capture the local _lua_ variable and save it in the _plume_ local scope. This is automatically called by plume at the end of `$` block in statement-mode.

**Parameters :**
- `path` _string_  The path where to search for the file.
- `key` _string_  The variable name.
- `key` _string_  The variable name
- `key` _string_  The variable name
- `path` _string_  Path of the lua file to load
- `name` _string_  Name of the macro
- `arg_number` _Number_  of paramters to capture
- `is_local` _bool_  Is the new macro local?
- `name` _string_  Name of the macro
- `arg_number` _Number_  of paramters to capture
- `is_local` _bool_  Is the new macro local?
- `name` _string_  the name of the macro
- `open_mode` _string_ Mode to open the file. _(optional, default `"r"`)_
- `silent_fail` _boolean_ If true, the search will not raise an error if no file is found. _(optional, default `false`)_

**Return:**
- `file`The file found during the search, opened in the given mode.
- `founded_path`The path of the file founded.
- `value`The required variable.
- `value`The required variable.
- `value`The required variable.
- `lib`The require lib
- `bool`True if we are inside a macro with the given name, false otherwise.

**Notes:**
- Mainly internal use, you shouldn't use this function.
- `plume.get` may return a tokenlist, so may have to call `plume.get (name):render ()` or `plume.get (name):renderLua ()`. See [get_render](#get_render) and [get_renderLua](#get_renderLua).

**Alias :** `plume.lget`

## Tokenlist

Tokenlists are Lua representations of Plume structures. `plume.get` will often return `tokenlists`, and macro arguments are also `tokenlists`.

In addition to the methods listed below, all operations that can be supercharged have also been supercharged. So, if `x` and `y` are two tokenlists, `x + y` is equivalent to `x:render() + y:render()`.

In the same way, if you call all `string` methods on a tokenlist, the call to `render` will be implicit: `tokenlist:match(...)` is equivalent to `tokenlist:render():match(...)`.

### Members
- `tokenlist.__type` :  Type of the table. Value : `"tokenlist"`
- `tokenlist.kind` :  Kind of tokenlist. Can be : `"block"`, `"opt_block"`, `"block_text"`, `"render-block"`.
- `tokenlist.context` :  The scope of the tokenlist. If set to false (default), search vars in the current scope.
- `tokenlist.lua_cache` :  For eval tokens, cached loaded lua code.
- `tokenlist.opening_token` :  If the tokenlist is a "block" or an "opt_block",keep a reference to the opening brace, to track token list position in the code.
- `tokenlist.closing_token` :  If the tokenlist is a "block" or an "opt_block",keep a reference to the closing brace, to track token list position in the code.

### render

**Usage :** `output = tokenlist:render()`

**Description:**  Get tokenlist rendered.

**Return:** `output`The string rendered tokenlist.

### renderLua

**Usage :** `lua_objet = tokenlist:renderLua()`

**Description:**  Get tokenlist rendered. If the tokenlist first child is an eval block, evaluate it and return the result as a lua object. Otherwise, render the tokenlist.

**Return:** `lua_objet`Result of evaluation

### get_line

**Usage :** `string, string, boolean, bool, string = tokenlist:get_line(source, noline)`

**Description:**  Returns the raw code of the tokenlist, as is writed in the source file.

**Parameters :**
- `source` _string_  The source code
- `noline` _number_  The line number to retrieve

**Return:**
- `string`The source code
- `string`The source code
- `boolean`Returns true if the block is an evaluation block, false otherwise
- `bool`Is the tokenlist empty?
- `string`The line at the specified line number

### source

**Usage :** `string = tokenlist:source()`

**Description:**  Returns the raw code of the tokenlist, as is writed in the source file.

**Return:** `string`The source code

### sourceLua

**Usage :** `string = tokenlist:sourceLua()`

**Description:**  Get lua code as writed in the code file, after deleting comment and insert plume blocks.

**Return:** `string`The source code

### is_eval_block

**Usage :** `boolean = tokenlist:is_eval_block()`

**Description:**  Determines if the block is an evaluation block (like `${1+1}`)

**Return:** `boolean`Returns true if the block is an evaluation block, false otherwise

### is_empty

**Usage :** `bool = tokenlist:is_empty()`

**Description:**  Render the tokenlist and return true if it is empty

**Return:** `bool`Is the tokenlist empty?

## Tokenlist - intern methods

The user have access to theses methods, but shouldn't use it.

### get_line

**Usage :** `debug_info, tokenlist, string, string, boolean, bool, string = tokenlist:get_line(scope, forced, source, noline)`

**Description:**  Return debug informations about the tokenlist.

**Parameters :**
- `scope` _table_  The scope to freeze.
- `forced` _boolean_  Force to re-freeze already frozen children?
- `source` _string_  The source code
- `noline` _number_  The line number to retrieve

**Return:**
- `debug_info`A table containing fields : `file`, `line` (the first line of this code chunck), `lastline`, `pos` (first position of the code in the first line), `endpos`, `code` (The full code of the file).
- `tokenlist`The copied tokenlist.
- `string`The source code
- `string`The source code
- `boolean`Returns true if the block is an evaluation block, false otherwise
- `bool`Is the tokenlist empty?
- `string`The line at the specified line number

### info

**Usage :** `debug_info = tokenlist:info()`

**Description:**  Return debug informations about the tokenlist.

**Return:** `debug_info`A table containing fields : `file`, `line` (the first line of this code chunck), `lastline`, `pos` (first position of the code in the first line), `endpos`, `code` (The full code of the file).

### set_context

**Usage :** `tokenlist:set_context(scope, forced)`

**Description:**  Freezes the scope for all tokens in the list.

**Parameters :**
- `scope` _table_  The scope to freeze.
- `forced` _boolean_  Force to re-freeze already frozen children?