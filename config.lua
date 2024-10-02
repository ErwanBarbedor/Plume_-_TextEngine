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

-- Configuration settings
plume.config = {}

-- Maximum number of nested macros. Intended to prevent infinite recursion errors such as `\def foo {\foo}`.
plume.config.max_callstack_size = 100

-- Maximum of loop iteration for macro `\while` and `\for`.
plume.config.max_loop_size      = 1000

-- Deprecated. Will be removed in 1.0.
plume.config.ignore_spaces  = false

-- If set to false, no effect. If set to `x`, the `x` character will replace any group of spaces (except spaces beginning a line). See [spaces macros](macros.md#spaces) for more details about space control.
plume.config.filter_spaces = " "

-- If set to false, no effect. If set to `x`, the `x` character will replace any group of newlines. See [spaces macros](macros.md#spaces) for more details about space control.
plume.config.filter_newlines = "\n"

-- Show deprecation warnings created with [deprecate](macros.md#deprecate).
plume.config.show_deprecation_warnings  = true
