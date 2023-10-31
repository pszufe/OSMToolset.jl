# Reference


```@meta
CurrentModule = OSMToolset
DocTestSetup = quote
    using OSMToolset
end
```

Scraping points-of-interest (POI)
---------------------
```@docs
find_poi
ScrapePOIConfig
MetaPOI
NoneMetaPOI
AttractivenessMetaPOI
```

Measuring Attractiveness Spatial Index
--------------------------------------
```@docs
AttractivenessSpatIndex
attractiveness
calculate_attractiveness
get_attractiveness_group
clean_pois_by_group
```

Efficient searching for nearest nodes in OSM
--------------------------------------------
```@docs
NodeSpatIndex
findnode
```

Tiling OSM file
------------------
```@docs
calc_tiling(::AbstractString, ::Float64, ::Float64)
calc_tiling(::OSMToolset.Bounds, ::Float64, ::Float64)
tile_osm_file(::AbstractString, ::Bounds; ::Integer, ::Integer, ::AbstractString)
Bounds
getbounds(::AbstractString)
```

Helper functions
```@docs
sample_osm_file
FloatLon
OSMToolset.Node
```
