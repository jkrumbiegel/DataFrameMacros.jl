# DataFrameMacros.jl

Read the docs at [https://jkrumbiegel.github.io/DataFrameMacros.jl/stable.](https://jkrumbiegel.github.io/DataFrameMacros.jl/stable)

## Summary

DataFrameMacros.jl offers macros for DataFrame manipulation with a syntax geared towards clarity, brevity and convenience.
Each macro translates expressions into the more verbose `source => function => sink` mini-language from [DataFrames.jl](https://github.com/JuliaData/DataFrames.jl).

The following macros are currently available:
- `@transform` / `@transform!`
- `@select` / `@select!`
- `@groupby`
- `@combine`
- `@subset` / `@subset!`
- `@sort` / `@sort!`
- `@unique`

## Differences to [DataFramesMeta.jl](https://github.com/JuliaData/DataFramesMeta.jl)

- Except `@combine`, all macros work row-wise by default in DataFrameMacros.jl
  ```julia
  @transform(df, :y = :x + 1)
  @combine(df, :sum = sum(:x))
  ```
- DataFrameMacros.jl uses `{}` to signal column expressions instead of `$()`
  ```julia
  @select(df, :y = {"x"} + 1)
  col = :x
  @transform(df, :z = {col} * 5)
  ```
- In DataFrameMacros.jl, you can switch between by-row and by-column operation separately for each expression in one macro call. In DataFramesMeta.jl, you instead either use, for example, `@rtransform` or `@transform` and all expressions in that call are then by-row or by-column.
  ```julia
  @transform(
      df,
      :y = :x + 1,
      :z = @bycol :x ./ mean(:x)
  )
  ```
- In DataFrameMacros.jl, you can apply the same expression to several columns in `{}` braces at once and even broadcast across multiple sets of columns. You can also use a shortcut syntax to derive new column names from old ones.
  ```julia
  @transform(df, "{}_plus_one" = {r"^col"} + 1) # for all columns starting with "col"
  ```
- In DataFrameMacros.jl, you can use special `{{ }}` multi-column expressions where you can operate on a tuple of all values at once which makes it easier to do aggregates across columns.
  ```julia
  @select(df, :july_larger_than_rest = :july > maximum({{Not(:july)}}))
  ```
- DataFrameMacros.jl has a special syntax to make use of `transform!` on a view returned from `subset`.
  ```julia
  @transform!(df, @subset(:x > 5), :x = :y + 10) # update x in all rows where x > 5
  ```

If any of these points have changed, please open an issue.

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
