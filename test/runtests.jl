using OSMToolset

using DataFrames
using Test

test_map = joinpath(dirname(pathof(OSMToolset)),"..","test","data","map.osm")

att = AttractivenessConfig(joinpath(dirname(pathof(OSMToolset)),"..","test","data","Attractiveness.csv"))
df = find_poi(test_map,attract_config=att)
@testset "OSMToolset" begin
    @test nrow(df) > 100
end
