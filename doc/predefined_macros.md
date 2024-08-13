# Predefined macros

## Controls

### `\for`

**Description:** Implements a custom iteration mechanism that mimics Lua's for loop behavior.

**Parameters:**
- _iterator_: A Lua iterator syntax, such as `i=1, 10` or `foo in pairs(t)`.
- _body_: Any Plume block that will be repeated.

**Example:**

```plume
\for {i=1, 10} {
    Line number #i.
}
```

### `\while`
**Description:** Implements a custom iteration mechanism that mimics Lua's while loop behavior.

**Parameters:**
- _condition_: Any Lua expression.
- _body_: Any Plume block.

**Example:**

```plume
\set i 100
\while {i>10} {
    \set i #{i-1}
}
```

### `\if`
**Description:** Implements a custom condition mechanism that mimics Lua's if behavior.

**Parameters:**
- _condition_: Any Lua expression.
- _body_: Any Plume block.

**Example:**

```plume
\set i 3
\if {i==4} {
    foo
}
```

### `\else`
**Description:** Implements a custom condition mechanism that mimics Lua's else behavior.

**Parameters:**
- _body_: Any Plume block.

**Notes:** Must follow an `\if` or an `\elseif` macro; otherwise, it will raise an error.

**Example:**

```plume
\set i 3
\if {i==4} {
    foo
}
\else {
    bar
}
```

### `\elseif`

**Description:** Behaves exactly like `\if`, but must follow an `\if` or an `\elseif` macro.

## Files

### Note on Path Searching

When using `\require` or `\include`, Plume will search for file in theses folder :

- First next to the file where `\require` or `\include` was called.
- Then to the file, if exist, that included the file calling  `\require` or `\include`.
- Then the previous path...
- Then in the "lib" folder next to `plume.lua`

If using `\require`, Plume will automatically search for file:
- With the exact name
- With the exact name followed by ".lua"
- With the name "init.lua" inside the folder with given name.

Same `\include` with ".plume" instead of ".lua".


### `\require`

**Description:** Executes a Lua file in the current scope.

**Parameters:**
- _path_: Path of the Lua file.

**Note:** See _Note on Path Searching_ above.

**Notes:** Unlike the Lua `require` function, `\require` does not perform any caching.

### `\include`

**Description:** Includes an external file.

**Parameters:**
- _path_: Path of the file to include.

**Optional Keywords:**
- _extern_: If provided, the file will not be executed but included as raw text.

**Note:** See _Note on Path Searching_ above.

**Example:**

```plume
\include {mylib} // will import mylib.plume
\include[extern] {style.css} // no need to escape all CSS brackets
```

### `\file`

**Description:** Saves the content to a file.

**Parameters:**
- _path_: Path of the output file.
- _body_: Block to write.

**Example:**

```plume
\file {output.txt} {
    foo
}
```

This will create a file named `output.txt` and write `foo` inside.

## Script

### `\script`

**Description:** Executes a Lua chunk in the current context. Any returned value will be added to the output. Returning a value is optional.

**Parameters:**
- _code_: Lua chunk to execute.

**Notes:**
- Local Lua variables are local to the chunk and cannot be accessed outside.
- Global Lua variables can be accessed from anywhere outside.
- You can define variables local to the current Plume scope with `plume.set_local(key, value)`.

**Example:**

```plume
\script {
    local a = 0
    a = a + 1
    return a
}
```

Output: `1`.

### `\eval`

**Description:** Evaluates and returns the given Lua expression.

**Parameters:**
- _code_: Lua expression to evaluate.

**Alias:**
- `\#{...}` is equivalent to `\eval {...}`
- `\#x+1` is equivalent to `\eval {x}+1`

```plume
\set x #{35 + 1 * 2}
```

## Spaces

### `\n`

**Description:** Returns a newline character.

### `\s`

**Description:** Returns a space character.

### `\t`

**Description:** Returns a tabulation character.

## Utils

### `\def`, `\redef`, `\redef_forced`

**Description:** Defines a new macro.

**Parameters:**
- _name_: Macro name.
- _body_: Body of the macro.

**Optional Parameters:** Any parameter with a value defines an optional parameter for the macro, with the given default value.

**Optional Keywords:** Any given keyword will declare a new argument for the defined macro.

**Notes:**
- The name argument will be rendered, allowing you to dynamically define macros.
- `\def` works only if the name isn't already taken.
- `\redef` works only to erase a user-defined name (not for erasing Plume predefined macros).
- `\redef_forced` works in any case.

**Example:**

```plume
\def foo[x y bar=baz] {
    x: #x, y: #y, bar: #bar
}
\foo {a} {b}
\foo[bar=bar] {} {}
```

Output: 
```
a b baz
bar
```

### `\set`

**Description:** Sets a variable to a value.

**Parameters:**
- _name_: Variable name.
- _value_: Variable value.

**Optional Keywords:**
- _local_: If provided, the variable will be local to the current scope.

**Alias:**
- `\setl` is an alias for `\set[local]`

**Notes:**
- The value will be saved as a number (if possible), otherwise as a string unless the value is an `\eval` block. In that case, it will be saved as a Lua object.

### `\setl`

**Description:** An alias for `\set[local]`.

### `\alias`

**Description:** Copies a macro to a new name.

**Parameters:**
- _name_: Name of the macro to copy.

**Notes:**
- The macro is passed by reference, so editing it changes the alias as well. However, deleting one doesn't delete the other.

### `\raw`
**Description:** Returns content as raw text.

**Parameters:**
- _content_: Content to return without execution.

**Notes:**
- This macro is convenient for new users but isn't hard to define on its own: `\def raw[x]{#{x:source()}}`

**Example:**

```plume
\raw{\def foo bar}
```

Output: 
```
\def foo bar
```

### `\config`
**Description:** Edits configuration settings.

**Parameters:**
- _key_: Name of the parameter to edit.
- _value_: New value of the parameter.

**Notes:**
- Almost equivalent to `\script{plume.config.variable_name = value}`, except `\config` will raise an error if the key isn't a known parameter name.
- If the value is a number, "true", "false", or "nil", it will be converted.

**List of Parameters:**

| Name                  | Default Value | Notes |
| --------------------- | ------------- |----------- |
| max_callstack_size    | 100           | Maximum number of nested macros. Intended to prevent infinite recursion errors such as `\def foo {\foo}`|
| max_loop_size         | 1000          | Maximum number of loop iterations for `\while` and `\for` macros.|
| ignore_spaces         | false         | New lines and leading spaces in the processed file will be ignored. Consecutive spaces are rendered as one. To add spaces in the final file in this case, use the `\s` (space), `\t` (tab), and `\n` (newline) macros. |

### `\default`
**Description:** Edits the default value of optional macro arguments.

**Parameters:**
- _name_: Name of the macro to edit.

**Optional Parameters:**
- Any pairs of `key=value` will be saved as defaults for the given macro.