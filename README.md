

# Tools for manipulation of Open Steet Map data

**Tools for point-of-interest (POI) extraction, walkability/attractiveness indexes and tiling of XML map data**

`OSMToolset` package provides the tools for efficient extraction of [point-of-interest](https://en.wikipedia.org/wiki/Point_of_interest) from maps and building various custom [walkability](https://en.wikipedia.org/wiki/Walkability) indexes  in [Julia](https://julialang.org/).

**Documentation**:  [![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://pszufe.github.io/OSMToolset.jl/dev/)
<br>
[![DOI](https://zenodo.org/badge/637564645.svg)](https://zenodo.org/doi/10.5281/zenodo.10016849)
<!-- [![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://pszufe.github.io/OSMToolset.jl/stable/) -->

# Installation
```julia
using Pkg; Pkg.add("OSMToolset")
```

# Features

1. Export points-of-interests (POIs) from a OSM xml map file to a [`DataFrame`](https://github.com/JuliaData/DataFrames.jl)
2. A spatial attractiveness index for analyzig location attractivenss across maps (can be used for an example in research of city's walkability index)
3. A spatial index for finding nearest nodes in maps to a given `LLA` or `ENU` coordinates
4. OSM map tiling/slicing - functionality to tile a large OSM file into smaller tiles without loosing connections on the tile edge. The map tiling works directly on XML files

![Restaurant walkability](docs/src/Boston_restaurant.png)
<br>(a complete code for this visualization can be found [in the docs](https://pszufe.github.io/OSMToolset.jl/dev/visualize/))

Please note that the maps provided by the [OpenStreetMap](https://www.openstreetmap.org/) project contain very detailed information about schools, businesses, shops, restaurants, cafes, parking spaces, hospitals etc. With this tool you get an effient, customizable API for extraction of data on such points of interests for further processing. This information can be further used e.g. to build walkability indexes that can be used to explain attractiveness of some parts of a city. Hence the second functionality of the package is to provide an interface (based on the [`SpatialIndexing`](https://github.com/alyst/SpatialIndexing.jl) package) for building of efficient attractiveness indexes of any urban area.
Since the OSM map XML files are usully very large, sometimes it is required to tile the files into smailler chunks for efficient parallel processing. Hence, yet another functionality of this package is an OSM file tiler.

This toolset has been constructed with performance in mind for large scale scraping of spatial data.
Hence, this package should work sufficiently well with datasets of size of entire states or countries.

# Basic functionalities walkthrough

## Exporting points of interests

The examples assume that the sample file is used
```
file = sample_osm_file()
```
Let us use the default configuration for parsing.
```
julia> df1 = find_poi(file)
78×10 DataFrame
 Row │ elemtype  elemid      nodeid      lat      lon       key               value       ⋯
     │ Symbol    Int64       Int64       Float64  Float64   String            String      ⋯
─────┼─────────────────────────────────────────────────────────────────────────────────────
   1 │ node        69487440    69487440  42.3649  -71.1029  public_transport  stop_positi ⋯
  ⋮  │    ⋮          ⋮           ⋮          ⋮        ⋮             ⋮                ⋮     ⋱
  78 │ relation     7943642  2913461577  42.3624  -71.0847  leisure           park        ⋯
                                                              4 columns and 76 rows omitted
```
The default configuration file can be founds in `OSMToolset.__builtin_config_path`. This configuration has meta-data columns that can be seen in results of the parsing process. You could create on base on that your own configuration and use it from scratch.

Suppose that rather you want to configure manually what is scraped. Perhaps we just wanted parking spaces
that can be either defined in an OSM file as `amenity=parking` or as `parking` key value:
```
julia> config = ScrapePOIConfig("parking",("amenity","parking"))
ScrapePOIConfig{NoneMetaPOI} with 2 keys:
 No │ key      values
────┼──────────────────
  1 │ amenity  parking
  2 │ parking  *
```

Note that the scraping configuration can be extracted to a data frame by executing `config |> DataFrame`. Such dataframe can also be used to create a new configuration by executing `ScrapePOIConfig{NoneMetaPOI}(DataFrame(key=["amenity","parking"],values=["parking","*"]))`.

Note that since we do not use meta data yet we use parameter: `NoneMetaPOI`.
Now this can be scraped as :
```
julia> df2 = find_poi(file, config)
12×7 DataFrame
 Row │ elemtype  elemid      nodeid      lat      lon       key      value
     │ Symbol    Int64       Int64       Float64  Float64   String   String
─────┼───────────────────────────────────────────────────────────────────────
   1 │ way        187565434  1982207088  42.3603  -71.0866  amenity  parking
  ⋮  │    ⋮          ⋮           ⋮          ⋮        ⋮         ⋮        ⋮
  12 │ way       1052438049  9672086211  42.3624  -71.0878  parking  surface                                                              10 rows omitted
```

It is also possible to extract adjacent tags within the same node - this cab be achieved via the `all_tags` option.
For an example we could get the information on parking place metadata.

```
find_poi(file, ScrapePOIConfig("parking",("amenity","parking")); all_tags=true)
25×7 DataFrame
 Row │ elemtype  elemid      nodeid      lat      lon       key            value
     │ Symbol    Int64       Int64       Float64  Float64   String         String
─────┼────────────────────────────────────────────────────────────────────────────────
   1 │ way        187565434  1982207088  42.3603  -71.0866  amenity        parking
   2 │ way        187565434  1982207088  42.3603  -71.0866  access         private
   3 │ way        187565434  1982207088  42.3603  -71.0866  parking        surface
   4 │ way        187565434  1982207088  42.3603  -71.0866  surface        asphalt
  ⋮  │    ⋮          ⋮           ⋮          ⋮        ⋮            ⋮            ⋮
  25 │ way       1052438049  9672086211  42.3624  -71.0878  parking        surface
                                                                       20 rows omitted
```
It can be seen that the same nodeid is repeated for different tags.

The data that we extract can be decorated with additionaly information, such as range and influence of the POI.

```
julia> config2 = ScrapePOIConfig(("amenity","cafe")=>AttractivenessMetaPOI(:food,1,500), ("amenity","restaurant")=>AttractivenessMetaPOI(:food,2,1000), ("parking",("amenity","parking")) => AttractivenessMetaPOI(:car,1,500))
ScrapePOIConfig{AttractivenessMetaPOI} with 2 keys:
 No │ key      values      group  influence  range
────┼───────────────────────────────────────────────
  1 │ amenity  cafe        food         1.0   500.0
  2 │ amenity  restaurant  food         2.0  1000.0
```
Here we assume that the importance of restaurant is larger than of cafe and that people are more likely to walk a larger distance to visit a restaurant.

```
julia> filter!(r->r.nodeid in [1884055322, 11173231405], # select two places
         find_poi(file, config2, all_tags=true))
5×10 DataFrame
 Row │ elemtype  elemid       nodeid       lat      lon       key            value               group    influence  range
     │ Symbol    Int64        Int64        Float64  Float64   String         String              Symbol?  Float64?   Float64?
─────┼─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ node       1884055322   1884055322  42.3617  -71.09    amenity        cafe                food           1.0      500.0
   2 │ node       1884055322   1884055322  42.3617  -71.09    name           Forbes Family Cafe  missing  missing    missing
   3 │ node       1884055322   1884055322  42.3617  -71.09    opening_hours  Mo-Fr 11:00-15:00   missing  missing    missing
   4 │ node      11173231405  11173231405  42.3622  -71.0864  amenity        cafe                food           1.0      500.0
   5 │ node      11173231405  11173231405  42.3622  -71.0864  name           Ripple Cafe         missing  missing    missing
```


The data can be further processed in many ways. For example [here](https://pszufe.github.io/OSMToolset.jl/dev/visualize/) is a sample code that performs POI vizualisation

## Spatial attractiveness processing

Let's consider a more complex attractiveness information:
```
 config3 = ScrapePOIConfig(("amenity","cafe")=>AttractivenessMetaPOI(:food,1,500), ("amenity","restaurant")=>AttractivenessMetaPOI(:food,2,1000), (["parking",("amenity","parking")] .=> Ref(AttractivenessMetaPOI(:car,1,500)))... )
ScrapePOIConfig{AttractivenessMetaPOI} with 4 keys:
 No │ key      values      group  influence  range
────┼───────────────────────────────────────────────
  1 │ amenity  cafe        food         1.0   500.0
  2 │ amenity  parking     car          1.0   500.0
  3 │ amenity  restaurant  food         2.0  1000.0
  4 │ parking  *           car          1.0   500.0
```

Note that in this demo we assume attractiveness configuration defined as `AttractivenessMetaPOI`. If you want a different structure of data for this index you need to crate a subtype of `MetaPOI` and use it in the constructor.

We search for such locations:
```
julia> df3 = find_poi(file, config3)
18×10 DataFrame
 Row │ elemtype  elemid       nodeid       lat      lon       key      value       group   influence  range
     │ Symbol    Int64        Int64        Float64  Float64   String   String      Symbol  Float64    Float64
─────┼────────────────────────────────────────────────────────────────────────────────────────────────────────
   1 │ node       1884054889   1884054889  42.3621  -71.0892  amenity  cafe        food          1.0    500.0
   2 │ node       1884055322   1884055322  42.3617  -71.09    amenity  cafe        food          1.0    500.0
  ⋮  │    ⋮           ⋮            ⋮          ⋮        ⋮         ⋮         ⋮         ⋮         ⋮         ⋮
  17 │ way        1052438049   9672086211  42.3624  -71.0878  amenity  parking     car           1.0    500.0
  18 │ way        1052438049   9672086211  42.3624  -71.0878  parking  surface     car           1.0    500.0
                                                                                               14 rows omitted
```

Now with this data we create a spatial attractiveness index in the following way:
```
ix = AttractivenessSpatIndex(df3);
```

Let us consider a point on the map:
```
using Statistics
lat, lon = mean(df3.lat), mean(df3.lon)
```
We can use the API to calculate attractiveness of that location:
```
julia> attractiveness(ix, lat, lon)
(car = 8.595822085195946, food = 5.151440338789913)
```
For this location we can see it is easy to find food and park your car nearby.

If, for some debugging purposes, we want to understand what data has been used to calculate that attractiveness use the `explain=true` parameter:
```
julia> attractiveness(ix, lat, lon; explain=true)
(car = 8.595822085195946, food = 5.151440338789913, explanation = 18×7 DataFrame
 Row │ group   influence  range    attractiveness  poidistance  lat      lon
     │ Symbol  Float64    Float64  Float64         Float64      Float64  Float64
─────┼────────────────────────────────────────────────────────────────────────────
   1 │ food          1.0    500.0        0.183414      408.293  42.3599  -71.0913
  ⋮  │   ⋮         ⋮         ⋮           ⋮              ⋮          ⋮        ⋮
  18 │ food          2.0   1000.0        1.44716       276.42   42.3627  -71.084
                                                                   16 rows omitted)ted
```
The attractiveness function is fully configurable on how the attractiveness is actually calculated.
The available parameters can be used to define attractiveness dimension, aggreagation function,
attractivess function and how the distance is on map is calculated.

Let us for an example take maximum influence values rather than summing them:
```
julia> att = attractiveness(ix, lat, lon, aggregator = x -> length(x)==0 ? 0 : maximum(x))
(car = 0.8840868352005442, food = 1.747669233262405)
```


We could also used a DataFrame without meta data columns for the attractiveness:
```
df4 = find_poi(file, ScrapePOIConfig(("amenity","parking"), "parking"))

ix4 = AttractivenessSpatIndex{NoneMetaPOI}(df4; get_range=a->300, get_group=a->:parking);
```
Note that since we did not have metadata we have manually provided `300` meters for the range and `:parking` for the group.

Now we can use this custom scraper to query the attractiveness:
```
julia> attractiveness(ix4, lat, lon; aggregator = sum, calculate_attractiveness = (a,dist) -> dist > 300 ? 0 : 300/dist )
(parking = 30.235559263812686,)
```
Note that for this code to work we needed to provide the way the attractiveness is calculated with the respect of metadata a (now an empty `struct` as this is NoneMetaPOI).

## OSM map tiling/slicing

The native format for OSM files is XML. The files are often huge and for many processing scenarios it might make sense to slice them into smaller portions. That is where this functionality becomes handy.

The file tiling can be executed as follows:
```
outfiles = tile_osm_file("file.osm", nrow=2, ncol=3, out_dir="some/target/directory")
```
After the execution `outfile` will be a matrix with file names of all tiles.


File tiling limitations
-----------------------
The OSM tiler is simultanously opening a file writer for each file. The operating system might limit the number of simultanously opened file descriptors. If you want to create large number of tiles you need to either change the operating system setting accordingly or use a recursive approach to file tiling.

## Aknowledgments

This research was funded by National Science Centre,  Poland, grant number 2021/41/B/HS4/03349.

<sup>This tool is using some code from the previous work of Marcin Żurek, under the same research grant. The initial prototype can be found at:
https://github.com/mkloe/OSMgetPOI.jl</sup>
