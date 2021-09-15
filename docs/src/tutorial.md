# Tutorial

```@setup
ENV["COLUMNS"] = 200
ENV["LINES"] = 16
```

In this tutorial, we'll get to know the macros of DataFrameMacros while working with the well-known [Titanic dataset from Kaggle](https://www.kaggle.com/c/titanic/).

## Loading the data

The `titanic` function returns the `DataFrame` with data about passengers of the Titanic.

```@repl 1
using DataFrameMacros, DataFrames, Statistics

df = DataFrameMacros.titanic()
```
## @select

The simplest operation one can do is to select columns from a DataFrame.
DataFrames.jl has the `select` function for that purpose and DataFramesMacro has the corresponding `@select` macro.
We can pass symbols or strings with column names that we're interested in.

```@repl 1
@select(df, :Name, :Age, :Survived)
```

We can also compute new columns with `@select`.
We can either specify a new column ourselves, or DataFrames selects an automatic name.

For example, we can extract the last name from each name string by splitting at the comma.

```@repl 1
@select(df, :last_name = split(:Name, ",")[1])
```

The `split` function operates on a single string, so for this expression to work on the whole column `:Name`, there must be an implicit broadcast expansion happening.
In DataFrameMacros, every macro but `@combine` works **by-row** by default.
The expression that the `@select` macro creates is equivalent to the following `ByRow` construct:

```julia
select(df, :Name => ByRow(x -> split(x, ",")[1]) => :last_name)
```

## @transform

Another thing we can try is to categorize every passenger into child or adult at the boundary of 18 years.

Let's use the `@transform` macro this time, which appends new columns to an existing DataFrame.

```@repl 1
@transform(df, :type = :Age >= 18 ? "adult" : "child")
```

This command fails because some passengers have no age recorded, and the ternary operator `... ? ... : ...` (a shortcut for `if ... then ... else ...`) cannot operate on `missing` values.

## The @m `passmissing` flag macro

One option is to remove the missing values beforehand, but then we would have to delete rows from the dataset.
A simple option to make the expression pass through missing values, is by using the special flag macro `@m`.

```@repl 1
@transform(df, :type = @m :Age >= 18 ? "adult" : "child")
```

This is equivalent to a DataFrames construct, in which the function is wrapped in `passmissing`:

```julia
transform(df, :Age => ByRow(passmissing(x -> x >= 18 ? "adult" : "child")) => :type)
```

This way, if any input argument is `missing`, the function returns `missing`, too.

## @subset

To retain only rows that fulfill certain conditions, you can use the `@subset` macro. For this macro it does not make sense to specify sink column names, because derived columns do not appear in the result. If there are `missing` values, you can use the `@m` flag to pass them through the boolean condition, and add the keyword argument `skipmissing = true` which the underlying `subset` function requires to remove such rows.

```@repl 1
@subset(df, @m startswith(:Name, "M") && :Age > 50; skipmissing = true)
```

## @groupby

The `groupby` function in DataFrames does not use the `src => function => sink` mini-language, it requires you to create any columns you want to group by beforehand.
In DataFrameMacros, the `@groupby` macro works like a `transform` and `groupby` combination, so that you can create columns and group by them in one stroke.

For example, we could group the passengers based on if their last name begins with a letter from the first or the second half of the alphabet.

```@repl 1
@groupby(df, :alphabet_half = :Name[1] <= 'M' ? "first" : "second")
```

## `begin ... end` syntax

You can of course group by multiple columns, in that case just add more positional arguments.
In order to write more readable code, we can arrange our multiple arguments as lines in a `begin ... end` block instead of two comma-separated positional arguments.

```@repl 1
group = @groupby df begin
    :alphabet_half = :Name[1] <= 'M' ? "first" : "second"
    :Sex
end
```

## @combine

We can compute summary statistics on groups using the `@combine` macro.
This is the only macro that works **by-column** by default because aggregations are most commonly computed on full columns, not on each row.

For example, we can compute survival rates for the groups we created above.

```@repl 1
@combine(group, :survival_rate = mean(:Survived))
```

## @chain

The `@chain` macro from [Chain.jl](https://github.com/jkrumbiegel/Chain.jl) is useful to build sequences of operations.
It is not included in DataFrameMacros but works well with it.

In a chain, the first argument of each function or macro call is by default the result from the previous line.

```@repl 1
using Chain

@chain df begin
    @select(:Sex, :Age, :Survived)
    dropmissing(:Age)
    @groupby(:Sex, :age_range =
        floor(Int, :Age/10) * 10 : ceil(Int, :Age/10) * 10 - 1)
    @combine(:survival_rate = mean(:Survived))
    @sort(first(:age_range), :Sex)
end
```

Here you could also see the `@sort` macro, which is useful when you want to sort by values that are derived from different columns, but which you don't want to include in the DataFrame.

## The @c flag macro

Some `@transform` or `@select` calls require access to whole columns at once.
One scenario is computing a z-score.
Because `@transform` and `@select` work **by-row** by default, you need to add the `@c` flag macro to signal that you want to work **by-column**.
This is exactly the opposite from DataFrames, where you work **by-column** by default and signal by-row behavior with the `ByRow` wrapper.

```@repl 1
@select(
    dropmissing(df, :Age),
    :age_z = @c (:Age .- mean(:Age)) ./ std(:Age))
```

## The @t flag macro

If a computation should return multiple different columns, DataFrames allows you to do this by returning a `NamedTuple` and setting the sink argument to `AsTable`.
To streamline this process you can use the `@t` flag macro.
It signals that all `:symbol = expression` expressions that are found are rewritten so that a `NamedTuple` like `(symbol = expression, symbol2...)` is returned and the sink argument is set to `AsTable`.

```@repl 1
@select(df, @t begin
    nameparts = split(:Name, r"[\s,]+")
    :title = nameparts[2]
    :first_name = nameparts[3]
    :last_name = nameparts[1]
end)
```