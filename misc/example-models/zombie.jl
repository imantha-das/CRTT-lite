using Pkg
Pkg.activate("envs/abm")

using LightOSM
using InteractiveDynamics:abmplot
using CairoMakie

using Agents: @agent, OSMAgent, OSM, ABM, OpenStreetMapSpace
using Random:MersenneTwister 

"""
download_osm_network(
    :place_name;
    place_name = "Guadeloupe",
    download_format = :osm,
    save_to_file_location = "example-models"
)
"""

@agent Zombie OSMAgent begin
    infected::Bool
    speed::Float64
end

OSM.test_map()

function initialise(;seed = 1234)
    map_path = "Gudaloupe_osm_network.json"
    properties = Dict(:dt => 1/60)
    model = ABM(
        Zombie,
        OpenStreeMapSpace(map_path),
        properties = properties,
        rng = MersenneTwister(seed)
    )
end 

model = ABM(
        Zombie,
        OpenStreetMapSpace("Primaryrds_EPSG36320.geojson"),
        properties = Dict(:dt => 1234),
        rng = MersenneTwister(1234)
)

abmplot(model)

