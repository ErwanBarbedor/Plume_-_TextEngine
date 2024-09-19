# Plume configuration
_Generated from source._

Change configuration using `#{plume.config.key = value}` or using the macro [config](macros.md#config).

| Name | Default Value | Description |
| ----- | ----- | ----- |
| max_callstack_size | 100 |  Maximum number of nested macros. Intended to prevent infinite recursion errors such as `\def foo {\foo}`. |
| max_loop_size | 1000 |  Maximum of loop iteration for macro `\while` and `\for`. |
| ignore_spaces | false |  New lines and leading spaces in the processed file will be ignored. Consecutive spaces are rendered as one. To add spaces in the final file in this case, see [spaces macros](macros.md#spaces). |
| show_deprecation_warnings | true |  Show deprecation warnings created with [deprecate](macros.md#deprecate). |