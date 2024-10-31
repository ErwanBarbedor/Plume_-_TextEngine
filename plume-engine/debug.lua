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

-- Tools for debuging during Plume developpement

plume.debug = {}

local function norm(s, fill, l)
    fill = fill or " "
    l = l or 12
    s = s .. fill:rep(l - #s)
    return s
end

function plume.debug.print_tokens(tokens)
    for _, token in ipairs(tokens) do
        local value = token.value:gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("%s", "_")
        print("->", norm(token.kind), norm(value))
    end
end

function plume.debug.print_parsed_tokens(tokens, indent)
    indent = indent or ""
    for _, token in ipairs(tokens) do
        local infos = norm(token.kind)
        if token.kind == "block_text" or token.kind == "space" or token.kind:match('^lua_.*') then
            infos = infos .. "\t'" .. token:source():gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("%s", "_") .. "'"
        elseif token.kind == "macro"  then
            infos = infos .. "\t" .. token.value
        elseif token.kind == "code" then
        end

        print(indent .. "->", infos)

        if token.kind == "block" or token.kind == "opt_block" then
            plume.debug.print_parsed_tokens (token, indent .. "\t")
        elseif token.kind == "code" then
            plume.debug.print_parsed_tokens (token[2], indent .. "\t")
        end
    end
end


function plume.debug.tokenize (code)
    print("List of tokens :")
    print("", norm("Kind"), norm("Value"))
    local tokens = plume.tokenizer:tokenize(code, file)
    plume.debug.print_tokens(tokens)
end

function plume.debug.parse (code)
    local tokens = plume.tokenizer:tokenize(code, file)
    tokens = plume.parse(tokens)

    print("List of tokens after parsing:")
    print("", norm("Kind"), norm("Value"))
    plume.debug.print_parsed_tokens(tokens)
end