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
Usage:
    txe INPUT_FILE
    txe --output OUTPUT_FILE INPUT_FILE
    txe --version
    txe --help

Plume - TextEngine is a templating langage with advanced scripting features.

Options:
  -h, --help          Show this help message and exit.
  -v, --version       Show the version of txe and exit.
  -o, --output FILE   Write the output to FILE instead of displaying it.

Examples:
  txe --help
    Display this message.

  txe --version
    Display the version of Plume - TextEngine.

  txe input.txe
    Process 'input.txt' and display the result.

  txe --output output.txt input.txe
    Process 'input.txt' and save the result to 'output.txt'.

For more information, visit #GITHUB#.
]]

--- Main function for the command-line interface,
-- a minimal cli parser
function txe.cli_main ()
    -- Save txe directory
    txe.directory = arg[0]:gsub('[/\\][^/\\]*$', '')

    if arg[1] == "-v" or arg[1] == "--version" then
        print(txe._VERSION)
        return
    elseif arg[1] == "-h" or arg[1] == "--help" then
        print(cli_help)
        return
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
    elseif arg[1]:match('^%-') then
        print("Unknow option '" .. arg[1] .. "'")
    else
        input  = arg[1]
    end

    if not input then
        print ("No input file provided.")
        return
    end

    txe.init (input)
    txe.current_scope().txe.input_file = input
    txe.current_scope().txe.output_file = output

    sucess, result = pcall(txe.renderFile, input)

    if sucess then
        sucess, result = xpcall (txe.current_scope().txe.output, txe.error_handler, result)
        if sucess then
            print("Sucess.")
        else
            print("Error during finalization.")
            result = txe.make_error_message(nil, result, true)
        end
    end

    if not sucess then
        print("Error:")
        print(result)
    end
end

-- Trick to test if we are called from the command line
-- Handle the specific case where arg is nil (when used in fegari for exemple)
if arg and debug.getinfo(3, "S")==nil then
    txe.cli_main ()
end