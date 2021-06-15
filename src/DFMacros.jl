module DFMacros

using Base: ident_cmp
using DataFrames: transform, transform!, select, select!, combine, subset, subset!, ByRow, passmissing, groupby

export @transform, @transform!, @select, @select!, @combine, @subset, @subset!, @groupby, @sort, @sort!

funcsymbols = :transform, :transform!, :select, :select!, :combine, :subset, :subset!

for f in funcsymbols
    @eval begin
        export $(Symbol("@", f))
        macro $f(exprs...)
            macrohelper($f, exprs...)
        end
    end
end

defaultbyrow(::typeof(transform)) = true
defaultbyrow(::typeof(select)) = true
defaultbyrow(::typeof(subset)) = true
defaultbyrow(::typeof(transform!)) = true
defaultbyrow(::typeof(select!)) = true
defaultbyrow(::typeof(subset!)) = true
defaultbyrow(::typeof(combine)) = false

macro groupby(exprs...)
    f = select
    df, func, kw_exprs = df_funcs_kwexprs(f, exprs...)

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
    f = select
    df, func, kw_exprs = df_funcs_kwexprs(f, exprs...)

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
    df, converted, kw_exprs = df_funcs_kwexprs(f, exprs...)
    build_call(f, df, converted, kw_exprs)
end

function build_call(f, df, converted, kw_exprs)
    :($f($(esc(df)), $(converted...); $(map(esc, kw_exprs)...)))
end

function df_funcs_kwexprs(f, exprs...)
    
    if length(exprs) >= 1 && exprs[1] isa Expr && exprs[1].head == :parameters
        kw_exprs = exprs[1].args
        df = exprs[2]
        source_func_sink_exprs = exprs[3:end]
    else
        df = exprs[1]
        source_func_sink_exprs = exprs[2:end]
        kw_exprs = []
    end

    converted = map(e -> convert_source_funk_sink_expr(f, e, df), source_func_sink_exprs)
    df, converted, kw_exprs
end

convert_source_funk_sink_expr(f, x, df) = x

function convert_source_funk_sink_expr(f, e::Expr, df)
    target, formula = split_formula(e)
    flags, formula = extract_macro_flags(formula)
    columns = gather_columns(formula)
    func, columns = make_function_expr(formula, columns)
    clean_columns = map(c -> clean_column(c, df), columns)

    byrow = (defaultbyrow(f) && !('c' in flags)) ||
        (!defaultbyrow(f) && ('r' in flags))

    pass_missing = 'm' in flags

    if pass_missing
        func = :(passmissing($func))
    end

    func = byrow ? :(ByRow($func)) : :($func)

    trans_expr = if target === nothing
        :([$(clean_columns...)] => $(esc(func)))
    else
        :([$(clean_columns...)] => $(esc(func)) => $(esc(target)))
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
        foreach(x.args) do arg
            gather_columns!(columns, arg; unique = unique)
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

clean_column(x::QuoteNode, df) = x
clean_column(x, df) = :(symbolarg($x, $df))
function clean_column(e::Expr, df)
    e = if e.head == :$
        e.args[1]
    else
        e
    end
    if e isa String
        QuoteNode(Symbol(e))
    else
        :(symbolarg($(esc(e)), $(esc(df))))
    end
end

symbolarg(x::Int, df) = Symbol(names(df)[x])
symbolarg(sym::Symbol, df) = sym
symbolarg(s::String, df) = Symbol(s)

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


end