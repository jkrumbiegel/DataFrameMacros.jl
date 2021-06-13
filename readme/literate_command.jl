d = pwd()

function make_toc(s)
    lines = split(s, '\n')
    tocline = findfirst(startswith("# TOC"), lines)
    tocline === nothing && return s

    others = lines[tocline+1:end]
    toc_entries = map(others) do line
        m = match(r"# (#+) (.+)", line)
        m === nothing && return nothing
        n = length(m[1])
        title = strip(m[2])
        githubanchor = replace(title, r"\s+" => "-")
        githubanchor = replace(githubanchor, r"[^\-a-z0-9A-Z]+" => "")
        (title, n, githubanchor)
    end

    toc_entries = filter(!isnothing, toc_entries)
    s = map(toc_entries) do (title, n, githubanchor)
        # "# $(" "^n)- [$title](#$githubanchor)"
        "# - [$title](#$githubanchor)"
    end |> x -> join(x, "\n")
    lines[tocline] = s
    join(lines, "\n")
end

try
    cd(@__DIR__)
    Literate.markdown("README.jl",
        execute = true,
        documenter = false,
        credit = false,
        preprocess = make_toc)
    mv("README.md", "../README.md", force = true)
finally
    cd(d)
end