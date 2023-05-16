using CSV, EzXML, DataFrames
using Parsers


struct Attract
    class::String
    points::Int
    range::Int
end

function load_attr_config(filename = "Attractiveness.csv") 
    dfa = CSV.read(filename, DataFrame,types=Dict(
        :class => String, :key => String, :points => Int, :range => Int, :values =>String) )
    dfa.values .= (x->string.(split(x,','))).(dfa.values)
    dkeys = Set(dfa.key)
    attract = Dict{Union{String, Tuple{String,String}}, Attract}()
    for row in eachrow(dfa)
        a = Attract(row.class, row.points, row.range)
        for value in row.values
            if value == "*"
                attract[row.key] = a
            else
                attract[row.key, value] = a
            end
        end
    end
    (;dkeys, attract)
end


struct Node
    id::Int
    lat::Float64
    lon::Float64
end

# %%

function parse_osm_file(filename;attract_config="Attractiveness.csv")
    dkeys, attract = load_attr_config(attract_config)

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

filename = raw"c:\temp\delaware-latest.osm"

@time df = parse_osm_file(filename);


CSV.write(filename*".attractiveness.csv", df)