<p align="center"><img src="dist/plume.png" width="600" height="300"></p>

![Version](https://img.shields.io/badge/version-0.7.0-blue.svg) [![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

## Introduction

Programming languages like Python and Lua enable the implementation of complex logic with relative ease. However, working with text input can often be tedious due to cumbersome syntax.

While there are formats that facilitate enriched text writing, such as Markdown or Jinja, they tend to have limited logical capabilities.

Plume's philosophy is to combine the best of both worlds: text input is at the core of its design, yet the integration of logic is seamless, thanks to its close relationship with the Lua scripting language.

To illustrate, consider the task of generating ten files, each containing a multiplication table for a specific number. This can certainly be achieved in Python or Lua, but of Plume offers a more intuitive approach:

```plume
\for {i=1,10} {
    \file {table-$i.txt} {
        \for {j=1,10}{
            $i * $j = ${i*j}
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
        $x * $i = ${x*i}
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

## Last version : 0.7.0

#### Changes
- Default space mode is now `light`.
- First parameter of `\if`, `\elseif`, `\for` and `\while` must now be an eval block.
- You can now declare a Plume block inside a Lua block. (only works inside `plume` files for now, not in external Lua files)
- Change eval escape to `$` from `#`. Code using `#` still works for now.
- Change comment syntax to `\--` from `//`. Code using `//` still works for now.
- New option `join` for `\for`, which will insert a character between all iterations.
- `${x}` will now render all `x` elements, if `x` is a table.
- New flag `no_table_join` and new option `join` for macro `$`.

_-_Explanations for the syntaxs changes:_

Originally, `#` was chosen to adhere to the LaTeX macro syntax, `\newcommand \double[1] {#1 #1}`. However, it doesn't necessarily align with the broader use that Plume makes of it. Moreover, `#` is used by Lua, which makes some expressions unclear (e.g., `#{#t}` to print the size of a table) and prevents it from being used to declare `plume` blocks inside `lua` blocks. Finally, `$` is much more associated with the `evaluate` function than `#`.

As for comments, the idea was to reduce the number of special characters to two in order to avoid the need for escaping as much as possible. (For example, `//` is used in URLs). So, start with `\`. It couldn't be `\\` (because it prints the character `\`) and `\$` was pretty weird, so `\--` was chosen in alignment with the `--` used by Lua. 

#### Enhancement
- Plume comment will now work in Lua blocks.
- Remove useless lines from traceback.

#### Fixes
- Fix wrong space mode name.
- Plume no longer see `a==4` as a statement.
- Fix an error causing Plume to crash if a for loop go over the iteration limit.

See the [changelog](doc/changelog.md) for older version

## License

This project is licensed under the GNU General Public License (GNU-GPL). This means that you are free to use, modify and redistribute the source code. However, if you distribute a modified version, you must also do so under the same license. 

