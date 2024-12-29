--[[
Plume - TextEngine 0.13.0
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
local plume = {}
plume._VERSION = "Plume - TextEngine 0.13.0"

require "plume-engine.config"          (plume)
require "plume-engine.syntax"          (plume)
require "plume-engine.render"          (plume)
require "plume-engine.token"           (plume)
require "plume-engine.tokenize"        (plume)
require "plume-engine.tokenize_plume"  (plume)
require "plume-engine.tokenize_lua"    (plume)
require "plume-engine.parse"           (plume)
require "plume-engine.error"           (plume)
require "plume-engine.macro"           (plume)
require "plume-engine.runtime"         (plume)
require "plume-engine.initialization"  (plume)
require "plume-engine.api"             (plume)
require "plume-engine.debug"           (plume)

require "plume-engine.messages.errors"         (plume)
require "plume-engine.messages.syntax_errors"  (plume)
require "plume-engine.messages.warnings"       (plume)

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