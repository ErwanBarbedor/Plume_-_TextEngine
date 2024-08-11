# Predefined functions


### `txe.set_local`

**Description:** Set a variable locally

**Parameters:**
- _name_: Variable name.
- _value_: Variable value.

**Example:**

```txe
\def foo {
    \script{
        txe.set_local("a", 1)
        b = 2
    }
    #a #b
}
\foo
#a #b
```
Output:
```
1 2
2
```

### `txe.require`

**Description:**  Works like Lua's require, but uses Plume's file search system.
**Parameters:**
- _name_: Name of the lua file to load.