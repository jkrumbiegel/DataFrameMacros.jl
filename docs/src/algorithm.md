# Algorithm

```@example 1
using JuliaFormatter: format_text
using MacroTools: prettify
using Markdown: MD

macro prettyexpand(exp)
    s = format_text(string(
        prettify(macroexpand(@__MODULE__, exp))
    ))

    MD("""
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