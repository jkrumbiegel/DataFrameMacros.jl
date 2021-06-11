# # DFMacros

# This package offers an opinionated take on DataFrame manipulation in Julia.

# The following macros are currently available:
# - `@transform`
# - `@select`
# - `@groupby`
# - `@combine`
# - `@subset`
# - `@sort`

# These are the most important opinionated aspects that differ from other packages:
# - `@transform`, `@select` and `@subset` work row-wise by default, `@combine` works column-wise by default. This matches the most common modes these functions are used in and reduces friction.
# - `@groupby` and `@sort` allow using arbitrary expressions including multiple columns, without having to `@transform` first and repeat the new column names.
# - Keyword arguments to the macro-underlying functions work by separating them from column expressions with the `;` character.
# - Target column names are written with `:` symbols to avoid visual ambiguity (`:newcol = ...`). This also allows to use `AsTable` as a target like in DataFrames.jl.
# - A flag macro (`@c` or `@r`) can be used to switch between row/column-based mode.
# - The flag macro can also include the character `m` to switch on automatic `passmissing` in row-wise mode.

# ## Examples

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


#-
@select(df, :height_m = :height_cm / 100)
#-
@transform(df, :weight_g = :weight_kg / 1000)
#-
@transform(df, :BMI = :weight_kg / (:height_cm / 100) ^ 2)
#-
@transform(df, :weight_z = @c (:weight_kg .- mean(:weight_kg)) / std(:weight_kg))
#-
g = @groupby(df, iseven(:id))
#-
@combine(g, :total_weight_kg = sum(:weight_kg))
#-
@sort(df, -sqrt(:height_cm))