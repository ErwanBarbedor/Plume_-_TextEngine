<p align="center"><img src="https://app.barbedor.bzh/plume.png" width="600" height="300"></p>

![Version](https://img.shields.io/badge/version-0.11.3-blue.svg) [![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

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

You can test plume in [your browser](https://app.barbedor.bzh/plume.html). 

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

Plume is currently in development, and I try to release an update every week or every two weeks.

I am actively experimenting with features in several projects (non-public), so updates are often non-backward compatible: macros and functions are added/removed very regularly, the internal workings evolve, and even the syntax can change.

This is essential for improving Plume, but it currently makes it incompatible with production use, although I try to announce non-backward compatible changes one or two versions in advance. However, feel free to test and report any errors or suggestions! The documentation is already very comprehensive and is regularly updated.

Version 1.0 should be released no later than September 2025, likely sooner. I will then tackle plume-document, a set of Plume macros for generating HTML/PDF documents.

## Last bugfix & enhancement version : 0.11.3
### Bugfix
- Fix a case when `${10.0}` output `.`
- Fix an error in documentation generation.
- Fix an error causing Lua comment to remove the end line, causing syntax errors.
- Fix a bug causing the ignoring of a local variable with a nil value and getting instead the parent value.
- Fix a bug occurring when trying to require a directory.
- Fix a bug causing external file Lua error to be treated as Plume internal errors.

### Enhancements
- A rendered flag that is empty doesn't raise an error anymore.
- If a rendered flag is provided, trim spaces before checking if this flag exists.

## Last minor version : 0.11.0
### Changes
- As planned, `\for`, `\if`, `\while` and `\elseif` first parameters must now be lua blocks.
- Remove `_L`, too complex to implement without being useful.
- No need anymore to escape `$` or braces inside lua string. Escaped `$` or braces will now raise an error.
- Can now use `return` inside a lua block.
- In consequence, remove `plume.write`.
- Can now use arbitrary complexe lua iterator in the `\for` macro.
- Token implicit conversion now only works if used with string methods or operators.

### Enhancement
- Plume should now detects if a Lua block is a statement or an expression without error.
- More pertinent suggestions in case of unknown macro or parameter.
- More coherent error messages.
- Resetting Plume is much faster.
- More accurate spaces filtering.

### Internal changes
- Rewrite unitary testing: cleaner code and much clearer output.
- Rewrite tokenizer. Cleaner and now context-sensitive
- Move somme parts of render to parser.
- Write a limited lua parser.
- Move errors message to dedicateds files.
- A lot of other code rewriting, cleaning, and comments added.

See the [changelog](doc/changelog.md) for older version

## License

This project is licensed under the GNU General Public License (GNU-GPL). This means that you are free to use, modify and redistribute the source code. However, if you distribute a modified version, you must also do so under the same license. 

