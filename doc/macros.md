# Macros documentation
_Generated from source._

## Controls

### for

**Usage:** `\for {iterator} {body}`

**Description:** Implements a custom iteration mechanism that mimics Lua's for loop behavior.

**Parameters:**
- `iterator` Anything that follow the lua iterator syntax, such as `i=1, 10` or `foo in pairs(t)`.
- `body` A block that will be repeated.

**Note:** Each iteration has it's own scope. The maximal number of iteration is limited by `plume.config.max_loop_size`. See [config](config.md) to edit it.

### while

**Usage:** `\while {condition} {body}`

**Description:** Implements a custom iteration mechanism that mimics Lua's while loop behavior.

**Parameters:**
- `condition` Anything that follow syntax of a lua expression, to evaluate.
- `body` A block that will be rendered while the condition is verified.

**Note:** Each iteration has it's own scope. The maximal number of iteration is limited by `plume.config.max_loop_size`. See [config](config.md) to edit it.

### if

**Usage:** `\if {condition} {body}`

**Description:** Implements a custom mechanism that mimics Lua's if behavior.

**Parameters:**
- `condition` Anything that follow syntax of a lua expression, to evaluate.
- `body` A block that will be rendered, only if the condition is verified.

### else

**Usage:** `\else {body}`

**Description:** Implements a custom mechanism that mimics Lua's else behavior.

**Parameters:**
- `body` A block that will be rendered, only if the last condition isn't verified.

**Note:** Must follow an `\if` or an `\elseif` macro; otherwise, it will raise an error.

### elseif

**Usage:** `\elseif {condition} {body}`

**Description:** Implements a custom mechanism that mimics Lua's elseif behavior.

**Parameters:**
- `condition` Anything that follow syntax of a lua expression, to evaluate.
- `body` A block that will be rendered, only if the last condition isn't verified and the current condition is verified.

**Note:** Must follow an `\if` or an `\elseif` macro; otherwise, it will raise an error.

### do

**Usage:** `\do {body}`

**Description:** Implements a custom mechanism that mimics Lua's do behavior.

**Parameters:**
- `body` A block that will be rendered in a new scope.

## Files

### require

**Usage:** `\require {path}`

**Description:** Execute a Lua file in the current scope.

**Parameters:**
- `path` Path of the file to require. Use the plume search system: first, try to find the file relative to the file where the macro was called. Then relative to the file of the macro that called `\require`, etc... If `name` was provided as path, search for files `name`, `name.lua` and `name/init.lua`.

**Note:** Unlike the Lua `require` function, `\require` macro does not perform any caching.

### include

**Usage:** `\include[...] {path}`

**Description:** Execute a plume file in the current scope.

**Parameters:**
- `path` Path of the file to include. Use the plume search system: first, try to find the file relative to the file where the macro was called. Then relative to the file of the macro that called `\require`, etc... If `name` was provided as path, search for files `name`, `name.plume` and `name/init.plume`.

**Other parameters:** Any argument will be accessible from the included file, in the field `__file_args`.

### extern

**Usage:** `\extern {path}`

**Description:** Insert content of the file without execution. Quite similar to `\raw`, but for a file.

**Parameters:**
- `path` Path of the file to include. Use the plume search system: first, try to find the file relative to the file where the macro was called. Then relative to the file of the macro that called `\require`, etc... 

### file

**Usage:** `\file {path} {note}`

**Description:** Render a plume chunck and save the output in the given file.

**Parameters:**
- `path` Name of the file to write.
- `note` Content to write in the file.

## Script

### script

**Usage:** `\script`

**Description:** Deprecated and will be removed in 1.0. You should use '#{...}' instead.

### eval

**Usage:** `\eval[remove_zeros={} thousand_separator={} decimal_separator=. format={}] {code}`

**Description:** Evaluate the given expression or execute the given statement.

**Parameters:**
- `code` The code to evaluate or execute.

**Optionnal parameters:**
- `remove_zeros` If set to anything not empty and the result is a number, remove useless zeros. (ex: 1.0 becomes 1)Default value : `{}`
- `thousand_separator` Symbol used between groups of 3 digits.Default value : `{}`
- `decimal_separator` Symbol used between the integer and the decimal part.Default value : `.`
- `format` Only works if the code returns a number. If set to `i`, the number is rounded. If set to `.2f`, it will be output with 2 digits after the comma. If set to `.3s`, it will be output using scientific notation, with 3 digits after the comma.Default value : `{}`

**Note:** If the given code is the statement, it cannot return any value.

**Alias:** `#{1+1}` is the same as `\eval{1+1}`

## Spaces

### n

**Usage:** `\n[n]`

**Description:** Output a newline.

**Optionnal parameters:**
- `n` Number of newlines to output.. It is not a keyword argument, you should use `\n[1]` and not `\n[n=1]`Default value : `1`

**Note:** Usefull if `plume.config.ignore_spaces` is set to `true`.

### s

**Usage:** `\s[n]`

**Description:** Output a space.

**Optionnal parameters:**
- `n` Number of spaces to output.. It is not a keyword argument, you should use `\s[1]` and not `\s[n=1]`Default value : `1`

**Note:** Usefull if `plume.config.ignore_spaces` is set to `true`.

### t

**Usage:** `\t[n]`

**Description:** Output a tabulation.

**Optionnal parameters:**
- `n` Number of tabs to output.. It is not a keyword argument, you should use `\t[1]` and not `\t[n=1]`Default value : `1`

**Note:** Usefull if `plume.config.ignore_spaces` is set to `true`.

## Utils

### def

**Usage:** `\def[...] {name} {body}`

**Description:** Define a new macro.

**Parameters:**
- `name` Name must be a valid lua identifier
- `body` Body of the macro, that will be render at each call.

**Other parameters:** Macro arguments names.

**Note:** Doesn't work if the name is already taken by another macro.

### redef

**Usage:** `\redef[...] {name} {body}`

**Description:** Redefine a macro.

**Parameters:**
- `name` Name must be a valid lua identifier
- `body` Body of the macro, that will be render at each call.

**Other parameters:** Macro arguments names.

**Note:** Doesn't work if the name is available.

### redef_forced

**Usage:** `\redef_forced[...] {name} {body}`

**Description:** Redefined a predefined macro.

**Parameters:**
- `name` Name must be a valid lua identifier
- `body` Body of the macro, that will be render at each call.

**Other parameters:** Macro arguments names.

**Note:** Doesn't work if the name is available or isn't a predefined macro.

### ldef

**Usage:** `\ldef[...] {name} {body}`

**Description:** Define a new macro locally.

**Parameters:**
- `name` Name must be a valid lua identifier
- `body` Body of the macro, that will be render at each call.

**Other parameters:** Macro arguments names.

**Note:** Contrary to `\def`, can erase another macro without error.

### set

**Usage:** `\set`

**Description:** Deprecated and will be removed in 1.0. You should use '#' instead.

### setl

**Usage:** `\setl`

**Description:** Deprecated and will be removed in 1.0. You should use '#' instead.

### alias

**Usage:** `\alias {name1} {name2}`

**Description:** name2 will be a new way to call name1.

**Parameters:**
- `name1` Name of an existing macro.
- `name2` Any valid lua identifier.

### default

**Usage:** `\default[...] {name}`

**Description:** set (or reset) default args of a given macro.

**Parameters:**
- `name` Name of an existing macro.

**Other parameters:** Any parameters used by the given macro.

### raw

**Usage:** `\raw {body}`

**Description:** Return the given body without render it.

**Parameters:**
- `body` 

### config

**Usage:** `\config {key} {value}`

**Description:** Edit plume configuration.

**Parameters:**
- `key` Name of the paramter.
- `value` New value to save.

**Note:** Will raise an error if the key doesn't exist. See [config](config.md) to get all available parameters.

### deprecate

**Usage:** `\deprecate {name} {version} {alternative}`

**Description:** Mark a macro as "deprecated". An error message will be printed each time you call it, except if you set `plume.config.show_deprecation_warnings` to `false`.

**Parameters:**
- `name` Name of an existing macro.
- `version` Version where the macro will be deleted.
- `alternative` Give an alternative to replace this macro.