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

-- Define script-related macro

--- \script
-- Deprecated and will be removed in 1.0. You should use '#{...}' instead.
plume.register_macro("script", {"body"}, {}, function(args)
    --Execute a lua chunk and return the result, if any
    local result = plume.call_lua_chunk(args.body)

    --if result is a token, render it
    if type(result) == "table" and result.render then
        result = result:render ()
    end
    
    return result
end, nil, false, true)

local function scientific_notation (x, n, sep)
    local n = n or 0
    local sep = sep or "."
    local mantissa = x
    local exposant  = 0

    while mantissa / 10 > 1 do
        mantissa = mantissa / 10
        exposant = exposant + 1
    end

    while mantissa < 1 do
        mantissa = mantissa * 10
        exposant = exposant - 1
    end

    local int_mantissa = math.floor (mantissa)
    local dec_mantissa = mantissa - int_mantissa 
    dec_mantissa = tostring(dec_mantissa):sub(3, n+2)

    mantissa = int_mantissa

    if dec_mantissa ~= "" then
        mantissa = mantissa .. sep .. dec_mantissa
    end

    return mantissa.. "e10^" .. exposant
end

--- \eval
-- Evaluate the given expression or execute the given statement.
-- @param code The code to evaluate or execute.
-- @option remove_zeros={} If set to anything not empty and the result is a number, remove useless zeros (e.g., 1.0 becomes 1).
-- @option thousand_separator={} Symbol used between groups of 3 digits.
-- @option decimal_separator=. Symbol used between the integer and the decimal part.
-- @option format={} Only works if the code returns a number. If set to `i`, the number is rounded. If set to `.2f`, it will be output with 2 digits after the decimal point. If set to `.3s`, it will be output using scientific notation, with 3 digits after the decimal point.
-- @option_kw silent Execute the code without returning anything. Useful for filtering unwanted function returns: `#{table.remove(t)}[silent]`
-- @alias `#{1+1}` is the same as `\eval{1+1}`
-- @note If the given code is a statement, it cannot return any value.
-- @note If you use eval inside default parameter values for eval, like `\default eval[{#format}]`, all parameters of `#format` will be ignored to prevent an infinite loop.
plume.register_macro("eval", {"expr"}, {}, function(args, calling_token)

    local remove_zeros, format, scinot, silent

    -- Used to prevent infinite loop when '#' is used inside default eval args value
    if not plume.is_inside_eval then
        plume.is_inside_eval = true

        -- Get optionnals args
        for i, arg in ipairs(args.__args) do
            local arg_render = arg:render ()

            if not remove_zeros and arg_render == "remove_zeros" then
                remove_zeros = true
            elseif not silents and arg_render == "silent" then
                silent = true
            elseif arg_render:match('%.[0-9]+f') or arg_render == "i" then
                format = arg_render
            elseif not scinot and arg_render:match('%.[0-9]+s') then
                scinot = arg_render:match('%.([0-9]+)s')
            else
                plume.error(arg, "Unknow arg '" .. arg_render .. "'.")
            end
        end

        plume.is_inside_eval = false
    end

    -- Get separator if provided
    local t_sep, d_sep
    if args.thousand_separator then
        t_sep = args.thousand_separator:render ()
        if #t_sep == 0 then
            t_sep = nil
        end
    end
    if args.decimal_separator then
        d_sep = args.decimal_separator:render ()
    else
        d_sep = "."
    end

    local result = plume.call_lua_chunk(args.expr)

    -- if result is a token, render it
    if type(result) == "table" and result.render then
        result = result:render ()
    end
    
    if tonumber(result) then
        if format == "i" then
            result = math.floor(result)
        elseif format then
            result = string.format("%"..format, result)
        end

        if scinot then
            result = scientific_notation (result, scinot, t_sep)
        else
            local int, dec = tostring(result):match('^(.-)%.(.+)')
            if not dec then
                int = tostring(result)
            end

            if t_sep then
                local e_t_sep = t_sep:gsub('.', '%%%1')--escaped for matching pattern

                int = int:gsub('([0-9])([0-9][0-9][0-9])$', '%1' .. t_sep .. '%2')
                while int:match('[0-9][0-9][0-9][0-9]' .. e_t_sep) do
                    int = int:gsub('([0-9])([0-9][0-9][0-9])' .. e_t_sep, '%1' .. t_sep .. '%2' .. t_sep)
                end
            end

            if dec and not (remove_zeros and dec:match('^0+$')) then
                result = int .. d_sep .. dec
            else
                result = int
            end
        end
    end
    
    if not silent then
        return result
    end
end, nil, false, true)