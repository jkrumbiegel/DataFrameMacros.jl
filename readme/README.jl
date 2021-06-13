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
# - Column expressions are interpolated into the macro with `$`.
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


# ### @select
@select(df, :height_m = :height_cm / 100)
#-
@select(df, AsTable = (w = :weight_kg, h = :height_cm))

# ### @transform
@transform(df, :weight_g = :weight_kg / 1000)
#-
@transform(df, :BMI = :weight_kg / (:height_cm / 100) ^ 2)
# #### column flag @c
@transform(df, :weight_z = @c (:weight_kg .- mean(:weight_kg)) / std(:weight_kg))


# ### @groupby & @combine
g = @groupby(df, iseven(:id))
#-
@combine(g, :total_weight_kg = sum(:weight_kg))

# ### @sort

@sort(df, -sqrt(:height_cm))

# ### interpolating column expressions

# If you have a variable or expression that you want to use as a column identifier, interpolate it into the macro with `$`.

the_column = :weight_kg
@combine(df, :total_weight = sum($the_column))
#-

a_string = "weight"
@combine(df, :total_weight = sum($(a_string * "_kg")))

# ### passmissing flag @m

df = DataFrame(name = ["joe", "jim", missing, "james"])

@transform(df, :cap_name = @m uppercasefirst(:name))



# ### escaping symbols

# The `$` symbol usually signals that an expression is to be used as a column identifier.
# The only exception is `$` in front of a bare symbol.
# In that case, it signals that the symbol should not be used as a column.

df = DataFrame(color = [:red, :green, :blue])
@transform(df, :is_red = :color == $:red)
