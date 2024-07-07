"""
    abstract type AbstractMetaPOI end

A base type for representing metadata related to a POI location.
"""
abstract type AbstractMetaPOI end

"""
    struct NoneMetaPOI <: AbstractMetaPOI; end

Scraping configuration when no attractiveness metadata is attached.
"""
struct NoneMetaPOI <: AbstractMetaPOI; end
"""
    struct AttractivenessMetaPOI <: AbstractMetaPOI

Container for metadata for attractiveness (the default configuration of scraping).

The attractiveness is defined by the following fields:
- `group` - the group of the POI (e.g. `:parking` or `:food`)
- `influence` - the power of the POI on the attractiveness of the location
- `range` - the range of the POI influence (measeured in meters)
"""
struct AttractivenessMetaPOI <: AbstractMetaPOI
    group::Symbol
    influence::Float64
    range::Float64
end

"""
    get_attractiveness_group(a::AttractivenessMetaPOI)

Default group for AttractivenessMetaPOI which is `a.group`.
"""
get_attractiveness_group(a::AttractivenessMetaPOI) = a.group

"""
    get_attractiveness_range(a::AttractivenessMetaPOI)

Default range for AttractivenessMetaPOI whic is the `a.range`.
"""
get_attractiveness_range(a::AttractivenessMetaPOI) = a.range

"""
    get_attractiveness_group(a::NoneMetaPOI)

Default group for NoneMetaPOI (`NoneMetaPOI`).
"""
get_attractiveness_group(a::NoneMetaPOI) = :NoneMetaPOI

"""
    get_attractiveness_range(a::AbstractMetaPOI)

You can create own subtypes of `AbstractMetaPOI` but than range needs to be provided.
"""
get_attractiveness_range(a::AbstractMetaPOI) = throw(ArgumentError("`get_attractiveness_range` not implemented for type $(typeof(a)). You can also just provide a custom function via the `get_range` parameter such as `get_range= a -> 100`"))


AttractivenessMetaPOI(row::DataFrameRow) = AttractivenessMetaPOI(Symbol(row.group), Float64(row.influence), Float64(row.range))
NoneMetaPOI(::DataFrameRow) = NoneMetaPOI()



"""
    Represents the configuration of the data scraping process from OSM XML.
Only those pieces of data will be scraped that are defined here.

The configuration is defined in a DataFrame with the following columns:
`group`, `key`, `values`, `influence`, `range`.
Instead of the DataFrame a paths to a CSV file can be provided.

### Constructors
- `ScrapePOIConfig()` - default inbuilt configuration for data scraping.
   Note that the default configuration can change with library updates.
   This will use a default configuration and `AttractivenessMetaPOI` as meta data.
- `ScrapePOIConfig(keys::Union{Tuple{String,String}, String}...)` - provide keys for scraping, `NoneMetaPOI` will be used as metadata
- `ScrapePOIConfig(pairs::Pair{<:Union{Tuple{String,String}, String}, T}...)` - provide keys and corresponding metadata
- `ScrapePOIConfig{T <: AbstractMetaPOI}(df::DataFrame)` - use a `DataFrame` as configuration
- ScrapePOIConfig{T <: AbstractMetaPOI}(meta::Dict{<:Union{String, Tuple{String,String}}, T}) - internal constructor. `meta` dictionary explaining how a single `k="keyname"` value or tuple ofvalues (paired with `v="valuename"`) should be mapped for attractiveness metadata.

### Example
```julia
ScrapePOIConfig(("amenity", "parking"), ("parking"))

ScrapePOIConfig(("*", "restaurant"))

ScrapePOIConfig("*")

ScrapePOIConfig(("amenity", "parking") =>AttractivenessMetaPOI(:car, 1, 500), ("amenity", "restaurant") => (AttractivenessMetaPOI(:food, 1.0, 1000.0)))

ScrapePOIConfig([("amenity", "pub"), ("amenity", "restaurant")] .=> Ref(AttractivenessMetaPOI(:food, 1.0, 100.0)))
"""
struct ScrapePOIConfig{T <: AbstractMetaPOI}
    meta::Dict{Union{String, Tuple{String,String}}, T}
    dkeys::Set{String} #helper field for efficient searching
end


function ScrapePOIConfig(pairs::Pair{<:Union{Tuple{String,String}, String}, T}...) where T <: AbstractMetaPOI
    ScrapePOIConfig(Dict{Union{String, Tuple{String,String}}, T}(pairs))
end

function ScrapePOIConfig(pairs::AbstractVector{<:Pair{<:Union{Tuple{String,String}, String}, T}}) where T <: AbstractMetaPOI
    ScrapePOIConfig(Dict{Union{String, Tuple{String,String}}, T}(pairs))
end


function ScrapePOIConfig(keys::Union{Tuple{String,String}, String}...)
    ScrapePOIConfig(Dict{Union{String, Tuple{String,String}}, NoneMetaPOI}(keys .=> Ref(NoneMetaPOI())))
end

function ScrapePOIConfig(keys::AbstractVector{<:Union{Tuple{String,String}, String}})
    ScrapePOIConfig(Dict{Union{String, Tuple{String,String}}, NoneMetaPOI}(keys .=> Ref(NoneMetaPOI())))
end



function ScrapePOIConfig(meta::Union{Dict{Tuple{String,String}, T},Dict{String, T}}) where T <: AbstractMetaPOI
    ScrapePOIConfig(Dict{Union{String, Tuple{String,String}}, T}(meta))
end

function ScrapePOIConfig(meta::Dict{Union{String, Tuple{String,String}}, T}) where T <: AbstractMetaPOI
    dkeyfirst(k::String) = k
    dkeyfirst(k::Tuple{String,String}) = k[1]
    ScrapePOIConfig{T}(meta, Set(dkeyfirst.(keys(meta))))
end

function DataFrames.DataFrame(sp::ScrapePOIConfig{T}) where T <: AbstractMetaPOI
    df = DataFrame(;key=String[], values=String[],
        (NamedTupleTools.fieldnames(T) .=> [Vector{ftype}() for ftype in NamedTupleTools.fieldtypes(T)])...  )
    for kv in keys(sp.meta)
        key = kv isa Tuple ? kv[1] : kv
        values = kv isa Tuple ? kv[2] : "*"
        push!(df, (;key, values, ntfromstruct(sp.meta[kv])...))
    end
    df2 = combine(groupby(df, Not(:values)), :values => (val -> join(sort(val), ",")) => :values)
    DataFrames.select!(df2, :key, :values,Not([:key, :values]))
    sort!(df2, [:key, :values])
    df2
end


function ScrapePOIConfig{T}(df::DataFrame) where T <: AbstractMetaPOI
    colnames = ["key", "values"]
    @assert all(colnames .∈ Ref(names(df)))
    meta = Dict{Union{String, Tuple{String,String}}, T}()
    for row in eachrow(df)
        a = T(row)
        for value in string.(split(String(row.values),','))
            if value == "*"
                meta[String(row.key)] = a
            else
                meta[String(row.key), value] = a
            end
        end
    end
    ScrapePOIConfig(meta)
end

ScrapePOIConfig(df::DataFrame) = ScrapePOIConfig{AttractivenessMetaPOI}(df)


"""
Default built-in configuration for data scraping from OSM XML.
The default configuration will use AttractivenessMetaPOI
"""
const __builtin_config_path = joinpath(@__DIR__, "..", "config", "ScrapePOIconfig.csv")
ScrapePOIConfig() = ScrapePOIConfig{AttractivenessMetaPOI}(CSV.read(__builtin_config_path, DataFrame ))


function Base.show(io::IO, sp::ScrapePOIConfig{T}) where T <: AbstractMetaPOI
    println(io, "ScrapePOIConfig{$T} with $(length(sp.meta)) keys:")
    show(io, DataFrame(sp);summary=false,eltypes=false,allrows=true,rowlabel=:No)
end


"""
    find_poi(filename::AbstractString, scrape_config::ScrapePOIConfig{T <: AbstractMetaPOI}=ScrapePOIConfig(); all_tags::Bool=false)

Generates a `DataFrame` with points of interests and from a given XML `filename`.
The `scrape_config` parameter defines the configuration of the scraping process.
The data frame will also contain the metadata of type `T` for each POI.

The `DataFrame` can be later used with `AttractivenessSpatIndex` to build an attractivenss spatial index.

Setting the `all_tags` parameter to `true` will cause that once the tag is matched, the adjacent tags within the same
element will be included in the resulting DataFrame.
"""
function find_poi(filename::AbstractString, scrape_config::ScrapePOIConfig{T}=ScrapePOIConfig(); all_tags::Bool=false) where T <: AbstractMetaPOI
    dkeys = scrape_config.dkeys
    dkeys_has_star = ("*" in dkeys)
    meta = scrape_config.meta
    EMPTY_NODE = Node(0,0.,0.)
    nodes =  Dict{Int,Node}()
    ways_firstnode = Dict{Int, Node}()
    relations_firstnode = Dict{Int, Node}()
    elemtype = :X
    elemid = -1

    # Buffer for collecting state when all_tags==true
    all_tags_buffer::Vector{Tuple{String,String}} = Vector{Tuple{String,String}}()
    all_tags_good_tag::Base.RefValue{Bool} = Ref(false)
    alltags_clear = all_tags ? () -> begin;empty!(all_tags_buffer);all_tags_good_tag[]=false;end : ()->nothing

	# creates an empty data frame
	df = DataFrame(;elemtype=Symbol[], elemid=Int[],nodeid=Int[],lat=Float64[],lon=Float64[],
					key=String[], value=String[],
					(NamedTupleTools.fieldnames(T) .=> [Vector{Union{ftype, all_tags ? Missing : ftype}}() for ftype in NamedTupleTools.fieldtypes(T)])...  )

    io = open(filename, "r")
    sr = EzXML.StreamReader(io)
    i = 0
    curnode = EMPTY_NODE
    waylookforfirstnd = false
    relationlookforfirstmember = false
    for dat in sr
        dat != EzXML.READER_ELEMENT && continue;
        i += 1
        nname = nodename(sr)
        if nname == "node"
            elemtype = :node
            if hasnodeattributes(sr)
                attrs = nodeattributes(sr)
                elemid = parse(Int, attrs["id"])
                curnode = Node(elemid, parse(Float64,attrs["lat"]), parse(Float64,attrs["lon"]))
                nodes[elemid] = curnode
            else
                @warn "<node> $nname, $i, no attribs?"
            end
            alltags_clear()
        elseif nname == "way"
            elemtype = :way
            curnode = EMPTY_NODE
            if hasnodeattributes(sr)
                attrs = nodeattributes(sr)
                elemid = parse(Int, attrs["id"])
                waylookforfirstnd = true
            else
                @warn "<way> $nname, $i, no attribs?"
            end
            alltags_clear()
        elseif waylookforfirstnd && nname == "nd"
            if hasnodeattributes(sr)
                attrs = nodeattributes(sr)
                curnode = nodes[parse(Int, attrs["ref"])]
                ways_firstnode[elemid] = curnode
                waylookforfirstnd = false
            else
                @warn "<way>/<nd> $nname, $i, no attribs?"
            end
            alltags_clear()
        elseif nname == "relation"
            elemtype = :relation
            curnode = EMPTY_NODE
            curway = -1
            if hasnodeattributes(sr)
                attrs = nodeattributes(sr)
                elemid = parse(Int, attrs["id"])
                relationlookforfirstmember = true
            else
                @warn "<relation> $nname, $i, no attribs?"
            end
            alltags_clear()
        elseif relationlookforfirstmember && nname == "member"
            if hasnodeattributes(sr)
                attrs = nodeattributes(sr)
                membertype = attrs["type"]
                memberref = parse(Int, attrs["ref"])
                if membertype == "node"
                    !haskey(nodes, memberref) && continue;
                    curnode = nodes[memberref]
                elseif membertype == "way"
                    !haskey(ways_firstnode, memberref) && continue;
                    curnode = ways_firstnode[memberref]
                elseif membertype == "relation"
                    !haskey(relations_firstnode, memberref) && continue;
                    curnode = relations_firstnode[memberref]
                else
                    curnode = EMPTY_NODE
                    @warn "<relation> , $i, Unsupported member type: $nname"
                end
                relations_firstnode[elemid] = curnode
                relationlookforfirstmember = false
            else
                @warn "<relation>/<member> $nname, $i, no attribs?"
            end
            alltags_clear()
        elseif nname == "tag"
            attrs = nodeattributes(sr)
            key = string(get(attrs,"k",""))
            keysearch::Union{String,Nothing} = nothing
            if key in dkeys
                keysearch = key
            elseif dkeys_has_star
                keysearch = "*"
            end
            if !isnothing(keysearch)
                value = string(get(attrs,"v",""))
                # get either first key if it was of * type
                # otherwise try to get attractiveness for the tuple
                a = get(meta, keysearch, get(meta, (keysearch, value), nothing))
                if !isnothing(a)
                    # we are interested only in attractive POIs
                    push!(df, (;elemtype,elemid,nodeid=curnode.id, lat=curnode.lat, lon=curnode.lon, key, value, ntfromstruct(a)...) )
                    all_tags_good_tag[] = all_tags
                elseif all_tags
                    push!(all_tags_buffer, (key, value))
                end
            elseif all_tags
                push!(all_tags_buffer, (key, string(get(attrs,"v",""))))
            end
            if all_tags_good_tag[]
                for (key, value) in all_tags_buffer
                    push!(df, (;elemtype,elemid,nodeid=curnode.id, lat=curnode.lat, lon=curnode.lon, key, value, (NamedTupleTools.fieldnames(T) .=>missing)...) )
                end
                empty!(all_tags_buffer)
            end
        end
    end
    unique!(df,[:lat,:lon,:key,:value])
    df
end

"""
    clean_pois_by_group(df::DataFrame)
For data imported via AttractivenessMetaPOI the function will return only the most attractive POI for each group.
This is useful when you want to remove duplicate entries for the same node.
"""
function clean_pois_by_group(df::DataFrame)
    DataFrame(g[findmax(g.influence)[2], :] for g in  groupby(df, [:nodeid, :group]))
end


#=
"""
    find_poi(osm::OpenStreetMapX.OSMData,scrape_config::ScrapePOIConfig=ScrapePOIConfig())
Finds POIs on the data from OSM parser. Please note that the OSM parser might not parse all the data from the XML file,
hence the results might be different than from `find_poi(filename::AbstractString)`.
Generally, usage of `find_poi(filename::AbstractString)` is stronlgy recommended.
"""
function find_poi(osm::OpenStreetMapX.OSMData,scrape_config::ScrapePOIConfig=ScrapePOIConfig())
    dkeys = scrape_config.dkeys
    meta = scrape_config.meta

    df = DataFrame()
    for (node, (key, value)) in osm.features
        # get either first key if it was of * type
        # otherwise try to get attractiveness for the tuple
        a = get(meta, key, get(meta, (key, value), nothing))
        if a !== nothing
            # we are interested only in attractive POIs
            lla = osm.nodes[node]
            push!(df, (;nodeid=node, lat=lla.lat, lon=lla.lon, key, value, ntfromstruct(a)...))
        end
    end
    df2 = DataFrame(g[findmax(g.influence)[2], :] for g in groupby(df, [:nodeid, :group]))
    return df2
end
=#