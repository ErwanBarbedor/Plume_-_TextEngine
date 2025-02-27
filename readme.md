<p align="center"><img src="https://app.barbedor.bzh/plume.png" width="600" height="300"></p>

![Version](https://img.shields.io/badge/version-0.12.0-blue.svg) [![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

## Introduction

Programming languages like Python and Lua enable the implementation of complex logic with relative ease. However, working with text input can often be tedious due to cumbersome syntax.

While there are formats that facilitate enriched text writing, such as Markdown or Jinja, they tend to have limited logical capabilities.

Plume's philosophy is to combine the best of both worlds: text input is at the core of its design, yet the integration of logic is seamless, thanks to its close relationship with the Lua scripting language.

To illustrate, consider the task of generating ten files, each containing a multiplication table for a specific number. This can certainly be achieved in Python or Lua, but of Plume offers a more intuitive approach:

```plume
\for ${i=1,10} {
    \file {table-$i.txt} {
        \for ${j=1,10}{
            $i * $j = ${i*j}
        }
    }
}
```

## Quick Start

You can test plume in [your browser](https://app.barbedor.bzh/plume-0.11.html). 

Plume requires Lua to run. It has been tested with Lua versions 5.x and LuaJIT. Clone or download the repository.

Write the following in a file `input.plume` inside the `plume` folder:

```plume
\macro table[x] {
    \for ${i=1, 10} {
        $x * $i = ${x*i}
    }
}
\table {3}
```

Then, in a command console, execute:

**Windows**
```bash
plume -p input.plume
```

**Linux**
```bash
chmod +x plume
./plume -p input.plume
```

This runs the `input.plume` file and you should see the multiplication table of 3 in your console.

To save this result to the `output.txt` file, run:

```bash
plume -o output.txt input.plume
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
plume input.plume
```

_Of course, with this method you can output several files._

For a list of available options, use:

```
> plume -h
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

## Project Status

The project is archived.
Feather development is not yet complete, but a large number of things to review have led me to start the project from scratch.

You can find the continuation here: https://github.com/ErwanBarbedor/PlumeScript

## Last version : 0.12.0

### Changes
- New syntax: conversion annotation. In the macro definition, users can give the name of a function to call on a parameter to convert it: `\macro double [x:number] ${2*x}`
- Default annotation to all parameters is `auto`, even if old default behavior is `ref`.
- New `config.default_annotation`.
- New `plume.set`, `plume.local_set` and `plume.lset`.
- Rename `plume.lua_get` to `plume.get_lua`
- Remove `plume.lget`
- All warnings are now disables by default.
- New `api.warnings_all()`
- `token:sourceLua(), tokenlist:sourceLua()` -> `token:source_lua(), tokenlist:source_lua()`
- Sugar syntax : `\foo[?bar]` is a shortcut for `\foo[{\if $bar bar}]`

### Enhancements
- Betters error message for internals errors.

### Interns changes
- Code cleaning

### Deprecation
- `tokenlist:is_empty ()` is deprecated
- All tokenlist implicit conversions will be removed in the future.

### CLI changes
- New `-w, --warnings` option

### Bugfixs
- Fix a bug causing non-provided flags to be `nil` instead of `false`.
- Preventing a file from including itself with the macro `\include`, or creating an infinite loop.

See the [changelog](doc/changelog.md) for older version

## License

This project is licensed under the GNU General Public License (GNU-GPL). This means that you are free to use, modify and redistribute the source code. However, if you distribute a modified version, you must also do so under the same license. 

