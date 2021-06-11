using DFMacros
using DataFrames
using Test

@testset "transform & select" begin
    df = DataFrame(a = 1:100, b = rand('a':'e', 100), c = randn(100))

    df2 = @transform(df, :a + 1)
    @test df2 == transform(df, :a => ByRow(x -> x + 1))
    df3 = @transform(df, :d = :a + 1)
    @test df3 == transform(df, :a => ByRow(x -> x + 1) => :d)
    df4 = @transform(df, :d = :a + 1, :e = :c * 2)
    @test df4 == transform(df,
        :a => ByRow(x -> x + 1) => :d,
        :c => ByRow(x -> x * 2) => :e
    )
    df5 = @transform(df, :d = :a + 1, :e = :c * 2, :f = :a * :c - (:c / :a))
    @test df5 == transform(df,
        :a => ByRow(x -> x + 1) => :d,
        :c => ByRow(x -> x * 2) => :e,
        [:a, :c] => ByRow((x, y) -> x * y - (y / x)) => :f
    )

    col1 = :a
    col2 = :c
    df6 = @transform(df, :d = $col1 + $col2 * :a)
    @test df6 == transform(df, [col1, col2, :a] => ByRow((x, y, z) -> x + y * z) => :d)

    s = "d"
    df7 = @transform(df, Symbol(s) = :a + 1)
    @test df7 == transform(df, :a => ByRow(x -> x + 1) => :d)

    df8 = @transform(df, AsTable = (x = "$(:a) $(:b)", y = :c * 2))

    @test df8 == transform(df,
        [:a, :b, :c] =>
            ByRow((a, b, c) -> (x = "$a $b", y = c * 2)) => AsTable
    )

    df9 = @transform(df, :a)
    @test df9 == transform(df, :a)

    df10 = @select(df, :a * 2)
    @test df10 == select(df, :a => ByRow(x -> x * 2))

    df11 = @select(df, :x = :a * 2)
    @test df11 == select(df, :a => ByRow(x -> x * 2) => :x)

    myfunc(x) = x + 2
    df12 = @transform(df, myfunc(:a))
    @test "a_myfunc" in names(df12)
    @test df12 == transform(df, :a => ByRow(myfunc))

    df13 = @transform(df, :x = @c sum(:a) .+ :c)
    @test df13 == transform(df, [:a, :c] => ((x, y) -> sum(x) .+ y) => :x)

    df14 = DataFrame(a = ['a', 'b', missing])
    df15 = @transform(df14, @m uppercase(:a))
    # @test df15 == transform(df14, :a => ByRow(passmissing(uppercase)))
end

@testset "combine" begin
    df = DataFrame(a = 1:100, b = rand('a':'e', 100), c = randn(100))

    df1 = @combine(df, sum(:a))
    @test df1 == combine(df, :a => sum)

    df2 = @combine(df, sum(:a) + 3)
    @test df2 == combine(df, :a => (x -> sum(x) + 3))

    df3 = @combine(df, :x = sum(:a) + 3)
    @test df3 == combine(df, :a => (x -> sum(x) + 3) => :x)

    df4 = @combine(df, :y = @r 3 * :a)
    @test df4 == combine(df, :a => ByRow(x -> 3 * x) => :y)
end

@testset "subset" begin
    df = DataFrame(a = [-1, 1, -2, 2, -3, 3], b = randn(6))
    df2 = @subset(df, abs(:a) < 2)
    @test df2 == subset(df, :a => ByRow(x -> abs(x) < 2))
end

@testset "groupby" begin
    df = DataFrame(a = [-1, 1, -2, 2, -3, 3], b = randn(6))
    gdf = @groupby(df, abs(:a))
    
    gdf2 = @groupby(df, :a = abs(:a))
    
    gdf3 = @groupby(df, :x = abs(:a))
end