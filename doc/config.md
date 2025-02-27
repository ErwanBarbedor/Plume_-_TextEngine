# Plume configuration
_Generated from source._

Change configuration using `${plume.config.key = value}` or using the macro [config](macros.md#config).

| Name | Default Value | Description |
| ----- | ----- | ----- |
| max_callstack_size | 100 |  Maximum number of nested macros. Intended to prevent infinite recursion errors such as `\macro foo {\foo}`. |
| max_loop_size | 1000 |  Maximum of loop iteration for macro `\while` and `\for`. |
| ignore_spaces | false |  Deprecated. Will be removed in 1.0. |
| filter_spaces | " " |  If set to false, no effect. If set to `x`, the `x` character will replace any group of spaces (except spaces beginning a line). See [spaces macros](macros.md#spaces) for more details about space control. |
| filter_newlines | "\n" |  If set to false, no effect. If set to `x`, the `x` character will replace any group of newlines. See [spaces macros](macros.md#spaces) for more details about space control. |
| show_deprecation_warnings | false |  Show deprecation warnings created with [deprecate](macros.md#deprecate). |
| show_macro_overwrite_warnings | false |  Show warning occuring when overwriting already existing macro |
| show_beginner_warnings | false |  Show some warnings for unexperimented users |
| default_annotation | "auto" |  Set default annotation. |