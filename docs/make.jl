using Documenter
using Pkg

if isfile("src/OSMToolset.jl")
    if !("." in LOAD_PATH)
        push!(LOAD_PATH,".")
    end
elseif isfile("../src/OSMToolset.jl")
    if !(".." in LOAD_PATH)
	   push!(LOAD_PATH,"..")
    end
end

using OSMToolset

println("Generating docs for module OSMToolset\n$(pathof(OSMToolset))")

DocMeta.setdocmeta!(OSMToolset, :DocTestSetup, :(using OSMToolset); recursive=true)

makedocs(
    modules = [OSMToolset],
    sitename = "OSMToolset",
    format = format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", nothing) == "true",
        canonical="https://pszufe.github.io/OSMToolset.jl/stable/",
        edit_link="main",
        assets=String[],
    ),
    checkdocs = :exports,
    pages = ["Home" => "index.md", "Reference" => "reference.md", "Visualization" => "visualize.md"],
    doctest = true
)


deploydocs(
    repo="github.com/pszufe/OSMToolset.jl.git",
    devbranch = "main",
    target="build"
)
