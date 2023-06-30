using Documenter
using OSMToolset

makedocs(
    sitename = "OSMToolset",
    format = Documenter.HTML(),
    modules = [OSMToolset]
)

deploydocs(
    repo = "github.com/pszufe/OSMToolset.jl.git"
)