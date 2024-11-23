#### 0.11.1
### Changes
- Plume will no longer print output by default.
- Rewrite the Linux launcher. You can choose the Lua executable by setting the `LUA_EXEC` environnement variable.

### Bugfix
- Fix a bug specific to Linux.
- Fix an error occurring when trying to open a file in the same folder.
- Fix an error occurring when giving an unknown flag to the eval macro.

#### 0.10.0

### Changes
- As planned, remove compatibilty for old syntax `#` and `\\`
- As planned, remove compatibilty for old configuration `config.ignore_spaces`


### 0.9.0

#### Changes
- Plume is no longer a standalone Lua file.
- As planned, remove `\def`, `\defl`, `\def_local`, `\setl`, `\set_local`, `\default_local`, `\alias_local`, `\aliasl`, `\redef` and `\redef_forced`.

#### CLI

##### Changes
- New option `-c --config` to edit configuration before executing the file or the given code.

##### Enhancements
- Rewrite doc
- New tests specifics to CLI

##### Fixes
- No longer see the first error message for each error.
- Fixe an error preventing to see plume output.
- Error is now writted on stderr, not stdin.

### 0.8.0

#### Changes
- Can now use `${...}` in parameter names and parameter values.
- Configuration can now be local.
- `${...}[i]` will now round, not floor.
- New option for CLI: interactive mode
- New function `plume.is_called_by`.
- New function `plume.write`.
- New `plume.engine`
- Add a warning if using `#` or `//` instead of `$` and `\--`. Will be triggered in Lua code, ignore it in this case.
- Remove `plume._LUA_VERSION`. (the Lua version is already in `plume._VERSION`)
- Remove implicit render on `token.__eq`
- Remove access to the Lua table `arg` from plume.

#### Enhancement
- When an error occurs in a Lua-defined macro, the line will no longer be printed twice in the error message.
- Can now use comments inside optional parameter declaration.
- Better error message for syntax error in lua code.

#### Fixes
- Fix a bug causing `local_macro` and `lmacro` to be global.
- Fix a bug causing an eval block to be evaluated 3 times instead of once.

#### Deprecation
- `\def`, `\defl`, `\def_local`, `\setl`, `\set_local`, `\default_local`, `\alias_local`, `\aliasl`, `\redef` and `\redef_forced` will be removed in `v0.9`
- Old syntax `#` and `//` compatibility will be removed in `v0.10`.
- Non-lua block as parameter of `\if`, `\elseif`, `\for` and `\while` will no longer be accepted in `v0.11`.

### 0.7.0

#### Changes
- Default space mode is now `light`.
- Rework a lot of naming:
    - `\def` became `\macro`.
    - The convention for local variant of `\command` is `\local_command`, with an alias `\lcommand`.
    - All old names (`\def`, `\defl`, `\def_local`, `\setl`, `\set_local`, `\default_local`, `\alias_local`, and `\aliasl`) are deprecated, but work for now.
- Deprecate `\redef` and `\redef_forced`. Writing over existing macros will now just print a warning.
- The first parameter of `\if`, `\elseif`, `\for`, and `\while` must now be an eval block.
- You can now declare a Plume block inside a Lua block. (only works inside `plume` files for now, not in external Lua files)
- Change eval escape to `$` from `#`. Code using `#` still works for now.
- Change comment syntax to `\--` from `//`. Code using `//` still works for now.
- New option `join` for `\for`, which will insert a character between all iterations.
- `${x}` will now render all `x` elements if `x` is a table.
- New flag `no_table_join` and new option `join` for macro `$`.

_Explanations for the syntaxs changes:_

Originally, `#` was chosen to adhere to the LaTeX macro syntax, `\newcommand \double[1] {#1 #1}`. However, it doesn't necessarily align with the broader use that Plume makes of it. Moreover, `#` is used by Lua, which makes some expressions unclear (e.g., `#{#t}` to print the size of a table) and prevents it from being used to declare `plume` blocks inside `lua` blocks. Finally, `$` is much more associated with the `evaluate` function than `#`.

As for comments, the idea was to reduce the number of special characters to two in order to avoid the need for escaping as much as possible. (For example, `//` is used in URLs). So, start with `\`. It couldn't be `\\` (because it prints the character `\`) and `\$` was pretty weird, so `\--` was chosen in alignment with the `--` used by Lua. 

#### Enhancement
- Plume comment will now work in Lua blocks.
- Remove useless lines from traceback.
- Warnings will be printed only one time per faulty code chunk.

#### Fixes
- Fix wrong space mode name.
- Plume no longer see `a==4` as a statement.
- Fix an error causing Plume to crash if a for loop go over the iteration limit.

### 0.6.1

#### Enhancement
- When giving an unknown parameter to a macro, the debug message proposes some close words that could be valid parameters.
- Now auto-detect lua code like `a, b = 1, 2` as statement, and not expression. Improve comment detection to force statement interpretation.

#### Fixes
- Fix some cli errors.
- Fix an error causing the plume to always search for the default value of parameters in the last scope instead of in the scope of the evaluated token.
- Fix a case when unnecessary `0`s will not be removed by `#`, even with the option `remove_zeros`.


### 0.6.0

### Changes
- Rework macros parameters into positionals/keywords/flags.
- Using an unknown parameter name will now raise an error.
- Due to the change, remove `script` without waiting for `1.0`.
- The functions `set` and `setl` are no longer deprecated.
- `set` and `setl` no longer perform implicit conversion on the fly.
- Remove `local` option for `set` and `alias`.
- New macros `set_local`, `alias_local`, and `def_local` (alias for `setl`, `aliasl` and `defl`).
- New macro `default_local`.
- New function `plume.export_local`.
- `light` space mode became `compact`. New space mode `light`.
- Add new error when using wrong syntax inside optional parameter declarations, instead of crashing.
- `__file_args` became `__file_params`.
- New macro special variable `__message`, used to achieve behavior like `\if {} \else {}`.
- New `_G` and `_L` tables.

### Fixes
- Fix CLI error on params numbering

### 0.5.0

#### Changes
- Macros now use scopes, like variables. (but cannot be accessed from plume script)
- New macro `\defl`.
- New macro `\deprecate`
- New option `local` for `\alias`. New macro `\aliasl`
- Remove access to macro local variables from other macros called inside.
- `#` can now be use for statement, not only for expression.
- Macros `set`, `setl` and `script` deprecated. Will be removed in `1.0`.
- New option `silent` for `#`.
- Documentation for predefined macros is now generated from source.
- Documentation for configuration is now generated from source.
- Documentation for api is now generated from source.
- Documentation for `tokenlist` is now generated from source.
- Configuration `plume.config.ignore_spaces` deprecated. Will be removed in `1.0`.
- New configuration `plume.config.filter_spaces`, and `plume.config.filter_newlines`.
- New macro `set_space_mode`

#### Fixes
- Preventing somme infinite loop when use `#` inside `\default eval`

### 0.4.0

#### Changes
- Create one `plume.lua` file per Lua version.
- Add error message (instead of crash) for wrong type in operation on token with implicit rendering.
- Add error message (instead of crash) for errors in external Lua files.
- Add error message (instead of crash) for unexpected errors inside plume code.
- Prevent implicit rendering from calling keys on numbers, or non-string methods on strings.
- Add an error if user try to render a nil code.
- Rename `api.getl` to `api.lget` to avoid confusion with `api.setl`. (`l` stands for "Lua" for one, "local" for the other).
- New `token:is_empty ()`
- New `api.export ()`

#### Fixes
- Fix implicit rendering not working with string methods.
- Fix `token.__unm` not working.
- Fix an error occurring when there are comments between `\if` and `\else`.

### 0.3.2

#### Fixes
- A lot of scope error fixes


### 0.3.1

#### Fixes
- Fix old code in `api.require`
- Fix parsing error in the macro `\for`
- Fix scope non closing in the macro `\for`
- Fix an error occurring when using a local variable in a macro used as a parameter of another macro.
- Fix a case where scope won't be frozen.

### 0.3.0

#### Changes
- Remove macro chain call: `\foo \foo x` will no longer be equivalent to `\foo {\foo x}`, but will raise an error. However, `\foo #{x}` still works.
- The `\script` macro can no longer return a value.
- Implement closures.
- Add one scope per loop iteration.
- No need to escape `[` and `]` anymore outside of a macro call.
- Local variables of `\script` will be captured, so there's no need for `plume.set_local` anymore.
- Change file searching behavior.
- New macro `\do`
- New `api.open`
- Remove `plume.set_local`.

#### Fixes
- Fix an error causing development sections to be included in the final code.
- Fix an error where calling methods on `tokenlist` via implicit call to `render` doesn't work.
- Fix an error when calling a macro as an argument of another macro with the same name.
- Fix an error causing Lua caching to not work at all.
- Fix an error causing the `setl` macro to not work at all.
- Fix an error where the character `\` doesn't display if it appears alone at the start of the line.

### 0.2.0

#### Changes
- Replace `\include[extern]` by `\extern`
- Remove `extern` option for `\include`
- Can give argument to included files.
- Can call any method and almost any metamethod on tokenlist via implicit call to `render`.
- Alias cannot erase existing macros.
- `\config` second argument isn't converted automaticaly anymore.

### 0.1.0

Initial release