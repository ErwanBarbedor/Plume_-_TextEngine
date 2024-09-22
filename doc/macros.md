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

**Other optional parameters:** Any argument will be accessible from the included file, in the field `__file_args`.

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

## Eval

### eval

**Usage:** `\eval[thousand_separator={} decimal_separator=. <format> remove_zeros silent] {code}`

**Description:** Evaluate the given expression or execute the given statement.

**Parameters:**
- `code` The code to evaluate or execute.

**Optional keyword parameters** (_Theses argument are used with a keyword, like this : `\foo[bar=baz]`._)
- `thousand_separator` Symbol used between groups of 3 digits.Default value : empty
- `decimal_separator` Symbol used between the integer and the decimal part.Default value : `.`

**Optional positional parameters** (_Theses argument are used without keywords, like this : `\foo[bar]`._) 
1. `format` Only works if the code returns a number. If set to `i`, the number is rounded. If set to `.2f`, it will be output with 2 digits after the decimal point. If set to `.3s`, it will be output using scientific notation, with 3 digits after the decimal point..

**Flags** (_Flags are optional positional arguments with one value. Behavior occurs when this argument is present._)
- `remove_zeros` Remove useless zeros (e.g., `1.0` becomes `1`).
- `silent` Execute the code without returning anything. Useful for filtering unwanted function returns: `#{table.remove(t)}[silent]`

**Notes:**
- If the given code is a statement, it cannot return any value.
- If you use eval inside default parameter values for eval, like `\default eval[{#format}]`, all parameters of `#format` will be ignored to prevent an infinite loop.
- In some case, plume will treat a statement given code as an expression. To forced the detection by plume, start the code with a comment.

**Alias:** `#{1+1}` is the same as `\eval{1+1}`

## Spaces

### n

**Usage:** `\n[<n>]`

**Description:** Output a newline.

**Optional positional parameters** (_Theses argument are used without keywords, like this : `\foo[bar]`._) 
1. `n` Number of newlines to output..

**Note:** Don't affected by `plume.config.filter_spaces` and `plume.config.filter_newlines`.

### s

**Usage:** `\s[<n>]`

**Description:** Output a space.

**Optional positional parameters** (_Theses argument are used without keywords, like this : `\foo[bar]`._) 
1. `n` Number of spaces to output..

**Note:** Don't affected by `plume.config.filter_spaces` and `plume.config.filter_newlines`.

### t

**Usage:** `\t[<n>]`

**Description:** Output a tabulation.

**Optional positional parameters** (_Theses argument are used without keywords, like this : `\foo[bar]`._) 
1. `n` Number of tabs to output..

**Note:** Don't affected by `plume.config.filter_spaces` and `plume.config.filter_newlines`.

### set_space_mode

**Usage:** `\set_space_mode {mode}`

**Description:** Shortand for common value of `plume.config.filter_spaces` and `plume.config.filter_newlines` (see [config](config.md)).

**Parameters:**
- `mode` Can be `normal` (take all spaces), `no_spaces` (ignore all spaces), `compact` (replace all space/tabs/newlines sequence with " ") and `light` (replace all space sequence with " ", all newlines block with a single `\n`)

## Utils

### def

**Usage:** `\def[...] {name} {body}`

**Description:** Define a new macro.

**Parameters:**
- `name` Name must be a valid lua identifier
- `body` Body of the macro, that will be render at each call.

**Other optional parameters:** Macro arguments names.

**Note:** Doesn't work if the name is already taken by another macro.

### redef

**Usage:** `\redef[...] {name} {body}`

**Description:** Redefine a macro.

**Parameters:**
- `name` Name must be a valid lua identifier
- `body` Body of the macro, that will be render at each call.

**Other optional parameters:** Macro arguments names.

**Note:** Doesn't work if the name is available.

### redef_forced

**Usage:** `\redef_forced[...] {name} {body}`

**Description:** Redefined a predefined macro.

**Parameters:**
- `name` Name must be a valid lua identifier
- `body` Body of the macro, that will be render at each call.

**Other optional parameters:** Macro arguments names.

**Note:** Doesn't work if the name is available or isn't a predefined macro.

### defl

**Usage:** `\defl[...] {name} {body}`

**Description:** Define a new macro locally.

**Parameters:**
- `name` Name must be a valid lua identifier
- `body` Body of the macro, that will be render at each call.

**Other optional parameters:** Macro arguments names.

**Note:** Contrary to `\def`, can erase another macro without error.

### alias

**Usage:** `\alias[local] {name1} {name2}`

**Description:** name2 will be a new way to call name1.

**Parameters:**
- `name1` Name of an existing macro.
- `name2` Any valid lua identifier.

**Flags** (_Flags are optional positional arguments with one value. Behavior occurs when this argument is present._)
- `local` Is the new macro local to the current scope.

**Alias:** `\aliasl` is equivalent as `\alias[local]`

### aliasl

**Usage:** `\aliasl {name1} {name2}`

**Description:** Make an alias locally

**Parameters:**
- `name1` Name of an existing macro.
- `name2` Any valid lua identifier.

**Alias:** `\aliasl` is equivalent as `\alias[local]`

### default

**Usage:** `\default[...] {name}`

**Description:** set (or reset) default args of a given macro.

**Parameters:**
- `name` Name of an existing macro.

**Other optional parameters:** Any parameters used by the given macro.

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