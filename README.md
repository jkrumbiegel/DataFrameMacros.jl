# DataFrameMacros.jl

[Read the full documentation and tutorials here](https://jkrumbiegel.github.io/DataFrameMacros.jl/stable)

## Summary

DataFrameMacros.jl offers macros for DataFrame manipulation with a syntax geared towards clarity, brevity and convenience.
Each macro translates expressions into the more verbose `source => function => sink` mini-language from [DataFrames.jl](https://github.com/JuliaData/DataFrames.jl).

## Example

Together with [Chain.jl](https://github.com/jkrumbiegel/Chain.jl), you get a convient syntax for chains of transformations:

```julia
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

@chain df begin
    @subset(:weight_kg > 50)
    @transform(:BMI = :weight_kg / (:height_cm / 100) ^ 2)
    @groupby(iseven(:id), :group)
    @combine(:mean_BMI = mean(:BMI))
    @sort(sqrt(:mean_BMI))
end
```

```
4×3 DataFrame
 Row │ id_iseven  group  mean_BMI
     │ Bool       Char   Float64
─────┼────────────────────────────
   1 │     false  a       19.0728
   2 │      true  a       20.4405
   3 │     false  b       22.097
   4 │      true  b       22.9701
```

Unlike DataFrames.jl, most operations are **row-wise** by default but you can switch to column-wise on demand using the `@bycol` modifier macro.
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

