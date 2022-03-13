# Visualization functions !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
function agent_color(agent::Union{Casualty,Rescuer,PMA})
    if agent isa Rescuer
        return :green
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

function plot_agents(model)
    ids = model.scheduler(model)
    colors = [agent_color(model[id]) for id in ids]
    #markers = [typeof(model[id]) == Casualty ? :circle : :square for id in ids]
    markers = Symbol[]
    for id in ids
        if model[id] isa Casualty
            push!(markers, :circle)
        elseif model[id] isa Rescuer
            push!(markers, :square)
        else
            push!(markers, :square)
        end
    end

    pos = [OSM.map_coordinates(model[i], model) for i in ids]
    plotmap(model.space.m)
    scatter!(
        pos;
        markercolor = colors,
        markershapes = markers,
        label = ""
    )
end