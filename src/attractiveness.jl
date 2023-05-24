using OpenStreetMapX # needed only for conversion between LLA and ENU coordinate systems
using CSV, DataFrames, SpatialIndexing
using StatsBase



struct AttractivenessData
    class::Symbol
    points::Int
    range::Int
    enu::ENU
    lla::LLA
end

struct AttractivenessSpatIndex
    tree::RTree{Float64, 2, SpatialElem{Float64, 2, Int64, AttractivenessData}}
    df::DataFrame
    refLLA::LLA
    measures::Vector{Symbol}
end
"""
    AttractivenessSpatIndex(filename::AbstractString)
    AttractivenessSpatIndex(df::AbstractDataFrame)

Builds an attractivness spatial index basing on data in some CSV file o a DataFrame

The CSV file or DataFrame should have the following columns:
    - class - data class in attractiveness index, each class name creates attractiveness dimension
    - key - key in the XML file <tag>
    - values - values in the <tag> (a star `"*"` catches all values)
    - points - number of influance points 
    - range - maximum influence range in meters 

When a `DataFrame` is provided the additional parameter `refLLA` can be provided for the reference 
`LLA` coordinates in the spatial index. The spatial index works in the ENU coordinate system.
"""
AttractivenessSpatIndex(filename::AbstractString) = AttractivenessSpatIndex(CSV.read(filename, DataFrame))
function AttractivenessSpatIndex(df::AbstractDataFrame, refLLA::LLA = LLA(mean(df.lat), mean(df.lon)))
    data = SpatialElem[]
    for id in 1:nrow(df)
        lla = LLA(df.lat[id], df.lon[id])
        enu = ENU(lla, refLLA)
        range_ = df.range[id]
        rect = SpatialIndexing.Rect((enu.east-range_,enu.north-range_), (enu.east+range_,enu.north+range_))
        a = AttractivenessData(Symbol(df.class[id]), df.points[id], df.range[id], enu, lla)
        push!(data, SpatialElem(rect, id, a))
    end
    tree = RTree{Float64, 2}(Int, AttractivenessData, variant=SpatialIndexing.RTreeStar)
    SpatialIndexing.load!(tree, data)
    return AttractivenessSpatIndex(tree, df, refLLA, Symbol.(sort!(unique(df.class))))
end


function attractiveness(sindex::AttractivenessSpatIndex, latitude::Float64, longitude::Float64; explain::Bool=false)
    res = Dict(sindex.measures .=> 0.0)
    enu = ENU(LLA(latitude,longitude),sindex.refLLA)
    p = SpatialIndexing.Point((enu.east, enu.north))
    explanation = DataFrame()
    for item in intersects_with(sindex.tree, SpatialIndexing.Rect(p))
        a = item.val
        poidistance = OpenStreetMapX.distance(enu, a.enu)
        res[a.class] += round(a.points * poidistance / a.range;digits=3)
        if explain
            append!(explanation, DataFrame(;a.class,a.points,poidistance,a.lla.lat,a.lla.lon))
        end
    end
    if explain
        return ((;res...), explanation)
    else
        return (;res...)
    end
end

#=
sindex = AttractivenessSpatIndex(filename);

using BenchmarkTools
@btime attractiveness(sindex, 39.2996,  -75.6048)

attractiveness(sindex, 39.2996,  -75.6048; explain=Val{true}())
=#
