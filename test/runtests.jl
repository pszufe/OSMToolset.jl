using OSMToolset

using DataFrames
using Test

pmap = joinpath(dirname(pathof(OSMToolset)),"..","test","data","map.osm")

df = find_poi(pmap)
@testset "OSMToolset" begin

    @test nrow(df) > 100
end
