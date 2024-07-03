--[[This file is part of TextEngine.

TextEngine is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3 of the License.

TextEngine is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with TextEngine. If not, see <https://www.gnu.org/licenses/>.
]]

local version = "TextEngine 0.1.0 (dev)"
local code = io.open("txe.lua"):read "*a"


code = code:gsub('(txe = {}[\r\n]+)', 'local %1')

for i=1, 2 do
    code = code:gsub('require "(.-)"', function (m)
        return "\n-- ## " .. m .. ".lua ##\n" .. io.open(m..".lua"):read "*a":gsub('%-%-%[%[.-%]%][\r\n]+', '', 1)
    end)
end

code = code:gsub('%-%- <DEV>.-%-%- </DEV>', '')
code = code:gsub('#VERSION#', version)
code = code:gsub('#GITHUB#', 'https://github.com/ErwanBarbedor/TextEngine')

io.open('dist/txe.lua', 'w'):write(code)

print("Building " .. version .. " done." )