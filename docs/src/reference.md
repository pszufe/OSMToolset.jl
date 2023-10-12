Reference
=========

```@meta
CurrentModule = OSMToolset
DocTestSetup = quote
    using OSMToolset
end
```

Scraping points-of-interest (POI)
---------------------
```@docs
find_poi(::AbstractString; ::AbstractString)
ScrapePOIConfig
```

Measuring Attractiveness Spatial Index
--------------------------------------
```@docs
AttractivenessSpatIndex
attractiveness(::AttractivenessSpatIndex, ::ENU; ::Function; ::Bool)
attractiveness(::AttractivenessSpatIndex, ::Float64, ::Float64; ::Function; ::Bool)
attractiveness(::AttractivenessSpatIndex, ::LLA; ::Function; ::Bool)
```

Tiling OSM file
------------------
```@docs
calc_tiling(::AbstractString, ::Float64, ::Float64) 
calc_tiling(::OSMToolset.Bounds, ::Float64, ::Float64)
tile_osm_file(::AbstractString, ::Bounds; ::Integer, ::Integer, ::AbstractString)
OSMToolset.BoundsTiles
```

Helper functions
```@docs
   OSMToolset.FloatLon
   OSMToolset.Node
   OSMToolset.Bounds
   OSMToolset.getbounds(::AbstractString)
```
