# Visualization functions !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
module Vis_Agents

using Agents: OSM
using OpenStreetMapXPlot: plotmap
using Plots: scatter!

using ..Agent_Types: Casualty, Rescuer, PMA
export plot_agents

function agent_color(agent::Union{Casualty,Rescuer,PMA})
    if agent isa Rescuer
        return :blue
    elseif agent isa PMA
        return :violet
    elseif agent.trauma == 3 && agent isa Casualty
        return :red
    elseif agent.trauma == 2 && agent isa Casualty
        return :orange 
    elseif agent.trauma == 1 && agent isa Casualty
        return :yellow
    end
end

function agent_size(agent::Union{Casualty,Rescuer,PMA})
    if agent isa Rescuer
        return 6
    elseif agent isa Casualty
        return 5
    elseif agent isa PMA
        return 8
    else
        @show agent
    end 
end

function agent_markers(agent::Union{Casualty,Rescuer,PMA})
    if agent isa Casualty
        return :circle
    elseif agent isa Rescuer
        return :circle
    elseif agent isa PMA
        return :square
    end
end

function plot_agents(model)
    ids = model.scheduler(model)
    colors = [agent_color(model[id]) for id in ids]
    sizes = [agent_size(model[id]) for id in ids]
    markers = [agent_markers(model[id]) for id in ids]
    
    pos = [OSM.map_coordinates(model[i], model) for i in ids]
    plotmap(model.space.m)
    scatter!(
        pos;
        markercolor = colors,
        markersize = sizes,
        markershapes = markers,
        label = ""
    )
end
end

module Model_plots
using ..Agent_Types: Casualty, Rescuer, PMA
using Plots

function plot_queue(model)
    pma_vec = filter(x -> x isa PMA, model.agents |> values |> collect)
    p_vec = []
    for i in 1:length(pma_vec)
        pma = pma_vec[i]
        queue_increment_points = [x[2] for x in pma.queue]
        x = 1:model.ticks |> collect
        y = [x in queue_increment_points ? 1 : 0 for x = 1:model.ticks] |> cumsum
        p = plot(x,y, series_type = :line, xlabel = "ticks", ylabel = "queue")
        push!(p_vec, p)
    end
    plot(p_vec...)
end

end

