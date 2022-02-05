#=
Author : Imantha
Date Created : 05.02.2022
Original Model : Developed by the Volcanic Hazard Risk Group @ Earth Observatory of Singapore

Desc : Work in progress of the implementation of CRTT Model in Julia agents.jl package at smaller scale.

Types of Agents
    - Casualty
    - Rescuer 
    - Medical : Both Stabilisation & Treatment operations
=#

using Pkg
Pkg.activate(joinpath(homedir(),"workspace","julia","envs","agentsenv"))

using Agents
using OpenStreetMapXPlot
using Plots

mutable struct Casualty <: AbstractAgent
    id::Int 
    pos::Tuple{Int,Int,Float64} #(i,j,x) --> position on the road inbetween nodes
    trauma::Int
    await_rescue::Bool
    in_ambulance::Bool
    in_queue::Bool
    in_stabilisation::Bool
    in_burn_beds::Bool
    in_non_burn_beds::Bool
end

mutable struct Rescuer <: AbstractAgent
    id::Int 
    pos::Tuple{Int,Int,Float64}
    mode::String
    destination::Tuple{Int,Int,Float64}
    casualty_rescued::Vector{Casualty}
end

function initialise(; map_path = OSM.TEST_MAP, num_casualty, num_rescuer)
    model = AgentBasedModel(
        Union{Casualty, Rescuer},
        OpenStreetMapSpace(map_path)
    )

    # Add casualties into model
    for  id = 1:num_casualty
        pos = random_position(model)
        casualty = Casualty(id, pos, rand([1,2,3]), true, false, false, false, false, false)
        add_agent_pos!(casualty, model)
    end

    # Add rescuers into model
    for id = num_casualty:(num_casualty + num_rescuer)
        init_pos = (775, 775, 0.0)
        rescuer = Rescuer(id, init_pos, "inactive", Array{Casualty}([]))
        add_agent_pos!(rescuer, model)
    end

    return model
end

# Visualization functions ----------------------------------------------------------
function agent_color(agent::Union{Casualty,Rescuer})
    if typeof(agent) == Rescuer
        return :green
    elseif agent.trauma == 3 && typeof(agent) == Casualty
        return :red
    elseif agent.trauma == 2 && typeof(agent) == Casualty
        return :orange 
    elseif agent.trauma == 1 && typeof(agent) == Casualty
        return :yellow
    end
end

function plot_agents(model)
    ids = model.scheduler(model)
    colors = [agent_color(m[id]) for id in ids]
    markers = [typeof(m[id]) == Casualty ? :circle : :square for id in ids]
    pos = [OSM.map_coordinates(model[i], model) for i in ids]
    plotmap(model.space.m)
    scatter!(
        pos;
        markercolor = colors,
        markershapes = markers,
        label = ""
    )
end

# -----------------------------------------------------------------------------------

function main()
    model = initialise(num_casualty = 25, num_rescuer = 5)
    plot_agents(model)
end

# Main Function Call
main()

