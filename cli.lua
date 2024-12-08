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
local plume = require "plume-engine"

local cli_help = [[
]] .. plume._VERSION .. [[
Plume is a templating langage with advanced scripting features.

Usage:
    plume [--print -p] [--output -o OUTPUT_FILE] [--config CONFIG] [INPUT_FILE | --string -s CODE]

Options:
  No argument         Launch interactive mode.
  -h, --help          Show this help message and exit.
  -v, --version       Show the version of plume and exit.
  -o, --output FILE   Write the output to FILE
  -p, --print         Display the result (true if -s is present)
  -s, --string        Evaluate the input
  -c, --config        Edit plume configuration
  -w, --warnings      Activate warnings

Examples:
  plume --help
    Display this message.

  plume --print input.plume
    Process 'input.plume' and display the result

  plume --output output.txt --string "foo"
    Process the code "foo" and save the result to 'output.txt'.
  
  plume --config "filter_spaces=_;filter_newlines= ;show_deprecation_warnings=false" input.plume
    Process 'input.plume' with a specific configuration.

For more information, visit https://github.com/ErwanBarbedor/Plume_-_TextEngine.
]]

local cli = {}

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

    if dir:sub(1, 1) == "/" then
        table.insert(parts, 1, "")
    end
    
    return table.concat(parts, "/")
end

-- Main function for the command-line interface,
-- a minimal cli parser
function cli.main ()
    -- Save plume directory
    plume.directory = arg[0]:gsub('[/\\][^/\\]*$', '')

    local print_output, direct_mode, config, warnings
    local output_file, input_file

    while #arg > 0 do
        if arg[1] == "-v" or arg[1] == "--version" then
            print(plume._VERSION)
            return
        elseif arg[1] == "-h" or arg[1] == "--help" then
            print(cli_help)
            return
        elseif arg[1] == "-p" or arg[1] == "--print" then
            print_output = true
            table.remove(arg, 1)
        elseif arg[1] == "-w" or arg[1] == "--warnings" then
            warnings = true
            table.remove(arg, 1)
        elseif arg[1] == "-s" or arg[1] == "--string" then
            direct_mode = true
            table.remove(arg, 1)
        elseif arg[1] == "-c" or arg[1] == "--config" then
            local optn = table.remove(arg, 1)
            config = table.remove(arg, 1)
            if not config then
                io.stderr:write("configuration expected after '" .. optn .. "'.")
            end
        elseif arg[1] == "-o" or arg[1] == "--output" then
            output_file = arg[2]
            if not output_file then
                io.stderr:write("No output file provided.")
            end
            table.remove(arg, 1)
            table.remove(arg, 1)
        elseif arg[1]:match('^%-') then
            io.stderr:write("Unknown option '" .. arg[1] .. "'\n" .. "Type plume --help for get accepted options.")
            return
        else
            input = arg[1]
            table.remove(arg, 1)
        end
    end

    if not input then
        plume.init()
        cli.config(plume, config, warnings)
        return cli.interactive_mode (plume)
    end

    -- Initialize with the input file
    local currentDirectory = getCurrentDirectory ()

    local success, result
    if direct_mode then
        plume.init ()
        cli.config(plume, config)
        -- Render the given string and capture success or error
        success, result = pcall(plume.render, input)
    else
        input_file = input
        plume.init (input_file)
        cli.config(plume, config)

        --- @api_variable If use in command line, path of the input file.
        plume.get_scope().variables.plume.input_file  = absolutePath(currentDirectory, input_file)
        --- @api_variable Name of the file to output execution result. If set to none, don't print anything. Can be set by command line.
        plume.get_scope().variables.plume.output_file = absolutePath(currentDirectory, output_file)

        -- Render the given file and capture success or error
        success, result = pcall(plume.renderFile, input_file)
    end

    -- Print the result if the print_output flag is set, or if in direct mode
    if success and (print_output or (direct_mode and not output_file)) then
        print(result)
    end

    if output_file then
        -- Write the result to the output file if specified
        local file = io.open(output_file, "w")
        if not file then
            error("Cannot write the file '" .. output_file .. "'.", -1)
            return
        end
        file:write(result)
        file:close ()
        print("File '" .. output_file .. "' written.")
    end

    if not success then
        io.stderr:write(result.."\n")
    end
end

--- Activates the interactive mode of the plume module
-- Prints the version, initializes plume, and processes user input until the "exit" command is issued.
function cli.interactive_mode(plume)
    -- Print the version information
    print(plume._VERSION)
    print("Type '" .. plume.syntax.escape .. "exit' to exit the interactive mode.")

    local exit = false

    -- Register "exit" macro to exit interactive mode
    plume.register_macro("exit", {}, {}, function() exit = true end)

    -- Start interactive loop
    while not exit do
        -- Prompt the user for input
        io.write "> "
        local input = io.read "*l"
        
        -- Attempt to render the user's input and handle any errors
        local success, result = pcall(plume.render, input)
        
        print(result)

        -- Reset traceback and error
        if not sucess then
            plume.last_error = nil
            plume.traceback = {}
        end
    end
end

--- Configures the application's runtime settings
-- Parses the configuration string and updates plume configuration.
-- The configuration string should have key-value pairs separated by semicolons, with each pair in the format "key=value".
-- Supports boolean values ("true" or "false") and numeric values in string form.
-- If an invalid format is encountered or a key does not exist, an error message is written to stderr.
-- @param plume table The plume main table
-- @param config string A semicolon-separated string of "key=value" pairs representing configuration settings.
function cli.config(plume, config, warnings)
    for info in (config or ""):gmatch('[^;]+') do
        local key, value = info:match('([^=]+)=(.+)')
        if not value then
            io.stderr:write('Malformed configuration "' .. info .. '"\n')
            io.stderr:write('"key=value" format expected.\n')
        end

        -- Convert value to appropriate type (boolean or number)
        if value == "false" then
            value = false
        elseif value == "true" then
            value = true
        elseif tonumber(value) then
            value = tonumber(value)
        end

        -- Update the configuration if the key exists
        if plume.running_api.config[key] then
            plume.running_api.config[key] = value
        else
            io.stderr:write("Unknown configuration '" .. key .. "'\n")
        end
    end

    if warnings then
        plume.running_api.warnings_all ()
    end
end

cli.main ()