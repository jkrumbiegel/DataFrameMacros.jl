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