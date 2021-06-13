d = pwd()
try
    cd(@__DIR__)
    Literate.markdown("README.jl", execute = true, documenter = false, credit = false); mv("README.md", "../README.md", force = true)
finally
    cd(d)
end