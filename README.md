# DFMacros

This package offers an opinionated take on DataFrame manipulation in Julia with a syntax geared towards convenience.

The following macros are currently available:
- `@transform` / `@transform!`
- `@select` / `@select!`
- `@groupby`
- `@combine`
- `@subset` / `@subset!`
- `@sort` / `@sort!`

Together with [Chain.jl](https://github.com/jkrumbiegel/Chain.jl), you get a convient syntax for longer piped transformations:

```julia
using DFMacros
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

## Design choices

These are the most important opinionated aspects that differ from other packages:
- `@transform`, `@select` and `@subset` work row-wise by default, `@combine` works column-wise by default. This matches the most common modes these functions are used in and reduces friction.
- `@groupby` and `@sort` allow using arbitrary expressions including multiple columns, without having to `@transform` first and repeat the new column names.
- Column expressions are interpolated into the macro with `$`.
- Keyword arguments to the macro-underlying functions work by separating them from column expressions with the `;` character.
- Target column names are written with `:` symbols to avoid visual ambiguity (`:newcol = ...`). This also allows to use `AsTable` as a target like in DataFrames.jl.
- A flag macro (`@c` or `@r`) can be used to switch between row/column-based mode.
- The flag macro can also include the character `m` to switch on automatic `passmissing` in row-wise mode.

## Examples

- [@select](#select)
- [@transform](#transform)
- [column flag @c](#column-flag-c)
- [@groupby & @combine](#groupby--combine)
- [@sort](#sort)
- [interpolating column expressions](#interpolating-column-expressions)
- [passmissing flag @m](#passmissing-flag-m)
- [escaping symbols](#escaping-symbols)

```julia
using DFMacros
using DataFrames
using Random
using Statistics
Random.seed!(123)

df = DataFrame(
    id = shuffle(1:5),
    group = rand('a':'b', 5),
    weight_kg = randn(5) .* 5 .+ 60,
    height_cm = randn(5) .* 10 .+ 170)
```

```
5×4 DataFrame
 Row │ id     group  weight_kg  height_cm
     │ Int64  Char   Float64    Float64
─────┼────────────────────────────────────
   1 │     1  b        64.9048    161.561
   2 │     4  b        59.6226    161.111
   3 │     2  a        61.3691    173.272
   4 │     3  a        59.0289    175.924
   5 │     5  b        58.3032    173.68
```

### @select

```julia
@select(df, :height_m = :height_cm / 100)
```

```
5×1 DataFrame
 Row │ height_m
     │ Float64
─────┼──────────
   1 │  1.61561
   2 │  1.61111
   3 │  1.73272
   4 │  1.75924
   5 │  1.7368
```

```julia
@select(df, AsTable = (w = :weight_kg, h = :height_cm))
```

```
5×2 DataFrame
 Row │ w        h
     │ Float64  Float64
─────┼──────────────────
   1 │ 64.9048  161.561
   2 │ 59.6226  161.111
   3 │ 61.3691  173.272
   4 │ 59.0289  175.924
   5 │ 58.3032  173.68
```

### @transform

```julia
@transform(df, :weight_g = :weight_kg / 1000)
```

```
5×5 DataFrame
 Row │ id     group  weight_kg  height_cm  weight_g
     │ Int64  Char   Float64    Float64    Float64
─────┼───────────────────────────────────────────────
   1 │     1  b        64.9048    161.561  0.0649048
   2 │     4  b        59.6226    161.111  0.0596226
   3 │     2  a        61.3691    173.272  0.0613691
   4 │     3  a        59.0289    175.924  0.0590289
   5 │     5  b        58.3032    173.68   0.0583032
```

```julia
@transform(df, :BMI = :weight_kg / (:height_cm / 100) ^ 2)
```

```
5×5 DataFrame
 Row │ id     group  weight_kg  height_cm  BMI
     │ Int64  Char   Float64    Float64    Float64
─────┼─────────────────────────────────────────────
   1 │     1  b        64.9048    161.561  24.8658
   2 │     4  b        59.6226    161.111  22.9701
   3 │     2  a        61.3691    173.272  20.4405
   4 │     3  a        59.0289    175.924  19.0728
   5 │     5  b        58.3032    173.68   19.3282
```

#### column flag @c

```julia
@transform(df, :weight_z = @c (:weight_kg .- mean(:weight_kg)) / std(:weight_kg))
```

```
5×5 DataFrame
 Row │ id     group  weight_kg  height_cm  weight_z
     │ Int64  Char   Float64    Float64    Float64
─────┼───────────────────────────────────────────────
   1 │     1  b        64.9048    161.561   1.61523
   2 │     4  b        59.6226    161.111  -0.388008
   3 │     2  a        61.3691    173.272   0.274332
   4 │     3  a        59.0289    175.924  -0.613175
   5 │     5  b        58.3032    173.68   -0.888383
```

### @groupby & @combine

```julia
g = @groupby(df, iseven(:id))
```

```
GroupedDataFrame with 2 groups based on key: id_iseven
Group 1 (3 rows): id_iseven = false
 Row │ id     group  weight_kg  height_cm  id_iseven
     │ Int64  Char   Float64    Float64    Bool
─────┼───────────────────────────────────────────────
   1 │     1  b        64.9048    161.561      false
   2 │     3  a        59.0289    175.924      false
   3 │     5  b        58.3032    173.68       false
Group 2 (2 rows): id_iseven = true
 Row │ id     group  weight_kg  height_cm  id_iseven
     │ Int64  Char   Float64    Float64    Bool
─────┼───────────────────────────────────────────────
   1 │     4  b        59.6226    161.111       true
   2 │     2  a        61.3691    173.272       true
```

```julia
@combine(g, :total_weight_kg = sum(:weight_kg))
```

```
2×2 DataFrame
 Row │ id_iseven  total_weight_kg
     │ Bool       Float64
─────┼────────────────────────────
   1 │     false          182.237
   2 │      true          120.992
```

### @sort

```julia
@sort(df, sqrt(:height_cm) / :weight_kg; rev = true)
```

```
5×4 DataFrame
 Row │ id     group  weight_kg  height_cm
     │ Int64  Char   Float64    Float64
─────┼────────────────────────────────────
   1 │     5  b        58.3032    173.68
   2 │     3  a        59.0289    175.924
   3 │     2  a        61.3691    173.272
   4 │     4  b        59.6226    161.111
   5 │     1  b        64.9048    161.561
```

### interpolating column expressions

If you have a variable or expression that you want to use as a column identifier, interpolate it into the macro with `$`.

```julia
the_column = :weight_kg
@combine(df, :total_weight = sum($the_column))
```

```
1×1 DataFrame
 Row │ total_weight
     │ Float64
─────┼──────────────
   1 │      303.229
```

```julia
a_string = "weight"
@combine(df, :total_weight = sum($(a_string * "_kg")))
```

```
1×1 DataFrame
 Row │ total_weight
     │ Float64
─────┼──────────────
   1 │      303.229
```

### passmissing flag @m

```julia
df = DataFrame(name = ["joe", "jim", missing, "james"])

@transform(df, :cap_name = @m uppercasefirst(:name))
```

```
4×2 DataFrame
 Row │ name     cap_name
     │ String?  String?
─────┼───────────────────
   1 │ joe      Joe
   2 │ jim      Jim
   3 │ missing  missing
   4 │ james    James
```

### escaping symbols

The `$` symbol usually signals that an expression is to be used as a column identifier.
The only exception is `$` in front of a bare symbol.
In that case, it signals that the symbol should be left as it is.

```julia
df = DataFrame(color = [:red, :green, :blue])
@transform(df, :is_red = :color == $:red)
```

```
3×2 DataFrame
 Row │ color   is_red
     │ Symbol  Bool
─────┼────────────────
   1 │ red       true
   2 │ green    false
   3 │ blue     false
```

