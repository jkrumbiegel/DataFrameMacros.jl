module DFMacros

using Base: ident_cmp
using DataFrames: transform, transform!, select, select!, combine, subset, subset!, ByRow, passmissing, groupby

export @transform, @transform!, @select, @select!, @combine, @subset, @subset!, @groupby, @sort, @sort!

struct Transform end
struct Transform! end
struct Select end
struct Select! end
struct Combine end
struct Subset end
struct Subset! end
struct Sort end
struct Sort! end


macro transform(exprs...)
    macrohelper(Transform(), exprs...)
end

macro select(exprs...)
    macrohelper(Select(), exprs...)
end

macro subset(exprs...)
    macrohelper(Subset(), exprs...)
end

macro transform!(exprs...)
    macrohelper(Transform!(), exprs...)
end

macro select!(exprs...)
    macrohelper(Select!(), exprs...)
end

macro subset!(exprs...)
    macrohelper(Subset!(), exprs...)
end

macro combine(exprs...)
    macrohelper(Combine(), exprs...)
end

macro groupby(exprs...)
    f, df, func, kw_exprs = f_df_funcs_kwexprs(Select(), exprs...)

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
    f, df, func, kw_exprs = f_df_funcs_kwexprs(Select(), exprs...)

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

dataframesfunc(::Transform) = transform
dataframesfunc(::Transform!) = transform!
dataframesfunc(::Select) = select
dataframesfunc(::Select!) = select!
dataframesfunc(::Combine) = combine
dataframesfunc(::Subset) = subset
dataframesfunc(::Subset!) = subset!

defaultbyrow(::Transform) = true
defaultbyrow(::Select) = true
defaultbyrow(::Subset) = true
defaultbyrow(::Transform!) = true
defaultbyrow(::Select!) = true
defaultbyrow(::Subset!) = true
defaultbyrow(::Combine) = false

function macrohelper(T, exprs...)
    f, df, converted, kw_exprs = f_df_funcs_kwexprs(T, exprs...)
    build_call(f, df, converted, kw_exprs)
end

function build_call(f, df, converted, kw_exprs)
    :($f($(esc(df)), $(map(esc, converted)...); $(map(esc, kw_exprs)...)))
end

function f_df_funcs_kwexprs(T, exprs...)
    
    if length(exprs) >= 1 && exprs[1] isa Expr && exprs[1].head == :parameters
        kw_exprs = exprs[1].args
        df = exprs[2]
        source_func_sink_exprs = exprs[3:end]
    else
        df = exprs[1]
        source_func_sink_exprs = exprs[2:end]
        kw_exprs = []
    end

    converted = map(e -> convert_source_funk_sink_expr(T, e), source_func_sink_exprs)
    f = dataframesfunc(T)
    f, df, converted, kw_exprs
end

convert_source_funk_sink_expr(T, x) = x

function convert_source_funk_sink_expr(T, e::Expr)
    target, formula = split_formula(e)
    flags, formula = extract_macro_flags(formula)
    columns = gather_columns(formula)
    func = make_function_expr(formula, columns)
    clean_columns = map(clean_column, columns)

    byrow = (defaultbyrow(T) && !('c' in flags)) ||
        (!defaultbyrow(T) && ('r' in flags))

    pass_missing = 'm' in flags

    if pass_missing
        func = :(passmissing($func))
    end

    func = byrow ? :(ByRow($func)) : :($func)

    trans_expr = if target === nothing
        :([$(clean_columns...)] => $func)
    else
        :([$(clean_columns...)] => $func => $target)
    end
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

function gather_columns(x)
    columns = []
    gather_columns!(columns, x)
    columns
end

function gather_columns!(columns, x)
    if is_column_expr(x)
        if x ∉ columns
            push!(columns, x)
        end
    elseif x isa Expr && !(is_escaped_symbol(x)) && !(is_dot_quotenode_expr(x))
        foreach(x.args) do arg
            gather_columns!(columns, arg)
        end
    end
end

flagchars = "crm"

extract_macro_flags(x) = "", x

function extract_macro_flags(e::Expr)
    if e.head == :macrocall && all(occursin(flagchars), string(e.args[1])[2:end]) &&
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
    e.head == :$ && !is_escaped_symbol(e)
end

function make_function_expr(formula, columns)
    is_simple, symbol = is_simple_function_call(formula, columns)
    if is_simple
        return symbol
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
    quote
        ($(newsyms...),) -> $replaced_formula
    end
end

clean_column(x) = x
function clean_column(e::Expr)
    if e.head == :$
        e.args[1]
    else
        e
    end
end

is_escaped_symbol(e::Expr) = e.head == :$ && length(e.args) == 1 && e.args[1] isa QuoteNode
is_escaped_symbol(x) = false

is_simple_function_call(x, columns) = false, nothing
function is_simple_function_call(expr::Expr, columns)
    is_simple = expr.head == :call &&
        length(expr.args) >= 2 &&
        expr.args[1] isa Symbol &&
        all(x -> x in columns, expr.args[2:end])

    is_simple, expr.args[1]
end

# from macrotools
walk(x, inner, outer) = outer(x)
walk(x::Expr, inner, outer) = outer(Expr(x.head, map(inner, x.args)...))
postwalk(f, x) = walk(x, x -> postwalk(f, x), f)


end