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