using OpenStreetMapX # needed only for conversion between LLA and ENU coordinate systems
using CSV, DataFrames, SpatialIndexing
using StatsBase



struct AttractivenessData
    class::Symbol
    points::Int
    range::Int
    enu::ENU
end

struct SpatIndex
    tree::RTree{Float64, 2, SpatialElem{Float64, 2, Int64, AttractivenessData}}
    df::DataFrame
    refLLA::LLA
    measures::Vector{Symbol}
end
function SpatIndex(filename, 
    df = CSV.read(filename, DataFrame), refLLA = LLA(mean(df.lat), mean(df.lon)) )

    data = SpatialElem[]
    for id in 1:nrow(df)
        enu = ENU(LLA(df.lat[id], df.lon[id]), refLLA)
        range_ = df.range[id]
        rect = SpatialIndexing.Rect((enu.east-range_,enu.north-range_), (enu.east+range_,enu.north+range_))
        a = AttractivenessData(Symbol(df.class[id]), df.points[id], df.range[id], enu)
        push!(data, SpatialElem(rect, id, a))
    end
    tree = RTree{Float64, 2}(Int, AttractivenessData, variant=SpatialIndexing.RTreeStar)
    SpatialIndexing.load!(tree, data)
    SpatIndex(tree, df, refLLA, Symbol.(sort!(unique(df.class))))
end

filename = "delaware-latest.osm.attractiveness.csv"

sindex = SpatIndex(filename);

function attractiveness(sindex::SpatIndex, lattitude::Float64, longitude::Float64)
    res = Dict(sindex.measures .=> 0.0)
    enu = ENU(LLA(lattitude,longitude),sindex.refLLA)
    p = SpatialIndexing.Point((enu.east, enu.north))
    for item in intersects_with(sindex.tree, SpatialIndexing.Rect(p))
        a = item.val
        res[a.class] += round(a.points * OpenStreetMapX.distance(enu, a.enu) / a.range;digits=3)
    end
    (;res...)
end



attractiveness(sindex, 39.2996,  -75.6048)