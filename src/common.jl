"""
    Node(id::Int, lat::Float64, lon::Float64)

A node is a point in the map. It has an id, a latitude and a longitude.
"""
struct Node
    id::Int
    lat::Float64
    lon::Float64
end

"""
    sample_osm_file()

Provides location of sample OSM file for tests and examples.
"""
function sample_osm_file()::String
    joinpath(dirname(pathof(OSMToolset)),"..","test","data","boston.osm")
end
