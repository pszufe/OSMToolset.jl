

"""
Internal method for parsing XML line
"""
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
    This is an AbstractFloat type representing geographic longitude as the values may wrap around
"""
primitive type FloatLon <: AbstractFloat 64 end
function FloatLon(x::Float64)
    if abs(x) > 360.0
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
+(a::FloatLon, b::Real) = FloatLon(Float64(a)+b)
+(a::Real, b::FloatLon) = FloatLon(a+Float64(b))
-(a::FloatLon, b::FloatLon)  = Float64(a) < Float64(b) ? 360 - (Float64(b)-Float64(a)) : Float64(a)-Float64(b)


"""
    A range of geographic coordinates for a map
"""
Base.@kwdef struct Bounds
    minlat::Float64 = .0
    minlon::FloatLon = .0
    maxlat::Float64 = .0
    maxlon::FloatLon = .0
    latwh::Float64 = maxlat - minlat
    lonwh::Float64 = maxlon - minlon
end

"""
Internal method generating XML line from given bounds
"""
toxmlline(bounds::Bounds) =  """<bounds minlat="$(bounds.minlat)" minlon="$(bounds.minlon)" maxlat="$(bounds.maxlat)" maxlon="$(bounds.maxlon)"/>"""


"""
    A set of bounds for all tiles
"""
Base.@kwdef struct BoundsTiles
    bounds::Bounds
    nrow::Int
    ncol::Int
    tilelatwh::Float64 = (bounds.maxlat - bounds.minlat)/nrow
    tilelonwh::Float64 = (bounds.maxlon - bounds.minlon)/ncol
    tiles::Matrix{Bounds} = [Bounds(bounds.minlat+(row-1)*tilelatwh, bounds.minlon+(col-1)*tilelonwh,
                             bounds.minlat+row*tilelatwh, bounds.minlon+col*tilelonwh, tilelatwh, tilelonwh)
                             for row in 1:nrow, col in 1:ncol ]
end

"""
    gettile(boundstiles::BoundsTiles, lat, lon)

Returns a `(row, column)` tile identifier for a given `lat` and `lon` coordinates.
"""
function gettile(boundstiles::BoundsTiles, lat, lon)
    bounds = boundstiles.bounds
    row = min(boundstiles.nrow, max(1, floor(Int, (lat - bounds.minlat) / boundstiles.tilelatwh) + 1))
    col = min(boundstiles.ncol, max(1, floor(Int, (FloatLon(lon) - bounds.minlon) / boundstiles.tilelonwh) + 1))
    (row,col)
end

"""
    getbounds(filename::AbstractString)::Bounds

Returns Bounds that can be found in the first 10 lines of the OSM file named 'filename'
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

"""
    calc_tiling(bounds::Bounds, latTileSize::Float64, lonTileSize::Float64)

Calculates recommended bounds, number of rows and columns for a given
`bounds` and size of tile `latTileSize` x `lonTileSize`.
"""
function calc_tiling(bounds::Bounds, latTileSize::Float64, lonTileSize::Float64)
    boundsR = Bounds(;minlat=floor(bounds.minlat/latTileSize)*latTileSize,minlon=floor(Float64(bounds.minlon)/lonTileSize)*lonTileSize,
                maxlat=ceil(bounds.maxlat/latTileSize)*latTileSize,maxlon=ceil(Float64(bounds.maxlon)/lonTileSize)*lonTileSize   )
    nrow = round(Int,(boundsR.latwh)*(1/latTileSize))
    ncol = round(Int,(boundsR.lonwh)*1/lonTileSize)
    (;bounds = boundsR, nrow, ncol)
end


"""
    calc_tiling(filename::AbstractString, latTileSize::Float64, lonTileSize::Float64)

Calculates recommended bounds, number of rows and columns for a given
`filename` and size of tile `latTileSize` x `lonTileSize`.
"""
function calc_tiling(filename::AbstractString, latTileSize::Float64, lonTileSize::Float64)
    calc_tiling(getbounds(filename), latTileSize, lonTileSize)
end


function tile_osm_file(filename::AbstractString, latTileSize::Float64, lonTileSize::Float64, bounds::Bounds = getbounds(filename); out_dir::String=dirname(filename))
    params = calc_tiling(bounds, latTileSize,lonTileSize)
    tile_osm_file(filename,params.bounds;nrow=params.nrow, ncol=params.ncol, out_dir=out_dir)
end

"""
    tile_osm_file(filename::AbstractString, [bounds::Bounds]; nrow::Integer, ncol::Integer, [out_dir::AbstractString]

Provide the tiling functionality for maps.
A `filename` will be open for processing and the tiling will be done around given `bounds`.
If `bounds` are not given they will be calculated using `getbounds` function.
The tiling will be performed with a matrix having `nrow` rows and `ncol` columns.
The output will be written to the folder name `out_dir`.
If none `out_dir` is given than as the output is written to where `filename` is located.

Returns a `Matrix{String}` of size `nrow` x `ncol` containing the names of the files created.
"""
function tile_osm_file(filename::AbstractString, bounds::Bounds = getbounds(filename); nrow::Integer=2, ncol::Integer=3, out_dir::String=dirname(filename))
    #dictionary of tiles for ways
    waystiles = Dict{Int, Vector{Tuple{Int,Int}}}()
    #dictionary of tiles for relations
    relationstiles = Dict{Int, Vector{Tuple{Int,Int}}}()

    io = open(filename, "r")
    fname = basename(filename)
    if endswith(lowercase(fname), ".osm")
        fname = fname[1:end-4]
    end
    mkpath(joinpath(out_dir))
    boundstiles = BoundsTiles(;bounds, nrow, ncol)

    # maps nodeids to Node structs
    nodesDict = Dict{Int,Node}()

    # dictionary containing a Set of neighbours for each node
    nodesnn = Dict{Int, Set{Node}}()


    """
    1st File pass: Build a dictionary of nodes (1st file pass)
    a) find all <node/> tags end extract lattitude and longitute for each node
     b) navigate through all <way> tags and for each <nd> tag adjust node negihbours.
    In the result of step 1 we have two objects:
     - nodesDict that maps nodeids to Node structs
     - nodesnn that for each node has a Set of his neighbours
    """

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
            lastnode = EMPTY_NODE
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

    """
    2nd File pass. Perform the tiling
     This code reads line by line rather than using EzXML because
     I did not find a method in EzXML to write back XML elements in a convenient way. /TODO/
     Each line is cheked whether it is a <node> or <way> or <relation>
     a) If a line is a node than gettiles is called. Gettiles finds all tiles for a file on the base
        of coordinates of the file and all this neighbours.
     b) If a line is a way we started line by line writing it to buffers for all tiles.
        Each <nd> line is checked for gettiles destination and is written to the appropiate tiles
        If a </way> is found the check for all tile buffer is performed. Those buffers that did not
        have a single <nd> line are discarded.
        The non-discarded buffers are written to appropiate files.
     c) Similarly such as ways the relations are processed. They are also checked for the dependence
        of ways (as relations can reference both nodes and ways)"
    """


    iotiles = Matrix{IOStream}(undef, nrow, ncol)
    filenames = Matrix{String}(undef, nrow, ncol)
    for row in 1:nrow, col in 1:ncol
        tile_bounds = boundstiles.tiles[row,col]
        filenames[row,col] = "$(tile_bounds.minlat)_$(tile_bounds.maxlat)_$(tile_bounds.minlon)_$(tile_bounds.maxlon).osm"
        iotiles[row,col] = open(joinpath(out_dir, filenames[row,col]), "w")
    end

    # Buffers for each output
    # We first write to buffer since it is not known if there is anything to write out
    buftiles = [IOBuffer() for row in 1:nrow, col in 1:ncol]

    #go again to the beginning of the file
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
    return filenames
end
