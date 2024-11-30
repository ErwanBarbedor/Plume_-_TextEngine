--[[
Plume - TextEngine 0.11.3
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

-- Following Lua best practices, plume should be local.
-- But given the current organization of the code, this would require a major rewrite.
plume = {}
plume._VERSION = "Plume - TextEngine 0.11.3"

require "plume-engine.config"
require "plume-engine.syntax"
require "plume-engine.render"
require "plume-engine.token"
require "plume-engine.tokenize"
require "plume-engine.tokenize_plume"
require "plume-engine.tokenize_lua"
require "plume-engine.parse"
require "plume-engine.error"
require "plume-engine.macro"
require "plume-engine.runtime"
require "plume-engine.initialization"
require "plume-engine.api"
require "plume-engine.debug"

require "plume-engine.messages.errors"
require "plume-engine.messages.syntax_errors"
require "plume-engine.messages.warnings"

--- Tokenizes, parses, and renders a string.
-- @param code string The code to render
-- @param file string The name used to track the code
-- @return string The rendered output
function plume.render (code, file)
    local tokens, result
    
    tokens = plume.tokenizer:tokenize(code, file)
    tokens = plume.parse(tokens)
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

return plume