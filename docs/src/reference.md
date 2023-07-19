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
AttractivenessSpatIndex(::AbstractDataFrame, ::LLA)
attractiveness(::AttractivenessSpatIndex, ::ENU; ::Bool)
```

Tiling OSM file
------------------
```@docs
calc_tiling(::AbstractString, ::Float64, ::Float64)
tile_osm_file(::AbstractString, ::Bounds; ::Integer, ::Integer, ::AbstractString)
```