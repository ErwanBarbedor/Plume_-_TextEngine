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
local function capture_api_method_doc (result, doc, method_name, usage)
    local params  = {}
    local params_names = {}
    local notes   = {}
    local returns = {}
    local returns_names = {}
    local alias

    for name, typ, desc in doc:gmatch('%-%- @param ([A-Za-z0-9_]+) ([A-Za-z0-9_]+) ([^\n\r]*)') do
        table.insert(params_names, name)
        table.insert(params, "`" .. name .. "` _" .. typ .. "_  " .. desc)
    end

    for name, def, typ, desc in doc:gmatch('%-%- @param ([A-Za-z0-9_]+)=(%S+) ([A-Za-z0-9_]+) ([^\n\r]*)') do
        table.insert(params_names, name)
        table.insert(params, "`" .. name .. "` _" .. typ .. "_ " .. desc .. " _(optional, default `"..def.."`)_")
    end

    for name, desc in doc:gmatch('%-%- @return ([A-Za-z0-9_]+) ([^\n\r]*)') do
        table.insert(returns, "`" .. name .. "`" .. desc)
        table.insert(returns_names, name)
    end

    for name in doc:gmatch('%-%- @alias ([A-Za-z0-9_]+)') do
        alias = name
    end

    for name in doc:gmatch('%-%- @name ([A-Za-z0-9_]+)') do
        method_name = name
    end

    for desc in doc:gmatch('%-%- @note ([^\n\r]*)') do
        table.insert(notes, desc)
    end

    table.insert(result, "### " .. method_name )

    if #returns == 0 then
        table.insert(result, "**Usage :** `" .. usage .. method_name .. "(" .. table.concat(params_names, ", ") .. ")`")
    else
        table.insert(result, "**Usage :** `".. table.concat(returns_names, ", ") .. " = " .. usage .. method_name .. "(" .. table.concat(params_names, ", ") .. ")`")
    end

    doc = doc:match('([^\n\r]+)')
    if doc and #doc>0 then
        table.insert(result, "**Description:** " .. doc)
    end

    if #params>0 then
        table.insert(result, '**Parameters :**\n- ' .. table.concat(params, "\n- "))
    end

    if #returns == 1 then
        table.insert(result, "**Return:** " .. returns[1])
    elseif #returns > 1 then
        table.insert(result, "**Return:**\n- " .. table.concat(returns, '\n- '))
    end

    if #notes == 1 then
        table.insert(result, "**Note:** " .. notes[1])
    elseif #notes > 1 then
        table.insert(result, "**Notes:**\n- " .. table.concat(notes, '\n- '))
    end

    if alias then
        table.insert(result, '**Alias :** `plume.' .. alias .. '`')
    end
end

local function capture_api_doc (result, source, usage, capture)
    for doc, method_name in source:gmatch("%-%-%- @"..capture.."(.-)function ([%.A-Za-z0-9_]+)") do
        method_name = method_name:match('[A-Za-z0-9_]+$')
        capture_api_method_doc (result, doc, method_name, usage)
    end

    for doc, method_name in source:gmatch("%-%-%- @"..capture.."(.-)[\n\r]+%s*([A-Za-z0-9_]+) = function") do
        capture_api_method_doc (result, doc, method_name, usage)
    end
end

local function capture_macro_doc (result, source)
    for macro_name, doc in source:gmatch("%-%-%- \\([A-Za-z0-9_]+)(.-)plume%.register_macro") do    
        local params = {}
        local params_names = {}
        local options = {}
        local options_names = {}
        local notes = {}
        local flags = {}
        local options_nokw = {}
        local desc, alias, other_options

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

                if default == "{}" then
                    table.insert(options, "`" .. name .. "` " .. desc .. "Default value : empty")
                else
                    table.insert(options, "`" .. name .. "` " .. desc .. "Default value : `"..default.."`")
                end
                table.insert(options_names, name.."="..default)
            elseif command == "flag" then
                local name, desc = line:match('(%S+)%s(.*)')

                table.insert(flags, "`" .. name .. "` " .. desc)
                table.insert(options_names, name)
            elseif command == "option_nokw" then
                local name, default, desc = line:match('(%S-)=(%S+)%s+(.*)')

                table.insert(options_nokw, "\n" .. (#options_nokw+1).. ". `" .. name .. "` " .. desc .. ".")
                table.insert(options_names, "<"..name..">")
            elseif command == "note" then
                table.insert(notes, line)
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
            table.insert(result, "**Optional keyword parameters** (_Theses argument are used with a keyword, like this : `\\foo[bar=baz]`._)\n- " .. table.concat(options, "\n- "))
        end

        if #options_nokw > 0 then
            table.insert(result, "**Optional positional parameters** (_Theses argument are used without keywords, like this : `\\foo[bar]`._) " .. table.concat(options_nokw, ""))
        end

        if #flags > 0 then
            table.insert(result, "**Flags** (_Flags are optional positional arguments with one value. Behavior occurs when this argument is present._)\n- " .. table.concat(flags, "\n- "))
        end

        if other_options then
            table.insert(result, "**Other optional parameters:** " .. other_options)
        end

        if #notes == 1 then
            table.insert(result, "**Note:** " .. notes[1])
        elseif #notes > 1 then
            table.insert(result, "**Notes:**\n- " .. table.concat(notes, '\n- '))
        end

        if alias then
            table.insert(result, "**Alias:** " .. alias)
        end

    end
end

return function ()
    local result = {"# Macros documentation\n_Generated from source._"}
    for categorie in ("Controls Files Eval Spaces Utils"):gmatch('%S+') do
        table.insert(result, "## " .. categorie)
        local script = io.open("macros/" .. categorie .. ".lua"):read "*a"
        capture_macro_doc (result, script)
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

    local result = {"# Plume API\n_Generated from source._\n\nMéthodes et variables Lua accessibles in any `#` macro.\n\n## Variables\n\n| Name |  Description |\n| ----- | ----- |"}

    table.insert(result, "| `__args` | When inside a macro, contain all macro-given parameters, use `ipairs` to iterate over them. Contain also provided flags as keys.|")
    table.insert(result, "| `__file_args` | Work as `__args`, but inside a file imported by using `\\include` |")

    local script = io.open("api.lua"):read ("*a") .. "\n" .. io.open("cli.lua"):read ("*a")
    for doc, name in script:gmatch("%-%-%- @api_variable([^\n\r]+).-([A-Za-z0-9_]+)%s*=") do
        table.insert(result, "| `plume." .. name .. "` | " .. doc .. " |")
    end

    result = {table.concat(result, "\n")}

    table.insert(result, "## Methods\n\n")

    capture_api_doc (result, script, "plume.", "api_method")

    local script1 = io.open("token.lua"):read ("*a"):match('local tokenlist = setmetatable(.*)')
    local script2 = io.open("render.lua"):read ("*a")

    table.insert(result, "## Tokenlist\n\nTokenlists are Lua representations of Plume structures. `plume.get` will often return `tokenlists`, and macro arguments are also `tokenlists`.\n\nIn addition to the methods listed below, all operations that can be supercharged have also been supercharged. So, if `x` and `y` are two tokenlists, `x + y` is equivalent to `x:render() + y:render()`.\n\nIn the same way, if you call all `string` methods on a tokenlist, the call to `render` will be implicit: `tokenlist:match(...)` is equivalent to `tokenlist:render():match(...)`.")

    local members = {}
    for name, value, doc in script1:gmatch("(%S+)%s*=%s*([^\n\r]-)%-%-%-([^\n\r]+)") do
        if not value:match('^%s*function') then
            table.insert(members, "\n- `tokenlist." .. name .. "` : " .. doc)
        end
    end
    table.insert(result, "### Members" .. table.concat(members))

    capture_api_doc (result, script2, "tokenlist:", "api_method")
    capture_api_doc (result, script1, "tokenlist:", "api_method")

    table.insert(result, "## Tokenlist - intern methods\n\nThe user have access to theses methods, but shouldn't use it.")

    capture_api_doc (result, script1, "tokenlist:", "intern_method")

    io.open("doc/api.md", "w"):write(table.concat(result, "\n\n"))
    print('Documentation for API generated.')

end