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

-- Function to make error messages in specific cases

--- Compute Damerau-Levenshtein distance
-- @param s1 string first word to compare
-- @param s2 string second word to compare
-- @return int Damerau-Levenshtein distance bewteen s1 and s2
local function word_distance(s1, s2)
    
    local len1, len2 = #s1, #s2
    local matrix = {}

    for i = 0, len1 do
        matrix[i] = {[0] = i}
    end
    for j = 0, len2 do
        matrix[0][j] = j
    end

    for i = 1, len1 do
        for j = 1, len2 do
            local cost = (s1:sub(i,i) ~= s2:sub(j,j)) and 1 or 0
            matrix[i][j] = math.min(
                matrix[i-1][j] + 1,
                matrix[i][j-1] + 1,
                matrix[i-1][j-1] + cost
            )
            if i > 1 and j > 1 and s1:sub(i,i) == s2:sub(j-1,j-1) and s1:sub(i-1,i-1) == s2:sub(j,j) then
                matrix[i][j] = math.min(matrix[i][j], matrix[i-2][j-2] + cost)
            end
        end
    end

    return matrix[len1][len2]
end

--- Convert an associative table to an alphabetically sorted one.
-- @param t table The associative table to sort
-- @return table The table containing sorted keys
local function sort(t)
    -- Create an empty table to store the sorted keys
    local sortedTable = {}
    
    -- Extract keys from the associative table
    for k in pairs(t) do
        table.insert(sortedTable, k)
    end

    -- Sort the keys alphabetically
    table.sort(sortedTable)
    
    return sortedTable
end

--- Generates error message for error occuring in plume internal functions
-- @param error_message string The error message
function plume.internal_error (error_message)
    -- Get the plume line that caused the error
    for line in debug.traceback ():gmatch('[^\n]+') do
        local line_error = line:match('^%s*%[string "%-%-chunk[0-9]+%.%.%."%]:[0-9]+:')
        if line_error then
            error_message = line_error .. " " .. error_message
            break
        end
    end

    plume.error(plume.lua_cache[#plume.lua_cache], error_message, true)
end

--- Generates error message for macro not found.
-- @param token table The token that caused the error (optional)
-- @param macro_name string The name of the not founded macro
function plume.error_macro_not_found (token, macro_name)
    
    -- Use a table to avoid duplicate names
    local suggestions_table = {}

    local scope = plume.get_scope(token and token.context)
    
    -- Hardcoded suggestions for common errors
    if macro_name == "import" then
        suggestions_table["require"] = true
        suggestions_table["include"] = true
    elseif macro_name == "def" or macro_name == "function" or macro_name == "func" then
        suggestions_table.macro = true
    elseif macro_name == "script" or macro_name == "lua" then
        suggestions_table.eval = true
        suggestions_table['$'] = true
    end

    -- Suggestions for possible typing errors
    for _, name in ipairs(scope:get_all("macros")) do
        if word_distance (name, macro_name) <= math.max(math.min(3, #macro_name - 2), 1) then
            suggestions_table[name] = true
        end
    end

    local suggestions_list = sort(suggestions_table)
    for i, name in ipairs(suggestions_list) do
        suggestions_list[i] =  "'" .. name .."'"
    end

    local msg = "Unknow macro '" .. macro_name .. "'."

    if #suggestions_list > 0 then
        msg = msg .. " Perhaps you mean "
        msg = msg .. table.concat(suggestions_list, ", "):gsub(',([^,]*)$', " or%1")
        msg = msg .. "?"
    end

    plume.error (token, msg)
end

--- Generates an error message for unknown optional parameters not found.
-- @param token table The token that caused the error (optional)
-- @param macro_name string The name of the called macro during the error
-- @param parameter string The name of the not found macro
-- @param valid_parameters table Table of valid parameter names
function plume.error_unknown_parameter (token, macro_name, parameter, valid_parameters)
    -- Use a table to avoid duplicate names
    local suggestions_table = {}

    -- Suggestions for possible typing errors
    for name, _ in pairs(valid_parameters) do
        if word_distance (name, parameter) <= math.max(math.min(3, #parameter - 2), 1) then
            suggestions_table[name] = true
        end
    end

    local suggestions_list = sort(suggestions_table)-- To make the order deterministic
    for i, name in ipairs(suggestions_list) do
        suggestions_list[i] =  "'" .. name .."'"
    end

    local msg = "Unknow optionnal parameter '" .. parameter .. "' for macro '" .. macro_name .. "'."

    if #suggestions_list > 0 then
        msg = msg .. " Perhaps you mean "
        msg = msg .. table.concat(suggestions_list, ", "):gsub(',([^,]*)$', " or%1")
        msg = msg .. "?"
    end

    plume.error (token, msg)
end