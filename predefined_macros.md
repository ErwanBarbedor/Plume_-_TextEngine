
### Controls

#### `\for`

**Description :** Implements a custom iteration mechanism that mimics Lua's for loop behavior.

**Parameters:**
- _iterator_ : A lua iterator syntax, like `i=1, 10` or `foo in pairs(t)`
- _body_ : Any Plume block that will be repeated.

**Exemple:**

```txe
\for {i=1, 10} {
    Line number #i.
}
```

#### `\while`
**Description :** Implements a custom iteration mechanism that mimics Lua's while loop behavior.

**Parameters:**
- _condition_ : Any lua expression
- _body_ : Any Plume block that will be repeated.

**Exemple:**

```txe
\set i 100
\while {i>10} {
    \set i #{i-1}
}
```

#### `\if`
**Description :** Implements a custom condition mechanism that mimics Lua's if behavior.

**Parameters:**

- _condition_ : Any lua expression.
- _body_ : Any Plume block that will be repeated.

**Exemple:**

```txe
\set i 3
\if {i==4} {
    foo
}
```

#### `\else`
**Description :** Implements a custom condition mechanism that mimics Lua's else behavior.

**Parameters:**
- _body_ : Any Plume block that will be repeated.

**Notes:** Must follow an `\if` or an `\elseif` macro, else it will raise an error.

**Exemple:**

```txe
\set i 3
\if {i==4} {
    foo
}
\else {
    bar
}
```

### Files

### Script

### Spaces

### Utils