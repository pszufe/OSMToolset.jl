module OSMToolset

using CSV, DataFrames
using SpatialIndexing
using StatsBase
using NamedTupleTools
using Parsers, EzXML, Parameters
import OpenStreetMapX
import OpenStreetMapX: OSMData, LLA, ENU, distance


include("common.jl")
include("tile.jl")
include("poi.jl")
include("attractiveness.jl")


export tile_osm_file
export FloatLon
export AttractivenessSpatIndex
export attractiveness
export find_poi
export calc_tiling
export getbounds, Bounds
export ScrapePOIConfig
export MetaPOI
export NoneMetaPOI
export AttractivenessMetaPOI
export sample_osm_file
export calculate_attractiveness, get_attractiveness_group
export clean_pois_by_group

end # module OSMToolset
