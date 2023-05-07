using CSV, EzXML, DataFrames
using Parsers


struct Node
    id::Int
    lat::Float64
    lon::Float64
end

function parse_osm_file(filename)
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
            push!(df, (;elemtype,elemid,nodeid=curnode.id, lat=curnode.lat, lon=curnode.lon, k=string(get(attrs,"k",nothing)), v=string(get(attrs,"v",nothing)) ) )
        end
    end
    df
end

filename = "c:\\temp\\delaware-latest.osm"

@time df = parse_osm_file(filename);

CSV.write(filename*".out.csv", df)