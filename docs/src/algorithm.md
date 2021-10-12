# Algorithm

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

```@example 1
using DataFrameMacros

@prettyexpand @select(df, :z = :x + :y)
```

```@example 1
@prettyexpand @select(df, :z = @c :x .+ :y)
```

```@example 1
@prettyexpand @select(df, :z = $1 + $2)
```

```@example 1
@prettyexpand @select(df, :z = @m :x + :y)
```