"""
    AttractivenessData

Internal data structure used to store data in the `AttractivenessSpatIndex` spatial index.
"""    
struct AttractivenessData{T <: MetaPOI}
    data::T
    enu::ENU
    lla::LLA
end

AttractivenessData{T}(row::DataFrameRow, enu, lla) where T <: MetaPOI =
    AttractivenessData(T(row), enu, lla)
AttractivenessData{NoneMetaPOI}(::DataFrameRow, enu, lla) =
    AttractivenessData(NoneMetaPOI(), enu, lla)

    

struct AttractivenessSpatIndex{T <: MetaPOI, F <: Function}
    tree::RTree{Float64, 2, SpatialElem{Float64, 2, Int64, AttractivenessData{T}}}
    df::DataFrame
    refLLA::LLA
    measures::Vector{Symbol}
    get_group::F
end


"""
    AttractivenessSpatIndex{T <: MetaPOI, F <: Function}(filename::AbstractString, get_range::Function=get_attractiveness_range, get_group::Function=get_attractiveness_group)
    AttractivenessSpatIndex{T <: MetaPOI, F <: Function}(df::AbstractDataFrame, get_range::Function=get_attractiveness_range, get_group::Function=get_attractiveness_group)

Builds an attractivness spatial index basing on data in some CSV file or a DataFrame 

Assuming that `T` is of typw `AttractivenessMetaPOI`,  the CSV file or DataFrame 
should have the following columns:
    - group - data group in attractiveness index, each group name creates attractiveness dimension
    - key - key in the XML file <tag>
    - values - values in the <tag> (a star `"*"` catches all values)
    - influence - strength of influence  
    - range - maximum influence range in meters 

When a `DataFrame` is provided the additional parameter `refLLA` can be provided for the reference 
`LLA` coordinates in the spatial index. The spatial index works in the ENU coordinate system.

If `T` is not provided `AttractivenessMetaPOI` will be used as the default metadata type.

The type `F` represents the attractiveness group function provided as  `get_group = (a::T) -> :somegroup`.
"""
AttractivenessSpatIndex{T}(filename::AbstractString;get_range::Function=get_attractiveness_range, get_group::Function=get_attractiveness_group) where T <: MetaPOI = AttractivenessSpatIndex(CSV.read(filename, DataFrame);get_range,get_group)
AttractivenessSpatIndex(filename::AbstractString;get_range::Function=get_attractiveness_range, get_group::Function=get_attractiveness_group) = AttractivenessSpatIndex{AttractivenessMetaPOI}(filename::AbstractString;get_range,get_group)


function AttractivenessSpatIndex{T}(df::AbstractDataFrame, refLLA::LLA = LLA(mean(df.lat), mean(df.lon));get_range::Function=get_attractiveness_range, get_group::Function=get_attractiveness_group) where T <: MetaPOI
    data = SpatialElem[]
    groups = Symbol[]
    id = 0
    for row in eachrow(df)
        metaPoi = T(row)
        id += 1
        lla = LLA(row.lat, row.lon)
        enu = ENU(lla, refLLA)
        range_ = get_range(metaPoi)
        push!(groups, get_group(metaPoi))
        rect = SpatialIndexing.Rect((enu.east-range_,enu.north-range_), (enu.east+range_,enu.north+range_))
        a = AttractivenessData{T}(row, enu, lla)
        push!(data, SpatialElem(rect, id, a))
    end
    tree = RTree{Float64, 2}(Int, AttractivenessData{T}, variant=SpatialIndexing.RTreeStar)
    SpatialIndexing.load!(tree, data)
    return AttractivenessSpatIndex{T, typeof(get_group)}(tree, df, refLLA, sort!(unique(groups)), get_group)
end

AttractivenessSpatIndex(df::AbstractDataFrame, refLLA::LLA = LLA(mean(df.lat), mean(df.lon))) = AttractivenessSpatIndex{AttractivenessMetaPOI}(df, refLLA)

function calculate_attractiveness(a::AttractivenessMetaPOI, poidistance::Number)
    if poidistance >= a.range
        return 0.0
    else
        return a.influence * (a.range - poidistance) / a.range
    end
end



"""
    attractiveness(sindex::AttractivenessSpatIndex{T}, lattitude::Number, longitude::Number; aggregator::Function=sum, calculate_attractiveness::Function=calculate_attractiveness,  distance::Function=OpenStreetMapX.distance, explain::Bool=false)  where T <: MetaPOI

Returns the multidimensional attractiveness measure
for the given spatial index `sindex` and `lattitude` and `longitude`.
The `aggregator` function will be used to aggregate the attractiveness values.
The aggreagation is required as more than one point of interest can be found within 
the attractiveness range. 
The function `calculate_attractiveness(a::T, poidistance::Number)` will be used 
to calculate the attractiveness on the base of metadata and distance.
The distance function `distance(a::ENU, b::ENU)` is used to 
calculate the distance between point pairs.

If `explain` is set to true the result will additionally contain details 
about POIs used to calculate the attractiveness.
"""
function attractiveness(sindex::AttractivenessSpatIndex{T}, lattitude::Number, longitude::Number; aggregator::Function=sum, calculate_attractiveness::Function=calculate_attractiveness, distance::Function=OpenStreetMapX.distance, explain::Bool=false)  where T <: MetaPOI
    attractiveness(sindex, OpenStreetMapX.LLA(lattitude,longitude); aggregator, calculate_attractiveness, distance, explain)
end

"""
    attractiveness(sindex::AttractivenessSpatIndex{T}, lla::LLA; aggregator::Function=sum, calculate_attractiveness::Function=calculate_attractiveness, distance::Function=OpenStreetMapX.distance, explain::Bool=false) where T <: MetaPOI

Returns the multidimensional attractiveness measure
for the given spatial index `sindex` and `LLA` coordinates.
The `aggregator` function will be used to aggregate the attractiveness values.
The aggreagation is required as more than one point of interest can be found within 
the attractiveness range. 
The function `calculate_attractiveness(a::T, poidistance::Number)` will be used 
to calculate the attractiveness on the base of metadata and distance.
The distance function `distance(a::ENU, b::ENU)` is used to 
calculate the distance between point pairs.

If `explain` is set to true the result will additionally contain details 
about POIs used to calculate the attractiveness.
"""
function attractiveness(sindex::AttractivenessSpatIndex{T}, lla::LLA; aggregator::Function=sum, calculate_attractiveness::Function=calculate_attractiveness, distance::Function=OpenStreetMapX.distance, explain::Bool=false) where T <: MetaPOI
    enu = ENU(lla,sindex.refLLA)
    attractiveness(sindex, enu; aggregator, calculate_attractiveness, distance, explain)
end



"""
    attractiveness(sindex::AttractivenessSpatIndex{T}, enu::ENU; aggregator::Function=sum, calculate_attractiveness::Function=calculate_attractiveness, distance::Function=OpenStreetMapX.distance, explain::Bool=false) where T <: MetaPOI

Returns the multidimensional attractiveness measure
for the given spatial index `sindex` and `enu` cooridanates.
Note that the enu coordinates *must* use `sindex.refLLA` as the reference point. 
Hence the `enu` coordinates need to be calculated eg. using `ENU(lla,sindex.refLLA)`.
The `aggregator` function will be used to aggregate the attractiveness values.
The aggreagation is required as more than one point of interest can be found within 
the attractiveness range. 
The function `calculate_attractiveness(a::T, poidistance::Number)` will be used 
to calculate the attractiveness on the base of metadata and distance.
The distance function `distance(a::ENU, b::ENU)` is used to 
calculate the distance between point pairs.

If `explain` is set to true the result will additionally contain details 
about POIs used to calculate the attractiveness.
"""
function attractiveness(sindex::AttractivenessSpatIndex{T}, enu::ENU; aggregator::Function=sum, calculate_attractiveness::Function=calculate_attractiveness, distance::Function=OpenStreetMapX.distance, explain::Bool=false) where T <: MetaPOI
    res = Dict(sindex.measures .=> [Float64[] for _ in 1:length(sindex.measures)]) 
    p = SpatialIndexing.Point((enu.east, enu.north))
    explanation = DataFrame()
    for item in intersects_with(sindex.tree, SpatialIndexing.Rect(p))
        aitval = item.val  # typeof(a) === AttractivenessData
        a = aitval.data
        poidistance = distance(enu, aitval.enu)
        attractiveness = calculate_attractiveness(a, poidistance)
        if attractiveness > 0.0
            push!(res[sindex.get_group(a)], attractiveness)
            if explain
                append!(explanation, DataFrame(;ntfromstruct(a)...,attractiveness,poidistance,aitval.lla.lat,aitval.lla.lon))
            end
        end
    end
    res2 = (sindex.measures .=> aggregator.(getindex.(Ref(res), sindex.measures)))
    if explain
        return (;res2..., explanation)
    else
        return (;res2...)
    end
end
