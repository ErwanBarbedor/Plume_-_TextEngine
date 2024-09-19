<p align="center"><img src="dist/plume.png" width="600" height="300"></p>

![Version](https://img.shields.io/badge/version-0.5.0-blue.svg) [![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

## Introduction

Programming languages like Python and Lua enable the implementation of complex logic with relative ease. However, working with text input can often be tedious due to cumbersome syntax.

While there are formats that facilitate enriched text writing, such as Markdown or Jinja, they tend to have limited logical capabilities.

Plume's philosophy is to combine the best of both worlds: text input is at the core of its design, yet the integration of logic is seamless, thanks to its close relationship with the Lua scripting language.

To illustrate, consider the task of generating ten files, each containing a multiplication table for a specific number. This can certainly be achieved in Python or Lua, but of Plume offers a more intuitive approach:

```plume
\for {i=1,10} {
    \file {table-#i.txt} {
        \for {j=1,10}{
            #i * #j = #{i*j}
        }
    }
}
```

## Quick Start

You can test plume in [your browser](https://app.barbedor.bzh/plume.html). 

Plume requires Lua to run. It has been tested with Lua versions 5.x and LuaJIT. You just need to download the file corresponding to your installed Lua version. For example, for Lua 5.4: [dist/Lua 5.4/plume.lua](dist/5.4/plume.lua).

Write the following in a file `input.plume`:

```plume
\def table[x] {
    \for {i=1, 10} {
        #x * #i = #{x*i}
    }
}
\table {3}
```

Then, in a command console, execute:

```bash
lua plume.lua -p input.plume
```

This runs the `input.plume` file and you should see the multiplication table of 3 in your console.

To save this result to the `output.txt` file, run:

```bash
lua plume.lua -o output.txt input.plume
```

You can also write your `input.plume` like this:

```plume
\table[x] {
    ...
}
\file {output.txt} {
    \table{3}
}
```

And just call:

```bash
lua plume.lua input.plume
```

_Of course, with this method you can output several files._

For a list of available options, use:

```
> lua plume.lua -h
Usage:
    plume INPUT_FILE
    plume --print INPUT_FILE
    plume --output OUTPUT_FILE INPUT_FILE
    plume --version
    plume --help

Options:
  -h, --help          Show this help message and exit.
  -v, --version       Show the version of plume and exit.
  -o, --output FILE   Write the output to FILE
  -p, --print         Display the result
```

## Learn More

To find out more about Plume, you can consult:
- [An overview of its main functions](doc/overview.md)
- [More advanced points](doc/advanced.md)
- Full documentation on predefined [macros](doc/macros.md) and  [functions/tables](doc/api.md).

You can also [read more about lua](https://www.lua.org/pil/1.html)

## Warnings for LaTeX Users

The syntax is quite similar to that of LaTeX, but Plume behaves very differently.

For exemple, in LaTeX, you can define a macro like this: `\newcommand {\foo} {bar}`, because `newcommand` will be expanded _before_ `foo`.

This doesn't work in Plume because `foo` will be expanded first.

## Changelog

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
- Documentation for predefined macros and documentation is now generated from source.
- Configuration `plume.config.ignore_spaces` deprecated.
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

## License

This project is licensed under the GNU General Public License (GNU-GPL). This means that you are free to use, modify and redistribute the source code. However, if you distribute a modified version, you must also do so under the same license. 

