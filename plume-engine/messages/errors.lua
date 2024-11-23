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

--- Initialize the combination table
-- @param n number The size of the combination table
-- @return table A table initialized with values from 1 to n
local function init_comb(n)
    local t = {}
    for i = 1, n do
        table.insert(t, i)
    end
    return t
end

--- Increment the combination
-- @param t table The current combination table
-- @param n number The maximum allowable number in the combination
-- @param i number The current index to increment, defaults to the length of t if not provided
-- @return boolean Returns true if the operation was successful, else returns nil
local function inc_comb(t, n, i)
    i = i or #t
    t[i] = t[i] + 1

    -- Normalize the current index if it exceeds the maximum number
    if t[i] > n then
        t[i] = 1
        if i == 1 then
            return
        end
        if not inc_comb(t, n, i - 1) then
            return
        end
    end

    -- Ensure no duplicate numbers exist in the combination
    for j = 1, i - 1 do
        if t[j] == t[i] then
            return inc_comb(t, n, i)
        end
    end

    return true
end

--- Iterator function for generating combinations
-- @param n number The size of the combination
-- @return function A function that, when called, returns the next combination table or nil if done
local function iter_comb(n)
    local t = init_comb(n)
    return function()
        if inc_comb(t, n) then
            return t
        end
    end
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

--- Checks and corrects the order of words in a name based on scope.
-- @param name string The name to be checked and potentially corrected.
-- @param scope string The scope to determine the correct order of words.
-- @return string The name with the correct word order based on the given scope.
function test_word_order(name, scope)
    local result = {}

    for _, config in ipairs({
            {pattern="[^_]+",         sep="_"},
            {pattern="[A-Z]-[^A-Z]+", sep="", lower_first=true, upper_second=true}
        }) do
        local words = {}
        for word in name:gmatch(config.pattern) do
            table.insert(words, word)
        end
        
        for comb in iter_comb(#words) do
            local suggestion = {}
            for i, k in ipairs(comb) do
                local word = words[k]
                if config.lower_first and i==1 then
                    word = word:sub(1, 1):lower() .. word:sub(2, -1)
                elseif config.upper_second and i>1 then
                    word = word:sub(1, 1):upper() .. word:sub(2, -1)
                end

                table.insert(suggestion, word)
            end

            local suggestion = table.concat(suggestion, config.sep)
            if scope:get("macros", suggestion) then
                table.insert(result, suggestion)
            end
        end
    end

    return result
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
    
    -- Character suppressions or substitutions, like using "foo" instead of "foo"
    for _, name in ipairs(scope:get_all("macros")) do
        if word_distance (name, macro_name) <= math.max(math.min(3, #macro_name - 2), 1) then
            suggestions_table[name] = true
        end
    end
    -- Wrong word order, like using "local_macro" instead of "macro_local"
    for _, name in ipairs(test_word_order(macro_name, scope)) do
        suggestions_table[name] = true
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

--- Handles error when the end of a block is reached.
-- This function is used to report an error when a macro does not receive the expected number of arguments.
-- @param token table The token associated with the macro call.
-- @param x number The number of arguments received.
-- @param y number The number of arguments expected.
function plume.error_end_block_reached(token, x, y)
    local msg = "End of block reached, not enough arguments for macro '" .. token.value .. "'. "
    msg = msg .. x .. " instead of " .. y .. "."

    plume.error(token, msg)
end

function plume.error_macro_call_without_braces (macro_token, token, n)
    local msg = "Macro call cannot be a parameter"
    msg = msg .. " (here, parameter #"
        msg = msg .. n
        msg = msg .. " of the macro '"
        msg = msg .. macro_token.value
        msg = msg .. "', line "
        msg = msg .. macro_token.line
    msg = msg .. ") "
    msg = msg .. "without being surrounded by braces."

    plume.error(token, msg)
end

function plume.error_invalid_name (token, name, kind)
    plume.error(token, "'" .. name .. "' is an invalid name for a " .. kind .. ".")
end

function plume.error_expecting_an_eval_block (param)
    local source = param:source()
    local correct_source = source

    local msg = "This parameter must be an eval block. "
    if source:sub(1, 1) ~= "{" then
        correct_source = "{" .. correct_source
    end

    if source:sub(-1, -1) ~= "}" then
        correct_source = correct_source .. "}" 
    end

    msg = msg .. "Write '$" .. correct_source .. "' "
    msg = msg .. "instead of '" .. source .. "' "

    plume.error(param, msg)
end


function plume.error_to_many_loop (token, max_loop_size)
    plume.error(token, "To many loop repetition (over the configurated limit of " .. max_loop_size .. ").")
end