# Predefined macros

## Controls

### `\for`

**Description:** Implements a custom iteration mechanism that mimics Lua's for loop behavior.

**Parameters:**
- _iterator_: A Lua iterator syntax, such as `i=1, 10` or `foo in pairs(t)`.
- _body_: Any Plume block that will be repeated.

**Note:** Each iteration has it's own scope.

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

**Note:** Each iteration has it's own scope.

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

### `\do`

**Description:** Create a scope and execute `body` inside.

**Parameters:**
- _body_: Any Plume block.

## Files

### Note on Path Searching

When using `\require` or `\include`, Plume will search for the file by tracing back through the traceback. Essentially, it retrieves the parent directory of the file where the last macro was called and checks if the requested file is found there. If it doesn't work, it moves to the previous macro, and so on, until the entire traceback is exhausted.


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

**Description:** Includes and execute an external file.

**Parameters:**
- _path_: Path of the file to include.

**Notes:**
- See _Note on Path Searching_ above.
- All optionnal arguments are stored in a `__file_args` table accessible from the imported file.

**Example:**

```plume
\include {mylib} // will import mylib.plume
```

### `\extern`

**Description:** Includes an external file without execution.

**Parameters:**
- _path_: Path of the file to include.

**Note:** See _Note on Path Searching_ above.

**Example:**

```plume
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

**Description:** Executes a Lua chunk in the current context. You cannot return value.

**Parameters:**
- _code_: Lua chunk to execute.

**Note:** Global and local _lua_ variables are seamlessly equivalent to global and local _plume_ variables.

**Example:**

```plume
\script {
    a = 0
}
#a
```

Output: `0`.

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

```plume
#{4/3}[i]
#{1/3}[.4f]
#{10000}[thousand_separator=,]
#{5/2}[decimal_separator=+0.]
#{5327}[%.2s]
```
Output:
```
1
0.3333
10,000
2+0.5
5.32E3
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

### `\ldef`

**Description:** Defines a new macro, local to the current scope. Dont do any check.

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
- _base_name_: Name of the macro to copy.
- _alias_name_: Name of the alias.

**Notes:**
- The macro is passed by reference, so editing it (like using `\default`) changes the alias as well. However, `\redef` one doesn't affect the other.

### `\raw`
**Description:** Returns content as raw text.

**Parameters:**
- _content_: Content to return without execution.

**Notes:**
- This macro is convenient for clarity but isn't hard to define on its own: `\def raw[x]{#{x:source()}}`

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
- `\config {variable_name} #{value}` is almost equivalent to `\script{plume.config.variable_name = value}`, except `\config` will raise an error if the key isn't a known parameter name.
- If the value is a number, "true", "false", or "nil", it will be converted.

**List of Parameters:**

| Name                  | Default Value | Notes |
| --------------------- | ------------- |----------- |
| max_callstack_size    | 100           | Maximum number of nested macros. Intended to prevent infinite recursion errors such as `\def foo {\foo}`|
| max_loop_size         | 1000          | Maximum number of loop iterations for `\while` and `\for` macros.|
| ignore_spaces         | false         | New lines and leading spaces in the processed file will be ignored. Consecutive spaces are rendered as one. To add spaces in the final file in this case, use the `\s` (space), `\t` (tab), and `\n` (newline) macros. |
| show_deprecation_warnings | true ||

### `\default`
**Description:** Edits the default value of optional macro arguments.

**Parameters:**
- _name_: Name of the macro to edit.

**Optional Parameters:**
- Any pairs of `key=value` will be saved as defaults for the given macro.

Exemple:
```plume
\def foo[bar=bar] {#bar}
\foo
\default foo[bar=baz]
\foo
```
Ouputs
```plume
bar
baz
```