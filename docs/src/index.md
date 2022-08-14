# DataFrameMacros.jl

DataFrameMacros.jl offers macros for DataFrame manipulation with a syntax geared towards clarity, brevity and convenience.
Each macro translates expressions into the more verbose `source => function => sink` mini-language from [DataFrames.jl](https://github.com/JuliaData/DataFrames.jl).

Here is a simple example:

```@repl
using DataFrameMacros, DataFrames
df = DataFrame(name = ["Mary Louise Parker", "Thomas John Fisher"])

result = @transform(df, :middle_initial = split(:name)[2][1] * ".")
```

Unlike DataFrames.jl, most operations are **row-wise** by default.
This often results in cleaner code that's easier to understand and reason about, especially when string or object manipulation is involved.
Such operations often don't have a clean broadcasting syntax, for example, `somestring[2]` is easier to read than `getindex.(somestrings, 2)`.
The same is true for `someobject.property` and `getproperty.(someobjects, :property)`.

The following macros are currently available:
- `@transform` / `@transform!`
- `@select` / `@select!`
- `@groupby`
- `@combine`
- `@subset` / `@subset!`
- `@sort` / `@sort!`
- `@unique`

Together with [Chain.jl](https://github.com/jkrumbiegel/Chain.jl), you get a convient syntax for chains of transformations:

```@example
using DataFrameMacros
using DataFrames
using Chain
using Random
using Statistics
Random.seed!(123)

df = DataFrame(
    id = shuffle(1:5),
    group = rand('a':'b', 5),
    weight_kg = randn(5) .* 5 .+ 60,
    height_cm = randn(5) .* 10 .+ 170)

result = @chain df begin
    @subset(:weight_kg > 50)
    @transform(:BMI = :weight_kg / (:height_cm / 100) ^ 2)
    @groupby(iseven(:id), :group)
    @combine(:mean_BMI = mean(:BMI))
    @sort(sqrt(:mean_BMI))
end

show(result)
```

## Design choices

These are the most important aspects that differ from other packages ([DataFramesMeta.jl](https://github.com/JuliaData/DataFramesMeta.jl) in particular):

- All macros except `@combine` work **row-wise** by default. This reduces syntax complexity in most cases because no broadcasting is necessary. A modifier macro (`@colwise` or `@rowwise`) can be used to switch between row/column-based mode when needed.
- `@groupby` and `@sort` allow using arbitrary expressions including multiple columns, without having to `@transform` first and repeat the new column names.
- Column expressions are interpolated into the macro with `$`.
- Keyword arguments to the macro-underlying functions work by separating them from column expressions with the `;` character.
- Target column names are written with `:` symbols to avoid visual ambiguity (`:newcol = ...`). This also allows to use `AsTable` as a target like in DataFrames.jl.
- The modifier macro can also include the character `m` to switch on automatic `passmissing` in row-wise mode.
- There is also a `@astable` modifier macro, which extracts every `:sym = expression` expression and collects the new symbols in a named tuple, while setting the target to `AsTable`.
