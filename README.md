# DataFrameMacros.jl

[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://jkrumbiegel.github.io/DataFrameMacros.jl/stable)
[![](https://img.shields.io/badge/docs-dev-lightgray.svg)](https://jkrumbiegel.github.io/DataFrameMacros.jl/dev)

[![CI Testing](https://github.com/jkrumbiegel/DataFrameMacros.jl/workflows/CI/badge.svg)](https://github.com/jkrumbiegel/DataFrameMacros.jl/actions?query=workflow%3ACI+branch%3Amaster)

## Intro

DataFrames.jl has a special mini-language for data transformations, which is powerful but often verbose.
Here's an example:

```julia
transform(df, :A => ByRow(x -> x + 1) => :B)
```

With DataFrameMacros.jl, you don't have to separately specify the input columns, the transformation function, and the output columns.
You can just write it as a normal expression which is transformed to the mini-language for you:

```julia
@transform(df, :B = :A + 1)
```

DataFrameMacros.jl also helps you when you have to transform many columns in a similar way.
Every expression in DataFrameMacros.jl is automatically executed once for every column in a multi-column specifier, such as `All`, `Between`, `Not` or regular expressions like `r"cat|dog"`.

Here's how you could divide all columns of a DataFrame that start with `"a"` by 10 and add the suffix `_div_10` to each new name:

```julia
@select(df, "{}_div_10" = {r"^a"} / 10)
```

You can also use multiple columns together as a Tuple with the double brace syntax, which is useful when you need to run an aggregation over those columns in an expression. In this example we keep all rows where the value in the `:January` column is larger than the median from `:February` to `:December`:

```julia
@subset(df, :January > median({{ Between(:February, :December) }}))
```

## API

DataFrameMacros.jl exports these macros:
- `@transform` and `@transform!`
- `@select` and `@select!`
- `@groupby`
- `@combine`
- `@subset` and `@subset!`
- `@sort` and `@sort!`
- `@unique`

## DataFrameMacros.jl compared to DataFramesMeta.jl

[DataFramesMeta.jl](https://github.com/JuliaData/DataFramesMeta.jl) is another package that provides macros for DataFrames.jl.
The syntax looks similar in many cases, but here are some noteworthy differences:

- Except `@combine`, all macros work row-wise by default in DataFrameMacros.jl
  ```julia
  @transform(df, :y = :x + 1)
  @combine(df, :sum = sum(:x))
  ```
 - In DataFrameMacros.jl, you can apply the same expression to several columns in `{}` braces at once and even broadcast across multiple sets of columns. You can also use a shortcut syntax to derive new column names from old ones.
  ```julia
  @transform(df, "{}_plus_one" = {r"^col"} + 1) # for all columns starting with "col"
  ```
- In DataFrameMacros.jl, you can use special `{{ }}` multi-column expressions where you can operate on a tuple of all values at once which makes it easier to do aggregates across columns.
  ```julia
  @select(df, :july_larger_than_rest = :july > maximum({{Not(:july)}}))
  ```
- DataFrameMacros.jl uses `{}` to signal column expressions instead of `$()`
  ```julia
  @select(df, :y = {"x"} + 1)
  col = :x
  @transform(df, :z = {col} * 5)
  ```
- DataFrameMacros.jl has a special syntax to make use of `transform!` on a view returned from `subset`.
  ```julia
  @transform!(df, @subset(:x > 5), :x = :y + 10) # update x in all rows where x > 5
  ```
- DataFrameMacros.jl has a `@groupby` macro, which is a shortcut to execute `transform` and then `groupby` on a DataFrame.jl. This is nice when you want to group on a column that you have to create first. Instead of
  ```julia
  df2 = @transform(df, :Y = :X + 1)
  groupby(df2, :Y)
  ```
  You can write:
  ```julia
  @groupby(df, :Y = :X + 1)
  ```

If any of these points have changed, please open an issue.

## Tip

You can use the separate package [Chain.jl](https://github.com/jkrumbiegel/Chain.jl) for writing chains of transformations, this way you don't have to repeat the DataFrame argument every time. This is similar to the tidyverse piping syntax that you might know from R:

```julia
@chain df begin
    @subset(:A > 50)
    @transform(:B = :A + :C)
    @groupby(iseven(:B), :D)
    @combine(:mean_E = mean(:E))
    @sort(abs(:F))
end
```
