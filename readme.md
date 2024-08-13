<p align="center"><img src="dist/plume.png" width="600" height="300"></p>

![Version](https://img.shields.io/badge/version-0.1.0-blue.svg) [![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

## Introduction

Programming languages like Python and Lua enable the implementation of complex logic with relative ease. However, working with text input can often be tedious due to cumbersome syntax.

While there are formats that facilitate enriched text writing, such as Markdown or Jinja, they tend to have limited logical capabilities.

Plume's philosophy is to combine the best of both worlds: text input is at the core of its design, yet the integration of logic is seamless, thanks to its close relationship with the Lua scripting language.

To illustrate, consider the task of generating ten files, each containing a multiplication table for a specific number. This can certainly be achieved in Python or Lua, but of Plume offers a more intuitive approach:

```txe
\for {i=1,10} {
    \file {table-#i.txt} {
        \for {j=1,10}{
            #i * #j = #{i*j}
        }
    }
}
```

## Quick Start

You can test plume in [your browser](https://app.barbedor.bzh/txe.html). 

Plume requires Lua to run. It has been tested with Lua versions 5.1, 5.4, and LuaJIT. You just need to download the ```dist/txe.lua``` file.

Write the following in a file `input.txe`:

```txe
\def table[x] {
    \for {i=1, 10} {
        #x * #i = #{x*i}
    }
}
\table {3}
```

Then, in a command console, execute:

```bash
lua txe.lua -p input.txe
```

This runs the `input.txe` file and you should see the multiplication table of 3 in your console.

To save this result to the `output.txt` file, run:

```bash
lua txe.lua -o output.txt input.txe
```

You can also write your `input.txe` like this:

```txe
\table[x] {
    ...
}
\file {output.txt} {
    \table{3}
}
```

And just call:

```bash
lua txe.lua input.txe
```

_Of course, with this method you can output several files._

For a list of available options, use:

```
> lua txe.lua -h
Usage:
    txe INPUT_FILE
    txe --print INPUT_FILE
    txe --output OUTPUT_FILE INPUT_FILE
    txe --version
    txe --help

Options:
  -h, --help          Show this help message and exit.
  -v, --version       Show the version of txe and exit.
  -o, --output FILE   Write the output to FILE
  -p, --print         Display the result
```

## Learn More

To find out more about Plume, you can consult:
- [An overview of its main functions](doc/overview.md)
- [More advanced points](doc/advanced.md)
- Full documentation on predefined [macros](doc/predefined_macros.md) and  [functions](doc/api.md).

You can also [read more about lua](https://www.lua.org/pil/1.html)

## Warnings for LaTeX Users

The syntax is quite similar to that of LaTeX, but Plume behaves very differently.

For exemple, in LaTeX, you can define a macro like this: `\newcommand {\foo} {bar}`, because `newcommand` will be expanded _before_ `foo`.

This doesn't work in Plume because `foo` will be expanded first.

## License

This project is licensed under the GNU General Public License (GNU-GPL). This means that you are free to use, modify and redistribute the source code. However, if you distribute a modified version, you must also do so under the same license. 
