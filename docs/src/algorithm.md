# Algorithm

With the following `@prettyexpand` macro, we can have a look at exactly what output expressions the different macros and flags produce.
All animal name variables are temporary variables that are macro-generated.

```@example 1
using JuliaFormatter: format_text
using MacroTools: prettify
using Markdown

macro prettyexpand(exp)
    s = format_text(string(
        prettify(macroexpand(@__MODULE__, exp))
    ), margin = 80)

    Markdown.parse("""
    ```julia
    $s
    ```
    """)
end
```

A simple select call with two column names and one output name.

```@example 1
using DataFrameMacros

@prettyexpand @select(df, :z = :x + :y)
```

The `@c` flag macro removes the `ByRow` construct.

```@example 1
@prettyexpand @select(df, :z = @c :x .+ :y)
```

Integers have to be resolved to strings before being used as column identifiers.

```@example 1
@prettyexpand @select(df, :z = $1 + $2)
```

The `@m` flag introduces a `passmissing` wrapper.

```@example 1
@prettyexpand @select(df, :z = @m :x + :y)
```

The `@t` flag sets the output to `AsTable` and creates a `NamedTuple` of all symbol assignments.

```@example 1
@prettyexpand @transform(df, @t :first_name, :last_name = split(:full_name))
```