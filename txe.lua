--[[
#VERSION#
Copyright (C) 2024 Erwan Barbedor

Check #GITHUB#
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

txe = {}
txe._VERSION = "#VERSION#"

require "config"
require "syntax"
require "render"
require "token"
require "tokenize"
require "parse"
require "error"
require "macro"
require "runtime"
require "api"
require "init"

-- <DEV>
txe.show_token = false
local function print_tokens(t, indent)
    indent = indent or ""
    for _, token in ipairs(t) do
        if token.kind == "block" or token.kind == "opt_block" then
            print(indent..token.kind)
            print_tokens(token, "\t"..indent)
        
        elseif token.kind == "block_text" then
            local value = ""
            for _, txt in ipairs(token) do
                value = value .. txt.value
            end
            print(indent..token.kind.."\t"..value:gsub('\n', '\\n'):gsub(' ', '_'))
        elseif token.kind == "opt_value" or token.kind == "opt_key_value" then
            print(indent..token.kind)
            print_tokens(token, "\t"..indent)
        else
            print(indent..token.kind.."\t"..(token.value or ""):gsub('\n', '\\n'):gsub(' ', '_'))
        end
    end
end
-- </DEV>

--- Tokenizes, parses, and renders a string.
-- @param code string The code to render
-- @param file string The name used to track the code
-- @return string The rendered output
function txe.render (code, file)
    local tokens, result
    
    tokens = txe.tokenize(code, file)
    tokens = txe.parse(tokens)
    -- print_tokens(tokens)
    result = tokens:render()
    
    return result
end

--- Reads the content of a file and renders it.
-- @param filename string The name of the file to render
-- @return string The rendered output
function txe.renderFile(filename)
    local file = io.open(filename, "r")
    assert(file, "File " .. filename .. " doesn't exist or cannot be read.")
    local content = file:read("*all")
    file:close()
    
    return txe.render(content, filename)
end

require "cli"

return txe