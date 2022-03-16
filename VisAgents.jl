# Visualization functions !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
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