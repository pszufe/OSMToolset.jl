"""
    Node

    A node is a point in the map. It has an id, a latitude and a longitude.
    All nodes need to be stored in memory in this format.
"""
struct Node
    id::Int
    lat::Float64
    lon::Float64
end

"""
    Provides location of sample OSM file for tests 
"""
function sample_osm_file()::String
    joinpath(dirname(pathof(OSMToolset)),"..","test","data","boston.osm")
end
