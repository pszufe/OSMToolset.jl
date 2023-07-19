using OSMToolset
using Documenter

DocMeta.setdocmeta!(OSMToolset, :DocTestSetup, :(using OSMToolset); recursive=true)

makedocs(;
    modules=[OSMToolset],
    authors="pszufe <pszufe@gmail.com> and contributors",
    repo="https://github.com/pszufe/OSMToolset.jl/blob/{commit}{path}#{line}",
    sitename="OSMToolset.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://pszufe.github.io/OSMToolset.jl",
        edit_link="master",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/pszufe/OSMToolset.jl",
    devbranch="master",
)
