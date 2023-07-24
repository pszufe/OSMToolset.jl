using Documenter
using Pkg


try
    using OSMToolset
catch
    if !("../src/" in LOAD_PATH)
	   push!(LOAD_PATH,"../src/")
	   @info "Added \"../src/\"to the path: $LOAD_PATH "
	   using OSMToolset
    end
end

DocMeta.setdocmeta!(OSMToolset, :DocTestSetup, :(using OSMToolset); recursive=true)

makedocs(
    modules = [OSMToolset],
    sitename = "OSMToolset.jl",
    format = format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", nothing) == "true",
        canonical="https://pszufe.github.io/OSMToolset.jl/stable/",
        edit_link="main",
        assets=String[],
    ),
    pages = ["Home" => "index.md", "Reference" => "reference.md"],
    doctest = true
)


deploydocs(
    repo="github.com/pszufe/OSMToolset.jl.git",
    devbranch = "main",
    target="build"
)

