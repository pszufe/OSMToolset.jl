Reference
=========

```@meta
CurrentModule = OSMToolset
DocTestSetup = quote
    using OSMToolset
end
```

Measuring Attractiveness Spatial Index
---------------------
```@docs
find_poi(::AbstractString; ::AbstractString)
AttractivenessConfig
AttractivenessSpatIndex
attractiveness(::AttractivenessSpatIndex, ::ENU; ::Bool)
attractiveness(::AttractivenessSpatIndex, ::Float64; ::Float64)
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