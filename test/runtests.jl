using OSMToolset
import OpenStreetMapX
import OpenStreetMapX: ENU
using DataFrames
using Test

test_map = joinpath(dirname(pathof(OSMToolset)),"..","test","data","map.osm")

att = AttractivenessConfig(joinpath(dirname(pathof(OSMToolset)),"..","test","data","Attractiveness.csv"))
df = find_poi(test_map,attract_config=att)
sindex = AttractivenessSpatIndex(df);
lla = sindex.refLLA
@testset "OSMToolset" begin
    @test nrow(df) > 100
    a1 = attractiveness(sindex, lla)
    a2 = attractiveness(sindex, lla.lat, lla.lon)
    a3 = attractiveness(sindex, OpenStreetMapX.ENU(0.0,0.0))
    @assert  a1 == a2 == a3
    @assert all(values(a1) .> 0)
end
