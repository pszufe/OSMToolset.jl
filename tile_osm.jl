using CSV, EzXML, DataFrames
using Parsers, Parameters

# this is representation of the node (all nodes need to be stored in memory in this format)
struct Node
    id::Int
    lat::Float64
    lon::Float64
end



function gettag(line)
    ixₐ = findfirst('<', line)
    ixₐ == nothing && return ""
    ixᵦ = findnext(' ',line, ixₐ+2)
    if isnothing(ixᵦ)
        ixᵦ = findnext('>',line, ixₐ+2)
    end
    type = Symbol(view(line, ixₐ+1:ixᵦ-1 ))
    subtype = :X
    id = 0
    if type in [:node, :way, :relation]
        ix = last(findnext("id=",line, ixᵦ))
        id = Parsers.xparse(Int, line; pos=ix+1, openquotechar='"', closequotechar='"').val
    elseif type == :nd
        ix = last(findnext("ref=",line, ixᵦ))
        id = Parsers.xparse(Int, line; pos=ix+1, openquotechar='"', closequotechar='"').val
    elseif type == :member
        ix = last(findnext("type=",line, ixᵦ))
        poslen = Parsers.xparse(String, line; pos=ix+1, openquotechar='"', closequotechar='"').val
        subtype = Symbol(Parsers.getstring(line, poslen, UInt8(0)))
        ix = last(findnext("ref=",line, ixᵦ))
        id = Parsers.xparse(Int, line; pos=ix+1, openquotechar='"', closequotechar='"').val
    end
    (;type, subtype, id)
end

"""
    This is a special type representing geographic longitude as the values may wrap around
"""
primitive type FloatLon <: AbstractFloat 64 end
function FloatLon(x::Float64) 
    if abs(x) > 360
        x = x % 360
    end
    if x > 180.0
        return reinterpret(FloatLon,x-360.0)
    elseif x < -180.0
        return reinterpret(FloatLon,x+360.0)
    end 
    return reinterpret(FloatLon, x)
end
FloatLon(x::Integer) = FloatLon(Float64(x))
Float64(x::FloatLon) = reinterpret(Float64, x)
Base.show(io::IO, x::FloatLon) = Base.show(io, Float64(x))
import Base: +,-
+(a::FloatLon, b::Real)  = FloatLon(Float64(a)+b)
+(a::Real, b::FloatLon) = FloatLon(a+Float64(b))
-(a::FloatLon, b::FloatLon)  = Float64(a) < Float64(b) ? 360 - (Float64(b)-Float64(a)) : Float64(a)-Float64(b)  


"""
    A range of geographic coordinates for a map
"""
@with_kw struct Bounds
    minlat::Float64 = .0
    minlon::FloatLon = .0
    maxlat::Float64 = .0
    maxlon::FloatLon = .0
    latwh::Float64 = maxlat - minlat
    lonwh::Float64 = maxlon - minlon
end

toxmlline(bounds::Bounds) =  """<bounds minlat="$(bounds.minlat)" minlon="$(bounds.minlon)" maxlat="$(bounds.maxlat)" maxlon="$(bounds.maxlon)"/>"""


"""
    A set of bounds for all tiles
"""
@with_kw struct BoundsTiles
    bounds::Bounds
    nrow::Int
    ncol::Int
    tilelatwh::Float64 = (bounds.maxlat - bounds.minlat)/nrow
    tilelonwh::Float64 = (bounds.maxlon - bounds.minlon)/ncol
    tiles::Matrix{Bounds} = [Bounds(bounds.minlat+(row-1)*tilelatwh, bounds.minlon+(col-1)*tilelonwh, 
                             bounds.minlat+row*tilelatwh, bounds.minlon+col*tilelonwh, tilelatwh, tilelonwh) 
                             for row in 1:nrow, col in 1:ncol ]
end


function gettile(boundstiles::BoundsTiles, lat, lon)
    bounds = boundstiles.bounds
    row = min(boundstiles.nrow, max(1, floor(Int, (lat - bounds.minlat) / boundstiles.tilelatwh) + 1))
    col = min(boundstiles.ncol, max(1, floor(Int, (FloatLon(lon) - bounds.minlon) / boundstiles.tilelonwh) + 1))
    (row,col)
end

"""
Return Bounds that can be found in the first 10 lines of the OSM file named 'filename'
"""
function getbounds(filename::AbstractString)::Bounds
    res = nothing
    open(filename, "r") do io
        for _ in 1:10
            line = readline(io)
            if contains(line, "<bounds")
                n = root(parsexml(line))
                minlat = parse(Float64,n["minlat"])
                minlon = parse(Float64,n["minlon"])
                maxlat = parse(Float64,n["maxlat"])
                maxlon = parse(Float64,n["maxlon"])
                res = Bounds(;minlat, minlon, maxlat, maxlon)
                break;
            end
        end
    end
    if isnothing(res)
        throw(ArgumentError("<bounds> not found in the first 10 lines"))
    else
        return res
    end
end

function gettiles(node::Node, boundstiles::BoundsTiles, nodesnn::Dict{Int, Set{Node}})
    unique!([gettile(boundstiles, n.lat, n.lon) for n in [node;collect(get(nodesnn,node.id,Node[]))]])
end
function tile_osm_file(filename::AbstractString, bounds::Bounds = getbounds(filename); nrow::Integer=2, ncol::Integer=3)
    #dictionary containing neighbours for each node
    nodesnn = Dict{Int, Set{Node}}()
    #dictionary of tiles for ways 
    waystiles = Dict{Int, Vector{Tuple{Int,Int}}}()
    #dictionary of tiles for relations 
    relationstiles = Dict{Int, Vector{Tuple{Int,Int}}}()

    io = open(filename, "r")


    fname = basename(filename)
    if endswith(lowercase(fname), ".osm")
        fname = fname[1:end-4]
    end
    iotiles = [ open(joinpath(dirname(filename), "$(fname)_$(lpad(row,4,'0'))_$(lpad(col,4,'0')).osm"),"w") for row in 1:nrow, col in 1:ncol]
    # Buffers for each output
    # We first write to buffer since it is not known if there is anything to write out
    buftiles = [IOBuffer() for row in 1:nrow, col in 1:ncol]

    boundstiles = BoundsTiles(;bounds, nrow, ncol)
    nodesDict =  Dict{Int,Node}()
    seekstart(io)
    sr = EzXML.StreamReader(io)
    i = 0
    EMPTY_NODE = Node(0,0.,0.)
    lastnode = EMPTY_NODE
    for dat in sr
        dat != EzXML.READER_ELEMENT && continue;
        i += 1
        nname = nodename(sr)
        if nname == "node"
            attrs = nodeattributes(sr)
            id=parse(Int, attrs["id"])
            nodesDict[id] = Node(id, parse(Float64,attrs["lat"]), parse(Float64,attrs["lon"]))
        end
        if nname == "way"
            lastnode =    EMPTY_NODE     
        elseif nname == "nd" 
            if hasnodeattributes(sr)
                attrs = nodeattributes(sr)
                node = nodesDict[parse(Int, attrs["ref"])]
                if lastnode !== EMPTY_NODE
                    push!(get!(Set{Node}, nodesnn, lastnode.id), node)
                    push!(get!(Set{Node}, nodesnn, node.id), lastnode)
                end
                lastnode = node
            else
                @warn "<way>/<nd> $nname, $i, no attribs?"
            end
        end
    end

    flush(stdout)
    seekstart(io)

    # the first two lines always contain headers
    # we start with two header lines and a bounds range
    println.(iotiles, Ref(readline(io)))
    println.(iotiles, Ref(readline(io)))
    println.(iotiles, toxmlline.(boundstiles.tiles))

    i = 0
    curtileset = Vector{Tuple{Int,Int}}()

    while !eof(io) 
        line = readline(io)
        type, subtype, id = gettag(line)
        if type == :node
            curtileset = gettiles(nodesDict[id],boundstiles,nodesnn)
        elseif type == :way
            buftilesWrite = Set{Tuple{Int,Int}}()
            println.(buftiles, Ref(line))
            wayid = id
            while !eof(io) && type != Symbol("/way")
                line = readline(io)
                type, subtype, id = gettag(line)
                if type==:nd
                    tils = gettiles(nodesDict[id],boundstiles,nodesnn)
                    push!.(Ref(buftilesWrite), tils)
                    println.(getindex.(Ref(buftiles), first.(tils), last.(tils)) , Ref(line))        
                else
                    println.(buftiles, Ref(line))
                end
            end
            curtileset = collect(buftilesWrite)
            waystiles[wayid] = deepcopy(curtileset)
            write.(getindex.(Ref(iotiles), first.(curtileset), last.(curtileset)),
                    take!.(getindex.(Ref(buftiles), first.(curtileset), last.(curtileset))) )
            #cleanup
            take!.(buftiles)
            empty!(curtileset)
        elseif type == :relation
            buftilesWrite = Set{Tuple{Int,Int}}()
            println.(buftiles, Ref(line))
            relationid = id
            while !eof(io) && type != Symbol("/relation")
                line = readline(io)
                type, subtype, id = gettag(line)
                if type==:member
                    local tils
                    if subtype == :node
                        tils = haskey(nodesDict, id) ? gettiles(nodesDict[id],boundstiles,nodesnn) : Tuple{Int,Int}[]
                    elseif  subtype == :way
                        tils = get(waystiles, id, Tuple{Int,Int}[])
                    elseif  subtype == :relation
                        tils = get(relationstiles, id, Tuple{Int,Int}[]) 
                    end                        
                    push!.(Ref(buftilesWrite), tils)
                    println.(getindex.(Ref(buftiles), first.(tils), last.(tils)) , Ref(line))        
                else
                    println.(buftiles, Ref(line))
                end
            end
            curtileset = collect(buftilesWrite)
            relationstiles[relationid] = deepcopy(curtileset)
            write.(getindex.(Ref(iotiles), first.(curtileset), last.(curtileset)),
                    take!.(getindex.(Ref(buftiles), first.(curtileset), last.(curtileset))) )
            #cleanup
            take!.(buftiles)
            empty!(curtileset)
        end
        length(curtileset) > 0 && println.(getindex.(Ref(iotiles), first.(curtileset), last.(curtileset)),Ref(line))
    end
    println.(iotiles, Ref("</osm>"))
    close.(iotiles)
    close(io)
end

filename = raw"c:\temp\delaware-latest.osm"
#filename = raw"c:\temp\la-rioja-latest.osm"
#filename = raw"c:\temp\iceland-latest.osm"

bounds = getbounds(filename)

boundsR = Bounds(;minlat=floor(bounds.minlat*2; digits=1)/2,minlon=floor(Float64(bounds.minlon)*2; digits=1)/2,
                  maxlat=ceil(bounds.maxlat*2; digits=1)/2,maxlon=ceil(Float64(bounds.maxlon)*2; digits=1)/2   )
nrow = round(Int,(boundsR.latwh)*20)
ncol = round(Int,(boundsR.lonwh)*20)

@time tile_osm_file(filename, boundsR;nrow,ncol);
#CSV.write(filename*".out.csv", df)

