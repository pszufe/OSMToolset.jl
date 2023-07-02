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

makedocs(
    sitename = "OSMToolset",
    format = format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true"
    ),
    modules = [OSMToolset],
    pages = ["index.md", "reference.md"],
    doctest = true
)


deploydocs(
    repo ="github.com/pszufe/OSMToolset.jl.git",
    target="build"
)