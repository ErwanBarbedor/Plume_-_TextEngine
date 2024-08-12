--[[This file is part of Plume - TextEngine.

Plume - TextEngine is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3 of the License.

Plume - TextEngine is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with Plume - TextEngine. If not, see <https://www.gnu.org/licenses/>.
]]

local cli_help = [[
#VERSION#
Plume is a templating langage with advanced scripting features.

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

Examples:
  txe --help
    Display this message.

  txe --version
    Display the version of Plume.

  txe input.txe
    Process 'input.txt'

  txe --print input.txe
    Process 'input.txt' and display the result

  txe --output output.txt input.txe
    Process 'input.txt' and save the result to 'output.txt'.

For more information, visit #GITHUB#.
]]

--- Determine the current directory
local function getCurrentDirectory ()
    -- Determine the appropriate directory separator based on the OS
    local sep = package.config:sub(1, 1)
    local command = sep == '\\' and "cd" or "pwd"

    -- Execute the proper command to get the current directory
    local handle = io.popen(command)
    local currentDir = handle:read("*a")
    handle:close()
    
    -- Remove any newline characters at the end of the path
    return currentDir:gsub("\n", "")
end

--- Convert a path to an absolute path
-- @param dir string Current directory
-- @param path string Path to be converted to absolute. Can be relative or already absolute.
-- @return string Absolute path
local function absolutePath(dir, path)
    if not path then
        return
    end

    -- Normalize path separators to work with both Windows and Linux
    local function normalizePath(p)
        return p:gsub("\\", "/")
    end
    
    dir = normalizePath(dir)
    path = normalizePath(path)
    
    -- Check if the path is already absolute
    if path:sub(1, 1) == "/" or path:sub(2, 2) == ":" then
        return path
    end
    
    -- Function to split a string based on a separator
    local function split(str, sep)
        local result = {}
        for part in str:gmatch("[^" .. sep .. "]+") do
            table.insert(result, part)
        end
        return result
    end

    -- Start with the current directory
    local parts = split(dir, "/")
    
    -- Append each part of the path, resolving "." and ".."
    for part in path:gmatch('[^/]+') do
        if part == ".." then
            table.remove(parts) -- Move up one level
        elseif part ~= "." then
            table.insert(parts, part) -- Add the part to the path
        end
    end

    return table.concat(parts, "/")
end

-- Main function for the command-line interface,
-- a minimal cli parser
function txe.cli_main ()
    -- Save txe directory
    txe.directory = arg[0]:gsub('[/\\][^/\\]*$', '')

    local print_output
    if arg[1] == "-v" or arg[1] == "--version" then
        print(txe._VERSION)
        return
    elseif arg[1] == "-h" or arg[1] == "--help" then
        print(cli_help)
        return
    elseif arg[1] == "-p" or arg[1] == "--print" then
        print_output = true
        table.remove(arg, 1)
    end

    local output, input
    if arg[1] == "-o" or arg[1] == "--output" then
        output = arg[2]
        if not output then
            print ("No output file provided.")
            return
        end

        input  = arg[3]
    elseif not arg[1] then
        print ("No input file provided.")
        return
    elseif arg[1]:match('^%-') then
        print("Unknown option '" .. arg[1] .. "'")
    else
        input  = arg[1]  -- Set input file
    end

    -- Initialize with the input file
    local currentDirectory = getCurrentDirectory ()
    txe.init (input)
    txe.current_scope().txe.input_file  = absolutePath(currentDirectory, input)
    txe.current_scope().txe.output_file = absolutePath(currentDirectory, output)

    -- Render the file and capture success or error
    success, result = pcall(txe.renderFile, input)

    if print_output then
        -- Print the result if the print_output flag is set
        print(result)
    end
    if output then
        -- Write the result to the output file if specified
        local file = io.open(output, "w")
        if not file then
            error("Cannot write the file '" .. output .. "'.", -1)
            return
        end
        file:write(result)
        file:close ()
        print("File '" .. filename .. "' written.")
    end

    if success then
        print("Success.")
    else
        print("Error:")
        print(result)
    end
end

-- Trick to test if we are called from the command line
-- Handle the specific case where arg is nil (when used in fegari for exemple)
if arg and debug.getinfo(3, "S")==nil then
    txe.cli_main ()
end