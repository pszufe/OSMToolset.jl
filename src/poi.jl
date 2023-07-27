
struct Attract
    class::String
    points::Int
    range::Int
end
"""
    Represents the configuration of the data scraping process from OSM XML.
Only those pieces of data will be scraped that are defined here.

The configuration is defined in a DataFrame with the following columns:
`class`, `key`, `values`, `points`, `range`.
Instead of the DataFrame a paths to a CSV file can be provided.

* Constructors *
- `AttractivenessConfig()` - default inbuilt configuration for data scraping. 
   Note that the default configuration can change with library updates
- `AttractivenessConfig(filename::AbstractString)` - use a CSV file with configuration
- `AttractivenessConfig(df::DataFrame)` - use a `DataFrame`


"""
struct AttractivenessConfig 
    dkeys::Set{String}
    attract::Dict{Union{String, Tuple{String,String}}, Attract}
end

const __builtin_attract_path = joinpath(@__DIR__, "..", "config", "Attractiveness.csv")

function AttractivenessConfig(df::DataFrame)
    colnames = ["class", "key", "points", "range", "values"]
    @assert all(colnames .∈ Ref(names(df)))
    dkeys = Set(dfa.key)
    attract = Dict{Union{String, Tuple{String,String}}, Attract}()
    for row in eachrow(dfa)
        a = Attract(row.class, row.points, row.range)
        for value in string.(split(row.value,','))

            if value == "*"
                attract[row.key] = a
            else
                attract[row.key, value] = a
            end
        end
    end
    AttractivenessConfig(dkeys, attract)
end

function AttractivenessConfig(filename::AbstractString = __builtin_attract_path)
    AttractivenessConfig(CSV.read(filename, DataFrame,types=Dict(
        :class => String, :key => String, :points => Int, :range => Int, :values =>String) ))
end

const __builtin_attract = AttractivenessConfig()

"""
    find_poi(filename::AbstractString; attract_config::AttractivenessConfig=__builtin_attract)

Generates a `DataFrame` with points of interests and their attractivenss from a given XML `filename`.

This `DataFrame` can be later used with `AttractivenessSpatIndex` to build an attractivenss spatial index.

The attractiveness values for the index will be used ones from the `attract_config` file.
By default `builtin_attract_path` will be used but you can define your own index.
"""
function find_poi(filename::AbstractString; attract_config::AttractivenessConfig=__builtin_attract)
    dkeys = attract_config.dkeys
    attract = attract_config.attract

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
                a = get(attract, key, get(attract, (key, value), nothing))
                if !isnothing(a)
                    # we are interested only in attractive POIs
                    push!(df, (;elemtype,elemid,nodeid=curnode.id, lat=curnode.lat, lon=curnode.lon, key, value,a.class, a.points, a.range ) )
                end
            end
        end
    end
    df2 = DataFrame(g[findmax(g.points)[2], :]  for g in  groupby(df, [:nodeid, :class]))
    df2
end


function find_poi(osm::OSMData; attract_config::AttractivenessConfig=__builtin_attract)
    dkeys = attract_config.dkeys
    attract = attract_config.attract

    df = DataFrame()
    for (node, (key, value)) in osm.features
        # get either first key if it was of * type
        # otherwise try to get attractiveness for the tuple
        a = get(attract, key, get(attract, (key, value), nothing))
        if a !== nothing
            # we are interested only in attractive POIs            #push!(df, (;elemtype, elemid, nodeid=curnode.id, lat=curnode.lat, lon=curnode.lon, key, value, a.class, a.points, a.range))
            lla = osm.nodes[node]
            push!(df, (;nodeid=node, lat=lla.lat, lon=lla.lon, key, value, a.class, a.points, a.range))
        end
    end
    df2 = DataFrame(g[findmax(g.points)[2], :] for g in groupby(df, [:nodeid, :class]))
    return df2
end
