
"""
    abstract type MetaPOI end

A base time for representing metadata related to a POI location.
"""
abstract type MetaPOI end

"""
    struct NoneMetaPOI <: MetaPOI; end

A subtype of `MetaPOI` that does not contain any metadata.
"""
struct NoneMetaPOI <: MetaPOI; end
"""
    struct AttractivenessMetaPOI <: MetaPOI

A subtype of `MetaPOI` that contains metadata for attractiveness 
(the default configuration of scraping).
This assumes that the metadata is stored in a CSV file with the following columns:
`key`, `values`, `group`, `influence`, `range`.
"""
struct AttractivenessMetaPOI <: MetaPOI
    group::Symbol
    influence::Float64
    range::Float64
end

"""
    get_attractiveness_group(a::AttractivenessMetaPOI)
    
Default group for AttractivenessMetaPOI which is `a.group`.
"""
get_attractiveness_group(a::AttractivenessMetaPOI) = 
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
    get_attractiveness_range(a::MetaPOI)
You can create own subtypes of `MetaPOI` but than range needs to be provided.
"""
get_attractiveness_range(a::MetaPOI) = throw(ArgumentError("`get_attractiveness_range` not implemented for type $(typeof(a)). You can also just provide a custom function via the `get_range` parameter such as `get_range= a -> 100`"))


AttractivenessMetaPOI(row::DataFrameRow) = AttractivenessMetaPOI(Symbol(row.group), Float64(row.influence), Float64(row.range))
NoneMetaPOI(::DataFrameRow) = NoneMetaPOI()



"""
    Represents the configuration of the data scraping process from OSM XML.
Only those pieces of data will be scraped that are defined here.

The configuration is defined in a DataFrame with the following columns:
`group`, `key`, `values`, `influence`, `range`.
Instead of the DataFrame a paths to a CSV file can be provided.

* Constructors *
- `ScrapePOIConfig()` - default inbuilt configuration for data scraping. 
   Note that the default configuration can change with library updates.
   This will use `AttractivenessMetaPOI` as meta data.
- `ScrapePOIConfig{T <: MetaPOI}(filename::AbstractString)` - use a CSV file with configuration
- `ScrapePOIConfig{T <: MetaPOI}(df::DataFrame)` - use a `DataFrame`

When the `T` parameter is not provided `AttractivenessMetaPOI` will be used.
When you do not want to use metadata provide `NoneMetaPOI` as `T`
"""
struct ScrapePOIConfig{T <: MetaPOI} 
    dkeys::Set{String}
    meta::Dict{Union{String, Tuple{String,String}}, T}
end

"""
Default built-in configuration for data scraping from OSM XML.
The default configuration will use AttractivenessMetaPOI
"""
const __builtin_config_path = joinpath(@__DIR__, "..", "config", "ScrapePOIconfig.csv")



function ScrapePOIConfig{T}(df::DataFrame) where T <: MetaPOI
    colnames = ["key", "values"]
    @assert all(colnames .∈ Ref(names(df)))

    dkeys = Set(String.(df.key))
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
    ScrapePOIConfig{T}(dkeys, meta)
end

ScrapePOIConfig(df::DataFrame) = ScrapePOIConfig{AttractivenessMetaPOI}(df)

function ScrapePOIConfig{T}(filename::AbstractString = __builtin_config_path) where T <: MetaPOI
    ScrapePOIConfig{T}(CSV.read(filename, DataFrame,types=Dict(
        :key => String, :values =>String) ))
end

ScrapePOIConfig(filename::AbstractString = __builtin_config_path) = ScrapePOIConfig{AttractivenessMetaPOI}(filename)

const __builtin_poiconfig = ScrapePOIConfig()

"""
    find_poi(filename::AbstractString; scrape_config::ScrapePOIConfig{T <: MetaPOI}=__builtin_poiconfig)

Generates a `DataFrame` with points of interests and from a given XML `filename`.
The data frame will also contain the metadata from `T` for each POI.

The `DataFrame` can be later used with `AttractivenessSpatIndex` to build an attractivenss spatial index.

The attractiveness values for the index will be used ones from the `scrape_config` file.
By default `__builtin_poiconfig` from `__builtin_config_path` will be used but you can define your own index.
"""
function find_poi(filename::AbstractString; scrape_config::ScrapePOIConfig{T}=__builtin_poiconfig) where T <: MetaPOI
    dkeys = scrape_config.dkeys
    meta = scrape_config.meta
    EMPTY_NODE = Node(0,0.,0.)
    nodes =  Dict{Int,Node}()
    ways_firstnode = Dict{Int, Node}()
    relations_firstnode = Dict{Int, Node}()
    elemtype = :X
    elemid = -1
    df= DataFrame()
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
        elseif waylookforfirstnd && nname == "nd"
            if hasnodeattributes(sr)
                attrs = nodeattributes(sr)
                curnode = nodes[parse(Int, attrs["ref"])]
                ways_firstnode[elemid] = curnode
                waylookforfirstnd = false
            else
                @warn "<way>/<nd> $nname, $i, no attribs?"
            end
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
        elseif nname == "tag"
            attrs = nodeattributes(sr)
            key = string(get(attrs,"k",""))
            if key in dkeys
                value = string(get(attrs,"v",""))
                # get either first key if it was of * type
                # otherwise try to get attractiveness for the tuple
                a = get(meta, key, get(meta, (key, value), nothing))
                if !isnothing(a)
                    # we are interested only in attractive POIs
                    push!(df, (;elemtype,elemid,nodeid=curnode.id, lat=curnode.lat, lon=curnode.lon, key, value, ntfromstruct(a)...) )
                end
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
    find_poi(osm::OpenStreetMapX.OSMData; scrape_config::ScrapePOIConfig=__builtin_poiconfig)
Finds POIs on the data from OSM parser. Please note that the OSM parser might not parse all the data from the XML file,
hence the results might be different than from `find_poi(filename::AbstractString)`.
Generally, usage of `find_poi(filename::AbstractString)` is stronlgy recommended.
"""
function find_poi(osm::OpenStreetMapX.OSMData; scrape_config::ScrapePOIConfig=__builtin_poiconfig)
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