using OSMToolset

using DataFrames
using Test

test_map = joinpath(dirname(pathof(OSMToolset)),"..","test","data","map.osm")

df = find_poi(test_map)
@testset "OSMToolset" begin
    @test nrow(df) > 100
end
