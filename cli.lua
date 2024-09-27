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

Examples:
  plume --help
    Display this message.

  plume --version
    Display the version of Plume.

  plume input.plume
    Process 'input.txt'

  plume --print input.plume
    Process 'input.txt' and display the result

  plume --output output.txt input.plume
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
function plume.cli_main ()
    -- Save plume directory
    plume.directory = arg[0]:gsub('[/\\][^/\\]*$', '')

    -- The first arg is "plume"
    table.remove(arg, 1)

    local print_output
    if arg[1] == "-v" or arg[1] == "--version" then
        print(plume._VERSION)
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
    plume.init (input)
    --- @api_variable If use in command line, path of the input file.
    plume.current_scope().variables.plume.input_file  = absolutePath(currentDirectory, input)
    --- @api_variable Name of the file to output execution result. If set to none, don't print anything. Can be set by command line.
    plume.current_scope().variables.plume.output_file = absolutePath(currentDirectory, output)

    -- Render the file and capture success or error
    success, result = pcall(plume.renderFile, input)

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
    plume.cli_main ()
end