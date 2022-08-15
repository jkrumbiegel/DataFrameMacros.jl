# # DataFrameMacros.jl

# DataFrameMacros.jl is an opinionated take on DataFrame manipulation in Julia with a syntax geared towards clarity, brevity and convenience.
# It offers macros that translate expressions into [DataFrames.jl](https://github.com/JuliaData/DataFrames.jl) function calls.

# Here is a simple example:

using DataFrameMacros #hide
using DataFrames #hide
df = DataFrame(name = ["Mary Louise Parker", "Thomas John Fisher"])
@transform(df, :middle_initial = split(:name)[2][1] * ".")


# Unlike DataFrames.jl, most operations are **row-wise** by default.
# This often results in cleaner code that's easier to understand and reason about, especially when string or object manipulation is involved.
# Such operations often don't have a clean broadcasting syntax, for example, `somestring[2]` is easier to read than `getindex.(somestrings, 2)`.
# The same is true for `someobject.property` and `getproperty.(someobjects, :property)`.

# The following macros are currently available:
# - `@transform` / `@transform!`
# - `@select` / `@select!`
# - `@groupby`
# - `@combine`
# - `@subset` / `@subset!`
# - `@sort` / `@sort!`
# - `@unique`

# Together with [Chain.jl](https://github.com/jkrumbiegel/Chain.jl), you get a convient syntax for chains of transformations:

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

# ## Design choices

# These are the most important aspects that differ from other packages ([DataFramesMeta.jl](https://github.com/JuliaData/DataFramesMeta.jl) in particular):

# - All macros except `@combine` work **row-wise** by default. This reduces syntax complexity in most cases because no broadcasting is necessary. A modifier macro (`@bycol` or `@byrow`) can be used to switch between row/column-based mode when needed.
# - `@groupby` and `@sort` allow using arbitrary expressions including multiple columns, without having to `@transform` first and repeat the new column names.
# - Column expressions are interpolated into the macro with `$`.
# - Keyword arguments to the macro-underlying functions work by separating them from column expressions with the `;` character.
# - Target column names are written with `:` symbols to avoid visual ambiguity (`:newcol = ...`). This also allows to use `AsTable` as a target like in DataFrames.jl.
# - The modifier macro can also include the character `m` to switch on automatic `passmissing` in row-wise mode.
# - There is also a `@astable` modifier macro, which extracts every `:sym = expression` expression and collects the new symbols in a named tuple, while setting the target to `AsTable`.

# ## Examples

# TOC

using DataFrameMacros
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
@transform(df, :weight_g = :weight_kg * 1000)
#-
@transform(df, :BMI = :weight_kg / (:height_cm / 100) ^ 2)
# #### column modifier @bycol
@transform(df, :weight_z = @bycol (:weight_kg .- mean(:weight_kg)) / std(:weight_kg))


# ### @groupby & @combine
g = @groupby(df, iseven(:id))
#-
@combine(g, :total_weight_kg = sum(:weight_kg))

# ### @sort

@sort(df, sqrt(:height_cm) / :weight_kg; rev = true)

# ### @unique

namedf = DataFrame(name = ["Joe Smith", "Eric Miller", "Frank Smith"])
@unique(namedf, last(split(:name)))

# ### interpolating column expressions

# If you have a variable or expression that you want to use as a column identifier, interpolate it into the macro with `$`.

the_column = :weight_kg
@combine(df, :total_weight = sum($the_column))
#-

a_string = "weight"
@combine(df, :total_weight = sum($(a_string * "_kg")))

# You can use strings and integers directly with `$`.
@combine(df, :sum = sum($"weight_kg" .* $4))

# ### modifier @passmissing

df = DataFrame(name = ["joe", "jim", missing, "james"])

@transform(df, :cap_name = @passmissing uppercasefirst(:name))



# ### escaping symbols

# The `$` symbol usually signals that an expression is to be used as a column identifier.
# The only exception is `$` in front of a bare symbol.
# In that case, it signals that the symbol should be left as it is.

df = DataFrame(color = [:red, :green, :blue])
@transform(df, :is_red = :color == $:red)


# ### `@astable` modifier macro for automatic `AsTable`

# To use `AsTable` as a target, you usually have to construct a NamedTuple in the passed function.
# You can avoid both passing `AsTable` explicitly and constructing the NamedTuple by using the `@astable` modifier macro.
# All expressions of the type `:symbol = expression` are collected, the `:symbol`s are replaced with anonymous variables, and these variables are collected in a NamedTuple as the return value automatically.

df = DataFrame(a = 1:3, b = 4:6)
df2 = @transform df @astable begin
    x = :a + :b
    :y = x * 2
    :z = x + 4
end

# ### block syntax

# You can pass a begin/end block to every macro instead of multiple separate arguments.

df = DataFrame(
    id = shuffle(1:5),
    group = rand('a':'b', 5),
    weight_kg = randn(5) .* 5 .+ 60,
    height_cm = randn(5) .* 10 .+ 170)

@transform df begin
    :weight_g = :weight_kg / 1000
    :BMI = :weight_kg / (:height_cm / 100) ^ 2
    :weight_z = @bycol (:weight_kg .- mean(:weight_kg)) / std(:weight_kg)
end