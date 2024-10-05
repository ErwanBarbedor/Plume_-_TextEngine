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

-- Merge all code into a single file.
-- Quite dirty, but do the job

local version   = "Plume - TextEngine 0.8.0"
local github    = 'https://github.com/ErwanBarbedor/Plume_-_TextEngine'
local build_doc = require 'build_doc'

build_doc ()

for lua_version in ("5.1 5.2 5.3 5.4 5.x"):gmatch('%S+') do
    local code = io.open("main.lua"):read "*a"

    code = code:gsub('(plume = {}[\r\n]+)', 'local %1')

    for i=1, 2 do
        code = code:gsub('require "(.-)"', function (m)
            return "\n-- ## " .. m .. ".lua ##\n" .. io.open(m..".lua"):read "*a":gsub('%-%-%[%[.-%]%][\r\n]+', '', 1)
        end)
    end

    -- code = code:gsub('%-%- <DEV>.-</DEV>%s*', '\n')

    if lua_version ~= "5.x" then
        code = code:gsub('%-%- <Lua (.-)>\r*\n%s*if .- then(.-)end\r\n%s*%-%- </Lua[^\n]*\r\n', function (v, m)
            if v:match(lua_version) then
                return m:gsub('\n    ', '\n')
            else
                return ""
            end
        end)
    end
    
    code = code:gsub('#VERSION#', version .. "-lua-" .. lua_version)
    code = code:gsub('#GITHUB#', github)

    local file = io.open('dist/Lua '..lua_version..'/plume.lua', 'w')
        file:write(code)
    file:close ()
    print("Building " .. version .. " on Lua " .. lua_version .. " done." )

    -- Make the standalone html (5.3 for fengari)
    if lua_version == "5.3" then
        file = io.open("web/plume.html")
            local html = file:read "*a"
        file:close ()

        file = io.open("web/style.css")
            local css = file:read "*a"
        file:close ()

        code = code:gsub('local plume = {}', 'plume = {}')
        html = html:gsub('{{PLUME}}', code:gsub('%%', '%%%%'))
        html = html:gsub('{{CSS}}',   css:gsub('%%', '%%%%'))
        html = html:gsub('{{GITHUB}}',  github)
        html = html:gsub('{{VERSION}}',  version)
        local version_number = version:match('%S-$')
        html = html:gsub('{{VERSION%-NUMBER}}',  version_number)

        file = io.open("dist/plume.html", "w")
            file:write(html)
        file:close ()
        print("Building website done." )
    end
end