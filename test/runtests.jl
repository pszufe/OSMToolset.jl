using OSMToolset
import OpenStreetMapX
import OpenStreetMapX: ENU
using DataFrames
using CSV
using Test

test_map = joinpath(dirname(pathof(OSMToolset)),"..","test","data","boston.osm")
test_poi_config = joinpath(dirname(pathof(OSMToolset)),"..","test","data","ScrapePOIconfig.csv")

#test_map = "test/data/boston.osm"
#test_poi_config = "test/data/ScrapePOIconfig.csv"

poiconf = ScrapePOIConfig{AttractivenessMetaPOI}(CSV.read(test_poi_config,DataFrame))
poiconf_default = ScrapePOIConfig()

bounds = getbounds(test_map)


df = find_poi(test_map,poiconf)
sindex = AttractivenessSpatIndex(df);

csvfile = tempname()
CSV.write(csvfile, df)
sindex2 = AttractivenessSpatIndex(csvfile);
atexit(() -> rm(csvfile))

lla = OpenStreetMapX.LLA((bounds.minlat+bounds.maxlat)/2, (Float64(bounds.minlon)+Float64(bounds.maxlon))/2)
@testset "AttractivenessSpatIndex" begin
	@test sindex.refLLA == sindex2.refLLA
    @test nrow(df) > 20
    a1 = attractiveness(sindex, lla)
    a2 = attractiveness(sindex, lla.lat, lla.lon)
    enu = ENU(lla, sindex.refLLA)
    a3 = attractiveness(sindex, enu)
    @test  a1 == a2 == a3
    @test all(values(a1) .>= 0)
    @test any(values(a1) .>= 0)
    @test all(values(a3) .>= 0)
    @test any(values(a3) .>= 0)
end


scdf1 = ScrapePOIConfig(("amenity","parking"), "parking") |> DataFrame
sc1 = ScrapePOIConfig{NoneMetaPOI}(scdf1)

sc2 = ScrapePOIConfig(("amenity","parking")=>AttractivenessMetaPOI(:parking,10,1000))
scdf2 = sc2 |> DataFrame

dfpois_all = find_poi(test_map, sc2;  all_tags=true)

@testset "DataFramesSC" begin
	@test sc1 |> DataFrame == scdf1
    @test ScrapePOIConfig{AttractivenessMetaPOI}(scdf2) |> DataFrame == scdf2
    @test length(findall(ismissing, dfpois_all.group)) > 0
end


config = DataFrame(key=["parking", "amenity"], values=["*", "parking"])
df2 = find_poi(test_map, ScrapePOIConfig{NoneMetaPOI}(config))
df2_api2 = find_poi(test_map, ScrapePOIConfig(("parking"),("amenity","parking")))
df3 = find_poi(test_map, ScrapePOIConfig{NoneMetaPOI}(DataFrame(key=String[], values=String[])))
df4 = find_poi(test_map, ScrapePOIConfig{NoneMetaPOI}(DataFrame(key=["does not exist<!"], values=["*"])))



# each parking space has an attractiveness range od 300 meters
sindex2 = AttractivenessSpatIndex{NoneMetaPOI}(df2; get_range=a->300, get_group=a->:parking);

@testset "CustomConfig" begin
    @test nrow(df2) > 0
    @test nrow(df2) == nrow(df2_api2)
    @test sort(df2,:nodeid) == sort(df2_api2, :nodeid)
    @test nrow(df3) == 0
    @test nrow(df4) == 0
    @test df2[1:0,:] == df3
    @test df2[1:0,:] == df4
    @test all(df2.key .∈ Ref(["amenity", "parking"]))
    att2 = attractiveness(sindex2, lla; aggregator= x -> length(x)==0 ? 0 : maximum(x), calculate_attractiveness = (a,dist) -> dist > 300 ? 0 : 300/dist   )
    @test fieldnames(att2) == (:parking,)
    @test att2.parking > 0
end


ixnodes = NodeSpatIndex(df2.nodeid, df2.lat, df2.lon, sindex2.refLLA;node_range=300.)

enu0 = ENU(0., 0.)
find0 =findnode(ixnodes, enu0)

enu2000 = ENU(200000., 2000000.)
find2000=findnode(ixnodes, enu2000)

@testset "Nodeindex" begin
    @test find0.distance < 300.
    @test find0.nodeid ∈ df2.nodeid
    @test find2000.distance == Inf
    @test find2000.nodeid == 0
end


function get_nodeids(f)
    df = DataFrame(OSMToolset.gettag.(readlines(test_map)))
    df[(df.type.==:node) .& (df.id .!= 0) , :id]
end
nodes1 = sort!(get_nodeids(test_map))


tdir = mktempdir()
outfiles = tile_osm_file(test_map, nrow=2, ncol=3, out_dir=tdir)
nodes2 = Int[]
for f in vec(outfiles)
    append!(nodes2, get_nodeids(joinpath(tdir,f)))
end
sort!(unique!(nodes2))
rm(tdir, force=true, recursive=true)

@testset "TileNodes" begin
    @test nodes1 == nodes2
end
