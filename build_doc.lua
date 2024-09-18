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

return function ()
    local result = {"# Macros documentation\n_Generated from source._"}
    for categorie in ("Controls Files Script Spaces Utils"):gmatch('%S+') do
        table.insert(result, "## " .. categorie)
        local script = io.open("macros/" .. categorie .. ".lua"):read "*a"
        for macro_name, doc in script:gmatch("%-%-%- \\([A-Za-z0-9_]+)(.-)plume%.register_macro") do
            
            local params = {}
            local params_names = {}
            local options = {}
            local options_names = {}
            local note, desc, alias, other_options

            doc = doc:gsub('\n%-%-%s*', '\n')
            if doc:match('@') then
                desc, doc = doc:match('(.-)(@.*)')
            else
                desc = doc
            end

            desc = desc:gsub('^%s*', ''):gsub('%s*$', '')

            for line in doc:gmatch('[^\n]+') do
                local command, line = line:match('@(.-)%s(.*)')
                if command == "param" then
                    local name, desc = line:match('(%S+)%s(.*)')
                    table.insert(params, "`" .. name .. "` " .. desc)
                    table.insert(params_names, "{"..name.."}")
                elseif command == "option" then
                    local name, default, desc = line:match('(%S-)=(%S+)%s+(.*)')

                    table.insert(options, "`" .. name .. "` " .. desc .. "Default value : `"..default.."`")
                    table.insert(options_names, name.."="..default)
                elseif command == "option_nokw" then
                    local name, default, desc = line:match('(%S-)=(%S+)%s+(.*)')

                    table.insert(options, "`" .. name .. "` " .. desc .. ". It is not a keyword argument, you should use `\\".. macro_name.."["..default.."]` and not `\\".. macro_name.."["..name.."="..default.."]`Default value : `"..default.."`")
                    table.insert(options_names, name)
                elseif command == "note" then
                    note = line
                elseif command == "alias" then
                    alias = line
                elseif command == "other_options" then
                    other_options = line
                end
            end

            if other_options then
                table.insert(options_names, "...")
            end

            local usage = macro_name
            if #options_names > 0 then
                usage = usage .. "[" .. table.concat(options_names, " ") .. "]"
            end

            if #params > 0 then
                usage = usage .. " " .. table.concat(params_names, " ")
            end
            table.insert(result, "### " .. macro_name)

            table.insert(result, "**Usage:** `\\" .. usage .. "`")

            if desc and #desc>0 then
                table.insert(result, "**Description:** " .. desc)
            end

            if #params > 0 then
                table.insert(result, "**Parameters:**\n- " .. table.concat(params, "\n- "))
            end

            if #options > 0 then
                table.insert(result, "**Optionnal parameters:**\n- " .. table.concat(options, "\n- "))
            end

            if other_options then
                table.insert(result, "**Other parameters:** " .. other_options)
            end

            if note then
                table.insert(result, "**Note:** " .. note)
            end

            if alias then
                table.insert(result, "**Alias:** " .. alias)
            end

        end
    end

    io.open("doc/macros.md", "w"):write(table.concat(result, "\n\n"))
    print('Documentation for macros generated.')

    local result = {"# Plume configuration\n_Generated from source._\n\nChange configuration using `#{plume.config.key = value}` or using the macro [config](macros.md#config).\n\n| Name | Default Value | Description |\n| ----- | ----- | ----- |"}
    local script = io.open("config.lua"):read "*a"
    for doc, name, value in script:gmatch("%-%-([^\n\r]+)%s+plume%.config%.([A-Za-z0-9_]+)%s*=%s*([^\n\r]+)") do
        table.insert(result, "| " .. name .. " | " .. value .. " | " .. doc .. " |")
    end

    io.open("doc/config.md", "w"):write(table.concat(result, "\n"))
    print('Documentation for configuration generated.')

end