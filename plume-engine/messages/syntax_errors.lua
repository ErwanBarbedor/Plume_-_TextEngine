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


function plume.syntax_error_wrong_eval (token, char)
    local msg = "Syntax error : '" .. plume.syntax.eval .. "' must be followed by an identifier "
    msg = msg .. "or '" .. plume.syntax.block_begin .. "', "
    msg = msg .. "not '" .. char .. "'."
    plume.error (token,  msg)
end

function plume.syntax_error_wrong_eval_inside_lua (token, char)
    local msg = "Syntax error : inside a lua bloc, '" .. plume.syntax.eval .. "' must be followed by '" .. plume.syntax.block_begin .. "', "
    msg = msg .. "not '" .. char .. "'."
    plume.error (token,  msg)
end

function plume.syntax_error_brace_close_nothing (token)
    plume.error(token, "Syntax error : this brace close nothing.")
end

function plume.syntax_error_unpaired_braces (token, opening_brace)
    plume.error(token, "Syntax error : this brace doesn't matching the opening brace, which was '"..opening_brace.."'.")
end

function plume.syntax_error_brace_unclosed (token)
    plume.error(token, "Syntax error : this brace was never closed.")
end

function plume.syntax_error_cannot_use_inside_optionnal_block (token)
    plume.error(token, "Syntax error : cannot use '" .. token.kind .. "' in optionnal parameters declaration. Please place braces around, or use raw text.")
end

function plume.syntax_error_expected_parameter_value(token)
    plume.error(token, "Expected parameter value, not '" .. token.value .. "'.")
end

function plume.syntax_error_expected_parameter_name(token)
    plume.error(token, "Expected parameter name, not '" .. token.value .. "'.")
end

function plume.syntax_error_lua_eof (token)
    plume.error(token, "Cannot end a lua script with '" .. token.value .. "'.")
end

function plume.error_syntax_invalid_for_iterator (token)
    plume.error(token, "Non valid syntax for iterator.")
end