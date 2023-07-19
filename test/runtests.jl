using OSMToolset
using CSV, EzXML, DataFrames
using Parsers
import OpenStreetMapX: OSMData
using Test

pmap = joinpath(dirname(pathof(OSMToolset)),"..","test","data","map.osm")

df = find_poi(pmap)
@testset "OSMToolset" begin

    @test nrow(df) == 909

end
