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
return function (plume)
    plume.syntax = {
        -- identifier must be a lua valid identifier
        identifier           = "[a-zA-Z0-9_]",
        identifier_begin     = "[a-zA-Z_]",

        -- all folowing must be one char long
        escape               = "\\",
        comment              = "-",-- comments are two plume.syntax.comment char next to each other.
        block_begin          = "{",
        block_end            = "}",
        opt_block_begin      = "[",
        opt_block_end        = "]",
        opt_assign           = "=",
        eval                 = "$"
    }

    plume.lua_syntax = {
        identifier       = plume.syntax.identifier,
        identifier_begin = plume.syntax.identifier_begin,
        simple_quote     = "'",
        double_quote     = '"',
        escape           = "\\",
        comment          = "-",

        call_begin       = "(",
        call_end         = ")",
        index_begin      = "[",
        index_end        = "]",
        table_begin      = "{",
        table_end        = "}",

        statement        = " for if while repeat do ",
        keyword          = " not and or in ",
        statement_alone  = " local ",
        function_keyword = "function",
        end_keyword      = "end",
        return_keyword   = "return"
    }

    --- Checks if a string is a valid identifier.
    -- @param s string The string to check
    -- @return boolean True if the string is a valid identifier, false otherwise
    function plume.is_identifier(s)
        return s:match('^' .. plume.syntax.identifier_begin .. plume.syntax.identifier..'*$')
    end
end