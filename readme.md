![Plume - TextEngine](logo.png)

## Introduction

TextEngine is a templating language with advanced scripting features.

It is designed to facilitate the generation of text documents (.txt, .html, ...) by mixing natural language and macros.

For example, the following code:
``` txe
\def double[x] {#x #x}
Some Text.
Some macro utilities: \double{foo}
```
Gives
``` txt
Some Text.
Some macro utilities: foo foo
```

TextEngine is heavily extensible with the Lua scripting langage.
For exemple, the code
``` txe
\for {i = 1, 10} {
    \if {math.floor(math.sqrt(i)) == math.sqrt(i)} {
        This is a square number : #i
    }
}
```
Gives
``` txt
This is a square number : 1
This is a square number : 4
This is a square number : 9
```

More than that, you can use in TextEngine any Lua defined function.

## Usage

TextEngine requires Lua to run. It has been tested with versions Lua 5.1, Lua 5.4 and Luajit.
You just need to download the ```dist/txe.lua``` file. Then, in a command console:

```bash
lua txe.lua input.txe
```
Executes the ```input.txe``` file and displays the result.

If you want to save this result to the ```output.txe``` file,

```bash
lua txe.lua -o output.txe input.txe
```

## Tutorial

*Coming soon...*

## Documentation

*Coming soon...*

## License

TextEngine is distributed under the GNU General Public License.