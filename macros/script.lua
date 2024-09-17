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

plume.register_macro("script", {"body"}, {}, function(args)
    --Execute a lua chunk and return the result, if any
    local result = plume.call_lua_chunck(args.body)

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

plume.register_macro("eval", {"expr"}, {}, function(args, calling_token)
    -- Get optionnals args
    local remove_zeros
    local format
    local scinot

    for i, arg in ipairs(args.__args) do
        local arg_render = arg:render ()

        if not remove_zeros and arg_render == "remove_zeros" then
            remove_zeros = true
        elseif arg_render:match('%.[0-9]+f') or arg_render == "i" then
            format = arg_render
        elseif not scinot and arg_render:match('%.[0-9]+s') then
            scinot = arg_render:match('%.([0-9]+)s')
        else
            plume.error(arg, "Unknow arg '" .. arg_render .. "'.")
        end
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
        if format then
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
    
    return result
end, nil, false, true)