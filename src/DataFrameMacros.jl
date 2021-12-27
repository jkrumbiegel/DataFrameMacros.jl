module DataFrameMacros

using Base: ident_cmp
using DataFrames: DataFrames, transform, transform!, select, select!, combine, subset, subset!, ByRow, passmissing, groupby, AsTable, DataFrame, GroupedDataFrame

export @transform, @transform!, @select, @select!, @combine, @subset, @subset!, @groupby, @sort, @sort!, @unique

funcsymbols = :transform, :transform!, :select, :select!, :combine, :subset, :subset!, :unique

subset_argument_docs(f) = """
## @subset argument

You can pass a `@subset` expression as the second argument to `@$f`,
between the input argument and the source-function-sink expressions.
Then, the call is equivalent to first taking a `subset` of the input
with `view = true`, then calling `$f` on the subset and returning the
mutated input. If the input is a `GroupedDataFrame`, the parent `DataFrame` is returned.

```julia
df = DataFrame(x = 1:5, y = 6:10)
@$f(df, @subset(:x > 3), :y = 20, :z = 3 * :x)
```
"""

for f in funcsymbols
    @eval begin
        """
            @$($f)(df, args...; kwargs...)

        The `@$($f)` macro builds a `DataFrames.$($f)` call. Each expression in `args` is converted to a `src => function => sink` construct that conforms to the transformation mini-language of DataFrames.

        Keyword arguments `kwargs` are passed down to `$($f)` but have to be separated from the positional arguments by a semicolon `;`.

        The transformation logic for all DataFrameMacros macros is explained in the `DataFrameMacros` module docstring, accessible via `?DataFrameMacros`.

        $($f in (transform!, select!) ? subset_argument_docs($f) : "")
        """
        macro $f(exprs...)
            macrohelper($(QuoteNode(f)), exprs...)
        end
    end
end

function defaultbyrow(s::Symbol)
    if s == :transform
        true
    elseif s == :select
        true
    elseif s == :subset
        true
    elseif s == :transform!
        true
    elseif s == :select!
        true
    elseif s == :subset!
        true
    elseif s == :combine
        false
    elseif s == :unique
        true
    else
        error("Unknown symbol $s")
    end
end


macro groupby(exprs...)
    f = :select
    df, subset_expr, func, kw_exprs = df_funcs_kwexprs(f, exprs...)

    select_kwexprs = [Expr(:kw, :copycols, false)]
    select_call = build_call(f, df, func, select_kwexprs)
    quote
        temp = $select_call
        df_copy = copy($(esc(df)))
        for name in names(temp)
            df_copy[!, name] = temp[!, name]
        end
        groupby(df_copy, names(temp); $(kw_exprs...))
    end
end

macro sort(exprs...)
    sorthelper(exprs...; mutate = false)
end

macro sort!(exprs...)
    sorthelper(exprs...; mutate = true)
end

function sorthelper(exprs...; mutate)
    f = :select
    df, subset_expr, func, kw_exprs = df_funcs_kwexprs(f, exprs...)

    select_kwexprs = [Expr(:kw, :copycols, false)]
    select_call = build_call(f, df, func, select_kwexprs)
    if mutate
        quote
            temp = $select_call
            sp = sortperm(temp; $(kw_exprs...))
            $(esc(df)) = $(esc(df))[sp, :]
        end
    else
        quote
            temp = $select_call

            sp = sortperm(temp; $(kw_exprs...))
            
            df_copy = copy($(esc(df)))
            df_copy[sp, :]
        end
    end
end

function macrohelper(f, exprs...)
    df, subset_expr, converted, kw_exprs = df_funcs_kwexprs(f, exprs...)

    if subset_expr !== nothing
        dfsym = gensym()
        dfsym_e = esc(dfsym)
        subset_converted = convert_subset_expr(subset_expr, dfsym)
        subset_converted_ungroup_false = copy(subset_converted)
        scg = subset_converted_ungroup_false

        if scg.args[2] isa Expr && scg.args[2].head == :parameters
            push!(scg.args[2].args, Expr(:kw, :ungroup, false))
        else
            insert!(scg.args, 2, Expr(:parameters, Expr(:kw, :ungroup, false)))
        end

        subs = gensym()
        call_expr = build_call(f, subs, converted, kw_exprs)
        e = quote
            let
                $dfsym_e = $(esc(df))
                if $dfsym_e isa GroupedDataFrame
                    $(esc(subs)) = $subset_converted_ungroup_false
                else
                    $(esc(subs)) = $subset_converted
                end
                $call_expr
                if $dfsym_e isa GroupedDataFrame
                    parent($dfsym_e)
                else
                    $dfsym_e
                end
            end
        end
        return e
    else
        return build_call(f, df, converted, kw_exprs)
    end
end

function convert_subset_expr(subset_expr, df)
    args = subset_expr.args[3:end]
    viewtrue_kw = Expr(:kw, :view, true)
    if args[1] isa Expr && args[1].head == :parameters
        push!(args[1].args, viewtrue_kw)
        insert!(args, 2, df)
    else
        insert!(args, 1, df)
        insert!(args, 1, Expr(:parameters, viewtrue_kw))
    end
    macrohelper(:subset, args...)
end

function build_call(f, df, converted, kw_exprs)
    :($f($(esc(df)), $(converted...); $(map(esc, kw_exprs)...)))
end

function extract_subset_expr!(exprs, f)
    subset_expr = nothing

    i_subsets = findall(is_subset_expr, exprs)

    if !isempty(i_subsets) && f ∉ (:transform!, :select!)
        error("The `@subset` argument syntax only works with `@transform!` and `@select!`, not `@$f`")
    end

    if length(i_subsets) > 1
        error("Only one @subset argument allowed, found $(length(i_subsets))")
    elseif length(i_subsets) == 1
        if first(i_subsets) != 1
            error("A @subset expression must be used after the dataframe argument and before all source-function-sink expressions.")
        end
        subset_expr = popfirst!(exprs)
    end

    subset_expr
end

function df_funcs_kwexprs(f, exprs...)

    exprs = [exprs...]

    if length(exprs) >= 1 && exprs[1] isa Expr && exprs[1].head == :parameters
        kw_exprs = exprs[1].args
        df = exprs[2]
        source_func_sink_exprs = exprs[3:end]
    else
        df = exprs[1]
        source_func_sink_exprs = exprs[2:end]
        kw_exprs = []
    end

    subset_expr = extract_subset_expr!(source_func_sink_exprs, f)

    if length(source_func_sink_exprs) == 1 && is_block_expression(source_func_sink_exprs[1])
        source_func_sink_exprs = extract_source_func_sink_exprs_from_block(
            source_func_sink_exprs[1])
    end

    converted = map(e -> convert_source_funk_sink_expr(f, e, df), source_func_sink_exprs)
    df, subset_expr, converted, kw_exprs
end

is_subset_expr(x) = false
is_subset_expr(e::Expr) = e.head == :macrocall &&
    e.args[1] == Symbol("@subset")

is_block_expression(x) = false
is_block_expression(e::Expr) = e.head == :block

function extract_source_func_sink_exprs_from_block(block::Expr)
    filter(x -> !(x isa LineNumberNode), block.args)
end


convert_source_funk_sink_expr(f, x, df) = x

function convert_source_funk_sink_expr(f, e::Expr, df)
    target, formula = split_formula(e)
    flags, formula = extract_macro_flags(formula)

    if 't' in flags
        if target !== nothing
            error("There should be no target expression when the @t flag is used. The implicit target is `AsTable`. Target received was $target")
        end
        target_expr = :(DataFrames.AsTable)
        formula = convert_automatic_astable_formula(formula)
    else
        target_expr = make_target_expression(df, target)
    end

    formula_is_column = is_column_expr(formula)

    columns = gather_columns(formula)
    func, columns = make_function_expr(formula, columns)
    clean_columns = map(c -> clean_column(c, df), columns)
    stringified_columns = [esc(stringarg_expr(c, df)) for c in clean_columns]

    byrow = (defaultbyrow(f) && !('c' in flags)) ||
        (!defaultbyrow(f) && ('r' in flags))

    pass_missing = 'm' in flags

    func_esc = esc(func)

    if pass_missing
        func_esc = :(passmissing($func_esc))
    end

    func_esc = byrow ? :(ByRow($func_esc)) : :($func_esc)

    trans_expr = if target_expr === nothing
        if formula_is_column
            :($(stringified_columns...) .=> $(stringified_columns...))
        else
            :($(esc(vcat)).($(stringified_columns...)) .=> $func_esc)
        end
    else
        if formula_is_column
            :($(stringified_columns...) .=> $(esc(target_expr)))
        else
            :($(esc(vcat)).($(stringified_columns...)) .=> $func_esc .=> $(esc(target_expr)))
        end
    end
end

function make_target_expression(df, expr)
    # not really columns but resolved names
    columns = gather_columns(expr)
    clean_columns = map(c -> clean_column(c, df), columns)

    replaced_expr = postwalk(expr) do e
        # check first if this is an escaped symbol
        # and if yes return it unwrapped
        if is_escaped_symbol(e)
            return e.args[1]
        end

        # check if this expression matches one of the column expressions
        # and wrap it in names(df, ex) if it matches
        i = findfirst(c -> c == e, columns)
        if i === nothing
            e
        else
            c = clean_columns[i]
            stringarg_expr(c, df)
        end
    end

    replaced_expr
end

function split_formula(e::Expr)
    if e.head != :(=)
        target = nothing
        formula = e
    else
        target = e.args[1]
        formula = e.args[2]
    end
    target, formula
end

function gather_columns(x; unique = true)
    columns = []
    gather_columns!(columns, x; unique = unique)
    columns
end

function gather_columns!(columns, x; unique)
    if is_column_expr(x)
        if !unique || x ∉ columns
            push!(columns, x)
        end
    elseif x isa Expr && !(is_escaped_symbol(x)) && !(is_dot_quotenode_expr(x))
        # we have to exclude quotenodes in dot syntax such as the b in `:a.b`
        args_to_scan = if x.head == :. && length(x.args) == 2 && x.args[2] isa QuoteNode
            x.args[1:1]
        else
            x.args
        end
        foreach(args_to_scan) do arg
            gather_columns!(columns, arg; unique = unique)
        end
    end
end

flagchars = "crmt"

extract_macro_flags(x) = "", x

function extract_macro_flags(e::Expr)
    if e.head == :macrocall && all(char -> occursin(char, flagchars), string(e.args[1])[2:end]) &&
            length(e.args) == 3
        string(e.args[1])[2:end], e.args[3] 
    else
        "", e
    end
end

is_dot_quotenode_expr(x) = false
# matches Module.[Submodule.Subsubmodule...].value
function is_dot_quotenode_expr(e::Expr)
    e.head == :(.) &&
        length(e.args) == 2 &&
        (e.args[1] isa Symbol || is_dot_quotenode_expr(e.args[1])) &&
        e.args[2] isa QuoteNode
end

is_column_expr(q::QuoteNode) = true
is_column_expr(x) = false
function is_column_expr(e::Expr)
    e.head == :call && e.args[1] in (:Not, :Between, :All) ||
        (e.head == :$ && !is_escaped_symbol(e))
end

function make_function_expr(formula, columns)
    is_simple, symbol = is_simple_function_call(formula, columns)
    if is_simple
        # :a + :a returns only +(:a) if we don't set unique false
        return symbol, gather_columns(formula; unique = false)
    end

    newsyms = map(x -> gensym(), columns)
    replaced_formula = postwalk(formula) do e
        # check first if this is an escaped symbol
        # and if yes return it unwrapped
        if is_escaped_symbol(e)
            return e.args[1]
        end

        # check if this expression matches one of the column expressions
        # and replace it with a newsym if it matches
        i = findfirst(c -> c == e, columns)
        if i === nothing
            e
        else
            newsyms[i]
        end
    end
    expr = quote
        ($(newsyms...),) -> $replaced_formula
    end
    expr, columns
end

stringarg_expr(x, df) = :(DataFrameMacros.stringargs($x, $df))
stringarg_expr(x::String, df) = x

clean_column(x::QuoteNode, df) = string(x.value)
clean_column(x, df) = :(DataFrameMacros.stringargs($x, $df))
clean_column(x::String, df) = x
function clean_column(e::Expr, df)
    stripped_e = if e.head == :$
        e.args[1]
    else
        e
    end
end

stringargs(x, df) = names(df, x)
stringargs(a::AbstractVector, df) = names(df, a)
# this is needed because from matrix up `names` fails
function stringargs(a::AbstractArray, df)
    s = size(a)
    reshape(names(df, vec(a)), s)
end

stringargs(sym::Symbol, df) = string(sym)
stringargs(s::String, df) = s

is_escaped_symbol(e::Expr) = e.head == :$ && length(e.args) == 1 && e.args[1] isa QuoteNode
is_escaped_symbol(x) = false

is_simple_function_call(x, columns) = false, nothing
function is_simple_function_call(expr::Expr, columns)
    is_call = expr.head == :call
    no_columns_in_funcpart = isempty(gather_columns(expr.args[1]))
    only_columns_in_argpart = length(expr.args) >= 2 &&
        all(x -> x in columns, expr.args[2:end])

    is_simple = is_call && no_columns_in_funcpart && only_columns_in_argpart

    is_simple, expr.args[1]
end

# from macrotools
walk(x, inner, outer) = outer(x)
walk(x::Expr, inner, outer) = outer(Expr(x.head, map(inner, x.args)...))
postwalk(f, x) = walk(x, x -> postwalk(f, x), f)


convert_automatic_astable_formula(x) = x
function convert_automatic_astable_formula(e::Expr)
    e_replaced, assigned_symbols, gensyms = replace_assigned_symbols(e)
    Expr(:block,
        e_replaced,
        Expr(:tuple,
            map(assigned_symbols, gensyms) do a, g
                Expr(:(=), a, g)
            end...
        )
    )
end

function replace_assigned_symbols(e)
    symbols = Symbol[]
    gensyms = Symbol[]

    function gensym_for_sym(sym)
        i = findfirst(==(sym), symbols)

        if i === nothing
            push!(symbols, sym)
            gs = gensym()
            push!(gensyms, gs)
        else
            gs = gensyms[i]
        end
        gs
    end

    new_ex = postwalk(e) do x
        # normal case :symbol = expression
        if x isa Expr && x.head == :(=) && x.args[1] isa QuoteNode
            sym = x.args[1].value
            gs = gensym_for_sym(sym)
            Expr(:(=), gs, x.args[2:end]...)
        # tuple destructuring case x, y = expr1, expr2 where x or y (or others) are :symbols
        elseif x isa Expr && x.head == :(=) && x.args[1] isa Expr && x.args[1].head == :tuple
            for (i, a) in enumerate(x.args[1].args)
                if a isa QuoteNode
                    sym = a.value
                    x.args[1].args[i] = gensym_for_sym(sym)
                end
            end
            x
        else
            x
        end
    end
    new_ex, symbols, gensyms
end


@doc """
DataFrameMacros offers macros which transform expressions for DataFrames functions that use the `source => function => sink` mini-language.
The supported functions are `@transform`/`@transform!`, `@select/@select!`, `@groupby`, `@combine`, `@subset`/`@subset!`, `@sort`/`@sort!` and `@unique`.

All macros have signatures of the form:
```julia
@macro(df, args...; kwargs...)
```

Each positional argument in `args` is converted to a `source .=> function .=> sink` expression for the transformation mini-language of DataFrames.
By default, all macros execute the given function **by-row**, only `@combine` executes **by-column**.
There is automatic broadcasting across all column specifiers, so it is possible to directly use multi-column specifiers such as `All()`, `Not(:x)`, `r"columnname"` and `startswith("prefix")`.

For example, the following pairs of expressions are equivalent:

```julia
transform(df, :x .=> ByRow(x -> x + 1) .=> :y)
@transform(df, :y = :x + 1)

select(df, names(df, All()) .=> ByRow(x -> x ^ 2))
@select(df, \$(All()) ^ 2)

combine(df, :x .=> (x -> sum(x) / 5) .=> :result)
@combine(df, :result = sum(:x) / 5)
```

## Column references

Each positional argument must be of the form `[sink =] some_expression`.
Columns can be referenced within `sink` or `some_expression` using a `Symbol`, a `String`, or an `Int`.
Any column identifier that is not a `Symbol` must be prefaced with the interpolation symbol `\$`.
The `\$` interpolation symbol also allows to use variables or expressions that evaluate to column identifiers.

The five expressions in the following code block are equivalent.

```julia
using DataFrames
using DataFrameMacros

df = DataFrame(x = 1:3)

@transform(df, :y = :x + 1)
@transform(df, :y = \$"x" + 1)
@transform(df, :y = \$1 + 1)
col = :x
@transform(df, :y = \$col + 1)
cols = [:x, :y, :z]
@transform(df, :y = \$(cols[1]) + 1)
```

## Passing multiple expressions

Multiple expressions can be passed as multiple positional arguments, or alternatively as separate lines in a `begin end` block. You can use parentheses, or omit them. The following expressions are equivalent:

```julia
@transform(df, :y = :x + 1, :z = :x * 2)
@transform df :y = :x + 1 :z = :x * 2
@transform df begin
    :y = :x + 1
    :z = :x * 2
end
@transform(df, begin
    :y = :x + 1
    :z = :x * 2
end)
```

## Flag macros

You can modify the behavior of all macros using flag macros, which are not real macros but only signal changed behavior for a positional argument to the outer macro.

Each flag is specified with a single character, and you can combine these characters as well.
The supported flags are:

| character | meaning |
|:--|:--|
| r | Switch to **by-row** processing. |
| c | Switch to **by-column** processing. |
| m | Wrap the function expression in `passmissing`. |
| t | Collect all `:symbol = expression` expressions into a `NamedTuple` where `(; symbol = expression, ...)` and set the sink to `AsTable`. |

### Example `@c`

To compute a centered column with `@transform`, you need access to the whole column at once and signal this with the `@c` flag.

```julia
using Statistics
using DataFrames
using DataFrameMacros

julia> df = DataFrame(x = 1:3)
3×1 DataFrame
 Row │ x     
     │ Int64 
─────┼───────
   1 │     1
   2 │     2
   3 │     3

julia> @transform(df, :x_centered = @c :x .- mean(:x))
3×2 DataFrame
 Row │ x      x_centered 
     │ Int64  Float64    
─────┼───────────────────
   1 │     1        -1.0
   2 │     2         0.0
   3 │     3         1.0
```

### Example `@m`

Many functions need to be wrapped in `passmissing` to correctly return `missing` if any input is `missing`.
This can be achieved with the `@m` flag macro.

```julia
julia> df = DataFrame(name = ["alice", "bob", missing])
3×1 DataFrame
 Row │ name    
     │ String? 
─────┼─────────
   1 │ alice
   2 │ bob
   3 │ missing 

julia> @transform(df, :name_upper = @m uppercasefirst(:name))
3×2 DataFrame
 Row │ name     name_upper 
     │ String?  String?    
─────┼─────────────────────
   1 │ alice    Alice
   2 │ bob      Bob
   3 │ missing  missing    
```

### Example `@t`

In DataFrames, you can return a `NamedTuple` from a function and then automatically expand it into separate columns by using `AsTable` as the sink value. To simplify this process, you can use the `@t` flag macro, which collects all statements of the form `:symbol = expression` in the function body, collects them into a `NamedTuple`, and sets the sink argument to `AsTable`.

```julia
julia> df = DataFrame(name = ["Alice Smith", "Bob Miller"])
2×1 DataFrame
 Row │ name        
     │ String      
─────┼─────────────
   1 │ Alice Smith
   2 │ Bob Miller

julia> @transform(df, @t begin
           s = split(:name)
           :first_name = s[1]
           :last_name = s[2]
       end)
2×3 DataFrame
 Row │ name         first_name  last_name  
     │ String       SubString…  SubString… 
─────┼─────────────────────────────────────
   1 │ Alice Smith  Alice       Smith
   2 │ Bob Miller   Bob         Miller
```

The `@t` flag also works with tuple destructuring syntax, so the previous example can be shortened to:

```julia
@transform(df, @t :first_name, :last_name = split(:name))
```

""" DataFrameMacros

const _titanic = include("titanic.jl")
titanic() = deepcopy(_titanic)

end