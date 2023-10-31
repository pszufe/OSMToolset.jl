

# Tools for Open Steet Map: Point-of-Interest extraction and tiling of map data

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://pszufe.github.io/OSMToolset.jl/)

The maps provided by the OpenStreetMap project contain very detailed information about schools, businesses, shops, restaurants, cafes, parking spaces, hospitals etc. The goal of this tools is to provide an effient API for extraction of data on such points of interest (POIs) for further processing. This information can be further used e.g. to build walkability indexes that can be used to explain attractiveness of some parts of a city. Hence the second functionality of the package is to provide an interface (based on the `SpatialInexing.jl` package) for efficient building of attractiveness indexes of any urban area.
Since the OSM map XML files are usully very large, sometimes it is required to tile the files into smailler chunks for efficient parallel processing. Hence, the third functionality of this package is an OSM file tiler.

The package offers the following functionalities:
1. Export points-of-interests (POIs) from a OSM xml map file to a `DataFrame`
2. A spatial attractiveness index for analyzig location attractivenss across maps (can be used for an example in research of city's walkability index)
3. OSM map tiling/slicing - functionality to tile a large OSM file into smaller tiles without loosing connections on the tile edge. The map tiling works directly on XML files

This toolset has been constructed with performance in mind for large scale scraping of spatial data.
Hence, this package should work sufficiently well with datasets of size of entire states or countries.

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
```
myconfig = ScrapePOIConfig{AttractivenessMetaPOI}(OSMToolset.__builtin_config_path)
df1 = find_poi(file;scrape_config=myconfig)
```

Suppose that rather you want to configure manually what is scraped. Perhaps we just wanted parking spaces
that can be either defined in an OSM file as `amenity=parking` or as `parking` key value:
```
julia> config = DataFrame(key=["parking", "amenity"], values=["*", "parking"])
2×2 DataFrame
 Row │ key      values
     │ String   String
─────┼──────────────────
   1 │ parking  *
   2 │ amenity  parking
```
Note that contrary to the previous example this time we do not have meta data columns and hence we will use the `NoneMetaPOI` configuration.

Now this can be scraped as :
```
julia> df2 = find_poi(file; scrape_config=ScrapePOIConfig{NoneMetaPOI}(config))
12×7 DataFrame
 Row │ elemtype  elemid      nodeid      lat      lon       key      value
     │ Symbol    Int64       Int64       Float64  Float64   String   String
─────┼───────────────────────────────────────────────────────────────────────
   1 │ way        187565434  1982207088  42.3603  -71.0866  amenity  parking
  ⋮  │    ⋮          ⋮           ⋮          ⋮        ⋮         ⋮        ⋮
  12 │ way       1052438049  9672086211  42.3624  -71.0878  parking  surface
                                                              10 rows omitted
```
This data can be further processed in many ways. For example [here](https://pszufe.github.io/OSMToolset.jl/dev/visualize/) is a sample code that performs vizualisation

## Spatial attractiveness processing

Suppose we have the `df1` data from the previous example. Now we can do a spatial attractiveness index in the following way:
```
ix = AttractivenessSpatIndex(df1)
```
Note that the default configuration works with the `AttractivenessMetaPOI` data format. If you want a different structure of data for this index you need to crate a subtype of `MetaPOI` and use it in the constructor.

Let us consider some point on the map:
```
lat, lon = mean(df1.lat), mean(df1.lon)
```
We can use the API to calculate attractiveness of that location:
```
julia> attractiveness(ix, lat, lon)
(education = 42.73746118854219, entertainment = 30.385266049775055, healthcare = 12.491783858701343, leisure = 134.5949900134078, parking = 7.310719949554132, restaurants = 25.200347106553586, shopping = 6.89416203789267, transport = 12.090409181473555)
```
If, for the debugging purposes, we want to understand what data has been used to calculate that attractiveness use the `explain=true` parameter:
```
julia> attractiveness(ix, lat, lon ;explain=true).explanation
68×7 DataFrame
 Row │ group        influence  range    attractiveness  poidistance  lat      lon
     │ Symbol       Float64    Float64  Float64         Float64      Float64  Float64
─────┼─────────────────────────────────────────────────────────────────────────────────
   1 │ education         20.0  10000.0       16.9454       1527.31   42.3553  -71.105
  ⋮  │      ⋮           ⋮         ⋮           ⋮              ⋮          ⋮        ⋮
  68 │ shopping           5.0    500.0        0.618922      438.108  42.3625  -71.0834
                                                                        66 rows omitted
```
The attractiveness function is fully configurable on how the attractiveness is actually calculated.
The available parameters can be used to define attractiveness dimension, aggreagation function,
attractivess function and how the distance is on map is calculated.

Let us for an example take maximum influence values rather than summing them:
```
julia> att = attractiveness(ix, lat, lon, aggregator = x -> length(x)==0 ? 0 : maximum(x))
(education = 19.245381074958622, entertainment = 17.69295158791498, healthcare = 6.245891929350671, leisure = 4.723681042516024, parking = 2.9623334286775806, restaurants = 4.596901824773207, shopping = 2.0103741801865715, transport = 6.407028429850689)
```

We could also used the custom scraped `df2` for the attractiveness:
```
ix2 = AttractivenessSpatIndex{NoneMetaPOI}(df2; get_range=a->300, get_group=a->:parking);
```
Note that since we did not have metadata we have manually provided `300` meters for the range and `:parking` for the group.

Now we can use this custom scraper to query the attractiveness:
```
julia> attractiveness(ix2, lat, lon; aggregator = sum, calculate_attractiveness = (a,dist) -> dist > 300 ? 0 : 300/dist )
(parking = 13.200370032301507,)
```
Note that for this code to work we needed to provide the way the attractiveness is calculated with the respect of metadata a (now an empty `struct` as this is NoneMetaPOI).

### OSM map tiling/slicing

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
