--[[
Plume - TextEngine 0.9.0
Copyright (C) 2024 Erwan Barbedor

Check https://github.com/ErwanBarbedor/Plume_-_TextEngine
for documentation, tutorial or to report issues.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3 of the License.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.
]]

plume = {}
plume._VERSION = "Plume - TextEngine 0.9.0"

require "plume.config"
require "plume.syntax"
require "plume.render"
require "plume.token"
require "plume.tokenize"
require "plume.parse"
require "plume.error"
require "plume.macro"
require "plume.runtime"
require "plume.initialization"
require "plume.api"

-- <DEV>
plume.show_token = false
local function print_tokens(t, indent)
    local function print_token_info (token)
        print(indent..token.kind.."\t"..(token.value or ""):gsub('\n', '\\n'):gsub(' ', '_')..'\t'..tostring(token.context or ""))
    end

    indent = indent or ""
    for _, token in ipairs(t) do
        if token.kind == "block" or token.kind == "opt_block" then
            print_token_info(token)
            print_tokens(token, "\t"..indent)
        
        elseif token.kind == "block_text" then
            local value = ""
            for _, txt in ipairs(token) do
                value = value .. txt.value
            end
            print_token_info(token)
        elseif token.kind == "opt_value" or token.kind == "opt_key_value" then
            print_token_info (token)
            print_tokens(token, "\t"..indent)
        else
            print_token_info(token)
        end
    end
end
-- </DEV>

--- Tokenizes, parses, and renders a string.
-- @param code string The code to render
-- @param file string The name used to track the code
-- @return string The rendered output
function plume.render (code, file)
    local tokens, result
    
    tokens = plume.tokenize(code, file)
    tokens = plume.parse(tokens)
    -- <DEV>
    if plume.show_token then
        print "--------"
        print_tokens(tokens)
    end
    -- </DEV>
    result = tokens:render()
    
    return result
end

--- Reads the content of a file and renders it.
-- @param filename string The name of the file to render
-- @return string The rendered output
function plume.renderFile(filename)
    local file = io.open(filename, "r")
        assert(file, "File " .. filename .. " doesn't exist or cannot be read.")
        local content = file:read("*all")
    file:close()
    
    local result = plume.render(content, filename)

    return result
end

require "plume.cli"

return plume