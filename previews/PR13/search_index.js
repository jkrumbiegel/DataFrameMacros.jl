var documenterSearchIndex = {"docs":
[{"location":"macros/#Macros","page":"Macros","title":"Macros","text":"","category":"section"},{"location":"macros/","page":"Macros","title":"Macros","text":"Modules = [DataFrameMacros]","category":"page"},{"location":"macros/#DataFrameMacros.DataFrameMacros","page":"Macros","title":"DataFrameMacros.DataFrameMacros","text":"DataFrameMacros offers macros which transform expressions for DataFrames functions that use the source => function => sink mini-language. The supported functions are @transform/@transform!, @select/@select!, @groupby, @combine, @subset/@subset!, @sort/@sort! and @unique.\n\nAll macros have signatures of the form:\n\n@macro(df, args...; kwargs...)\n\nEach positional argument in args is converted to a source => function => sink expression for the transformation mini-language of DataFrames. By default, all macros execute the given function by-row, only @combine executes by-column.\n\nFor example, the following pairs of expressions are equivalent:\n\ntransform(df, :x => ByRow(x -> x + 1) => :y)\n@transform(df, :y = :x + 1)\n\nsort(df, :x => x -> x ^ 2)\n@sort(df, :x ^ 2)\n\ncombine(df, :x => (x -> sum(x) / 5) => :result)\n@combine(df, :result = sum(:x) / 5)\n\nColumn references\n\nEach positional argument must be of the form [sink =] some_expression. Columns can be referenced within sink or some_expression using a Symbol, a String, or an Int. Any column identifier that is not a Symbol must be prefaced with the interpolation symbol $. The $ interpolation symbol also allows to use variables or expressions that evaluate to column identifiers.\n\nThe five expressions in the following code block are equivalent.\n\nusing DataFrames\nusing DataFrameMacros\n\ndf = DataFrame(x = 1:3)\n\n@transform(df, :y = :x + 1)\n@transform(df, :y = $\"x\" + 1)\n@transform(df, :y = $1 + 1)\ncol = :x\n@transform(df, :y = $col + 1)\ncols = [:x, :y, :z]\n@transform(df, :y = $(cols[1]) + 1)\n\nPassing multiple expressions\n\nMultiple expressions can be passed as multiple positional arguments, or alternatively as separate lines in a begin end block. You can use parentheses, or omit them. The following expressions are equivalent:\n\n@transform(df, :y = :x + 1, :z = :x * 2)\n@transform df :y = :x + 1 :z = :x * 2\n@transform df begin\n    :y = :x + 1\n    :z = :x * 2\nend\n@transform(df, begin\n    :y = :x + 1\n    :z = :x * 2\nend)\n\nFlag macros\n\nYou can modify the behavior of all macros using flag macros, which are not real macros but only signal changed behavior for a positional argument to the outer macro.\n\nEach flag is specified with a single character, and you can combine these characters as well. The supported flags are:\n\ncharacter meaning\nr Switch to by-row processing.\nc Switch to by-column processing.\nm Wrap the function expression in passmissing.\nt Collect all :symbol = expression expressions into a NamedTuple where (; symbol = expression, ...) and set the sink to AsTable.\n\nExample @c\n\nTo compute a centered column with @transform, you need access to the whole column at once and signal this with the @c flag.\n\nusing Statistics\nusing DataFrames\nusing DataFrameMacros\n\ndf = DataFrame(x = 1:5)\n@transform(df, :x_centered = @c :x .- mean(:x))\n\nExample @m\n\nMany functions need to be wrapped in passmissing to correctly return missing if any input is missing. This can be achieved with the @m flag macro.\n\ndf = DataFrame(name = [\"alice\", \"bob\", missing])\n@transform(df, @m :name_upper = uppercasefirst(:name))\n\n\n\n\n\n","category":"module"},{"location":"macros/#DataFrameMacros.@combine-Tuple","page":"Macros","title":"DataFrameMacros.@combine","text":"@combine(df, args...; kwargs...)\n\nThe @combine macro converts an expression into\n\nThe transformation logic for all DataFrameMacros macros is explained in the DataFrameMacros docstring.\n\n\n\n\n\n","category":"macro"},{"location":"macros/#DataFrameMacros.@select!-Tuple","page":"Macros","title":"DataFrameMacros.@select!","text":"@select!(df, args...; kwargs...)\n\nThe @select! macro converts an expression into\n\nThe transformation logic for all DataFrameMacros macros is explained in the DataFrameMacros docstring.\n\n\n\n\n\n","category":"macro"},{"location":"macros/#DataFrameMacros.@select-Tuple","page":"Macros","title":"DataFrameMacros.@select","text":"@select(df, args...; kwargs...)\n\nThe @select macro converts an expression into\n\nThe transformation logic for all DataFrameMacros macros is explained in the DataFrameMacros docstring.\n\n\n\n\n\n","category":"macro"},{"location":"macros/#DataFrameMacros.@subset!-Tuple","page":"Macros","title":"DataFrameMacros.@subset!","text":"@subset!(df, args...; kwargs...)\n\nThe @subset! macro converts an expression into\n\nThe transformation logic for all DataFrameMacros macros is explained in the DataFrameMacros docstring.\n\n\n\n\n\n","category":"macro"},{"location":"macros/#DataFrameMacros.@subset-Tuple","page":"Macros","title":"DataFrameMacros.@subset","text":"@subset(df, args...; kwargs...)\n\nThe @subset macro converts an expression into\n\nThe transformation logic for all DataFrameMacros macros is explained in the DataFrameMacros docstring.\n\n\n\n\n\n","category":"macro"},{"location":"macros/#DataFrameMacros.@transform!-Tuple","page":"Macros","title":"DataFrameMacros.@transform!","text":"@transform!(df, args...; kwargs...)\n\nThe @transform! macro converts an expression into\n\nThe transformation logic for all DataFrameMacros macros is explained in the DataFrameMacros docstring.\n\n\n\n\n\n","category":"macro"},{"location":"macros/#DataFrameMacros.@transform-Tuple","page":"Macros","title":"DataFrameMacros.@transform","text":"@transform(df, args...; kwargs...)\n\nThe @transform macro converts an expression into\n\nThe transformation logic for all DataFrameMacros macros is explained in the DataFrameMacros docstring.\n\n\n\n\n\n","category":"macro"},{"location":"macros/#DataFrameMacros.@unique-Tuple","page":"Macros","title":"DataFrameMacros.@unique","text":"@unique(df, args...; kwargs...)\n\nThe @unique macro converts an expression into\n\nThe transformation logic for all DataFrameMacros macros is explained in the DataFrameMacros docstring.\n\n\n\n\n\n","category":"macro"},{"location":"#DataFrameMacros.jl","page":"DataFrameMacros.jl","title":"DataFrameMacros.jl","text":"","category":"section"},{"location":"","page":"DataFrameMacros.jl","title":"DataFrameMacros.jl","text":"DataFrameMacros.jl is an opinionated take on DataFrame manipulation in Julia with a syntax geared towards clarity, brevity and convenience. It offers macros that translate expressions into DataFrames.jl function calls.","category":"page"},{"location":"","page":"DataFrameMacros.jl","title":"DataFrameMacros.jl","text":"Here is a simple example:","category":"page"},{"location":"","page":"DataFrameMacros.jl","title":"DataFrameMacros.jl","text":"using DataFrameMacros #hide\nusing DataFrames #hide\ndf = DataFrame(name = [\"Mary Louise Parker\", \"Thomas John Fisher\"])\n\nresult = @transform(df, :middle_initial = split(:name)[2][1] * \".\")\n\nshow(result)","category":"page"},{"location":"","page":"DataFrameMacros.jl","title":"DataFrameMacros.jl","text":"Unlike DataFrames.jl, most operations are row-wise by default. This often results in cleaner code that's easier to understand and reason about, especially when string or object manipulation is involved. Such operations often don't have a clean broadcasting syntax, for example, somestring[2] is easier to read than getindex.(somestrings, 2). The same is true for someobject.property and getproperty.(someobjects, :property).","category":"page"},{"location":"","page":"DataFrameMacros.jl","title":"DataFrameMacros.jl","text":"The following macros are currently available:","category":"page"},{"location":"","page":"DataFrameMacros.jl","title":"DataFrameMacros.jl","text":"@transform / @transform!\n@select / @select!\n@groupby\n@combine\n@subset / @subset!\n@sort / @sort!\n@unique","category":"page"},{"location":"","page":"DataFrameMacros.jl","title":"DataFrameMacros.jl","text":"Together with Chain.jl, you get a convient syntax for chains of transformations:","category":"page"},{"location":"","page":"DataFrameMacros.jl","title":"DataFrameMacros.jl","text":"using DataFrameMacros\nusing DataFrames\nusing Chain\nusing Random\nusing Statistics\nRandom.seed!(123)\n\ndf = DataFrame(\n    id = shuffle(1:5),\n    group = rand('a':'b', 5),\n    weight_kg = randn(5) .* 5 .+ 60,\n    height_cm = randn(5) .* 10 .+ 170)\n\nresult = @chain df begin\n    @subset(:weight_kg > 50)\n    @transform(:BMI = :weight_kg / (:height_cm / 100) ^ 2)\n    @groupby(iseven(:id), :group)\n    @combine(:mean_BMI = mean(:BMI))\n    @sort(sqrt(:mean_BMI))\nend\n\nshow(result)","category":"page"},{"location":"#Design-choices","page":"DataFrameMacros.jl","title":"Design choices","text":"","category":"section"},{"location":"","page":"DataFrameMacros.jl","title":"DataFrameMacros.jl","text":"These are the most important aspects that differ from other packages (DataFramesMeta.jl in particular):","category":"page"},{"location":"","page":"DataFrameMacros.jl","title":"DataFrameMacros.jl","text":"All macros except @combine work row-wise by default. This reduces syntax complexity in most cases because no broadcasting is necessary. A flag macro (@c or @r) can be used to switch between row/column-based mode when needed.\n@groupby and @sort allow using arbitrary expressions including multiple columns, without having to @transform first and repeat the new column names.\nColumn expressions are interpolated into the macro with $.\nKeyword arguments to the macro-underlying functions work by separating them from column expressions with the ; character.\nTarget column names are written with : symbols to avoid visual ambiguity (:newcol = ...). This also allows to use AsTable as a target like in DataFrames.jl.\nThe flag macro can also include the character m to switch on automatic passmissing in row-wise mode.\nThere is also a @t flag macro, which extracts every :sym = expression expression and collects the new symbols in a named tuple, while setting the target to AsTable.","category":"page"}]
}
