module DFMacros

using Base: ident_cmp
using DataFrames: transform, select, combine, subset, ByRow, passmissing, groupby

export @transform, @select, @combine, @subset, @groupby

struct Transform end
struct Select end
struct Combine end
struct Subset end

macro transform(df, exprs...)
    macrohelper(Transform(), df, exprs...)
end

macro select(df, exprs...)
    macrohelper(Select(), df, exprs...)
end

macro combine(df, exprs...)
    macrohelper(Combine(), df, exprs...)
end

macro subset(df, exprs...)
    macrohelper(Subset(), df, exprs...)
end

macro groupby(df, exprs...)
    select_part = macrohelper(Select(), df, exprs...)
    quote
        temp = $select_part
        df_copy = copy($(esc(df)))
        for name in names(temp)
            df_copy[!, name] = temp[!, name]
        end
        groupby(df_copy, names(temp))
    end
end

dataframesfunc(::Transform) = transform
dataframesfunc(::Select) = select
dataframesfunc(::Combine) = combine
dataframesfunc(::Subset) = subset

defaultbyrow(::Transform) = true
defaultbyrow(::Select) = true
defaultbyrow(::Combine) = false
defaultbyrow(::Subset) = true

function macrohelper(T, df, exprs...)
    source_func_sink_exprs = filter(is_source_func_sink_expr, exprs)
    kw_exprs = filter(is_kw_expr, exprs)
    converted = map(e -> convert_source_funk_sink_expr(T, e), source_func_sink_exprs)
    converted_kw = map(convert_kw_expr, kw_exprs)
    f = dataframesfunc(T)
    :($f($(esc(df)), $(map(esc, converted)...); $(kw_exprs...)))
end

is_source_func_sink_expr(x) = true
is_kw_expr(x) = false

convert_source_funk_sink_expr(T, x) = x
convert_kw_expr(x) = x

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
    elseif x isa Expr
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

is_column_expr(q::QuoteNode) = true
is_column_expr(x) = false
function is_column_expr(e::Expr)
    e.head == :$
end

function make_function_expr(formula, columns)
    is_simple, symbol = is_simple_function_call(formula, columns)
    if is_simple
        return symbol
    end

    newsyms = map(x -> gensym(), columns)
    replaced_formula = postwalk(formula) do e
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