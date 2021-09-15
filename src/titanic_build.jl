open("titanic.jl", "w") do io
    println(io, "DataFrame(")
    for n in names(df)
        println(io, "    ", repr(n), " => ", repr(df[:, n]), ",")
    end
    println(io, ")")
end