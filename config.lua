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

-- Maximum of loop iteration for macro "\while" and "\for".
plume.config.max_loop_size      = 1000

-- New lines and leading spaces in the processed file will be ignored. Consecutive spaces are rendered as one. To add spaces in the final file in this case, use the `\s` (space), `\t` (tab), and `\n` (newline) macros.
plume.config.ignore_spaces  = false

-- Show deprecation warnings created with [deprecate](macros.md#deprecate).
plume.config.show_deprecation_warnings  = true