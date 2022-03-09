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
begin
    using Pkg
    Pkg.activate(joinpath(homedir(),"workspace","julia","envs","agentsenv"))

    using Agents
    using OpenStreetMapXPlot
    using Plots
end

mutable struct Casualty <: AbstractAgent
    id::Int 
    pos::Tuple{Int,Int,Float64} #(i,j,x) --> position on the road inbetween nodes
    trauma::Int
    awaiting_rescue::Bool
    in_rescue::Bool
    in_queue::Bool
    in_stabilisation::Bool
    in_burn_beds::Bool
    in_non_burn_beds::Bool
    function Casualty(id::Int, pos::Tuple{Int,Int,Float64};trauma::Int,awaiting_rescue::Bool=true,in_rescue::Bool=false,in_queue::Bool=false,in_stabilisation::Bool=false,in_burn_beds::Bool=false, in_non_burn_beds::Bool=false)
        new(id,pos,trauma,awaiting_rescue,in_rescue,in_queue,in_stabilisation,in_burn_beds,in_non_burn_beds)
    end
end

mutable struct Rescuer <: AbstractAgent
    id::Int 
    pos::Tuple{Int,Int,Float64}
    awaiting_instructions::Bool
    rescuing_in_progress::Bool
    to_medical::Bool
    destination::Tuple{Int,Int,Float64} 
    route::Vector{Int}
    casualty_in_rescue::Casualty
    casualties_rescued::Vector{Casualty}

    function Rescuer(id::Int,pos::Tuple{Int,Int,Float64};awaiting_instructions::Bool=true,rescuing_in_progress::Bool=false,to_medical::Bool=false,destination::Tuple{Int,Int,Float64}=(0,0,0.),route::Vector{Int}=Int[],casualty_in_rescue::Casualty=Casualty(999,(0,0,0.),trauma=9),casualties_rescued::Vector{Casualty}=Casualty[])
        new(id,pos,awaiting_instructions,rescuing_in_progress,to_medical,destination,route,casualty_in_rescue,casualties_rescued)
    end
end

function initialise(;map_path=OSM.TEST_MAP,num_casualties, num_rescuers)
    model = AgentBasedModel(
        Union{Casualty, Rescuer},
        OpenStreetMapSpace(map_path),
        scheduler = Schedulers.fastest
    )
    # Add casualties to Model
    for i=1:num_casualties
        pos = random_position(model)
        casualty = Casualty(i,pos,trauma = rand([1,2,3]))
        add_agent_pos!(casualty,model)
    end
    #Add Rescuers to Model 
    for i=num_casualties + 1:num_casualties + num_rescuers
        init_pos=(775,775,0.0)
        rescuer=Rescuer(i,init_pos) 
        add_agent_pos!(rescuer,model)
    end
    return model
end

# Agent Step functions ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

# Get agent by type 
@doc "Return ids of casualties/rescuers by their boolean attributes only" ->
function agent_by_property(model::ABM, agent_type::DataType, prop::Symbol, prop_value::Bool)::Vector{Int64}
    if prop_value
        return [id for id in 1:length(model.agents) if model[id] isa agent_type && getproperty(model[id], prop)]
    else
        return [id for id in 1:length(model.agents) if model[id] isa agent_type && !getproperty(model[id], prop)]
    end
end

@doc "Finds any casualty to be rescued, needs to be converted through munkres in future" ->
function find_casualties_awaiting_rescue(model::ABM)
awaiting_instructions = agent_by_property(model,Rescuer,:awaiting_instructions,true)
    for i = 1:length(awaiting_instructions)
        # As long as there is an Causlty to be Saved : Need to Change to Munkres in future
        if !isempty(agent_by_property(model, Casualty, :awaiting_rescue,true))
            # get casualties to be rescued (id)
            casualty_to_be_rescued = agent_by_property(model, Casualty, :awaiting_rescue,true)[i]
            # get casualty destination
            destination_at = model[casualty_to_be_rescued].pos 
            # update casualties properties
            model[casualty_to_be_rescued].awaiting_rescue = false
            # update rescuer properties
            model[awaiting_instructions[i]].awaiting_instructions = false
            model[awaiting_instructions[i]].rescuing_in_progress = true
            model[awaiting_instructions[i]].casualty_in_rescue = model[casualty_to_be_rescued]
            model[awaiting_instructions[i]].destination = destination_at
        end
    end
end

 @doc "Move towards destination" ->
 function rescuer_step!(model,distance_traveled)
    rescue_in_progress = agent_by_property(model,Rescuer,:rescuing_in_progress,true)
    for r_id in rescue_in_progress
        r = model[r_id]
        route = OSM.plan_route(r.pos,r.destination,model)
        r.route = route 
        move_along_route!(r,model, distance_traveled)
        if 
    end
 end

model = initialise(num_casualties=50,num_rescuers=5)
find_casualties_awaiting_rescue(model)


r5 = model[55]
route =OSM.plan_route(r5.pos,r5.destination,model)
r5.route = route
move_along_route!(r5,model,25)
is_stationary(r5,model)

# Main Stepping function
function agent_step!(model::AgentBasedModel)
    # Locate casualties to rescue 
    find_casualties_awaiting_rescue(model)
    # Rescuers take a Step
    rescuer_step!(model,25)
end


# Visualization functions !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
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
    colors = [agent_color(model[id]) for id in ids]
    markers = [typeof(model[id]) == Casualty ? :circle : :square for id in ids]
    pos = [OSM.map_coordinates(model[i], model) for i in ids]
    plotmap(model.space.m)
    scatter!(
        pos;
        markercolor = colors,
        markershapes = markers,
        label = ""
    )
end

# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


model = initialise(num_casualties = 25, num_rescuers = 5)
plot_agents(model)
frames = @animate for i = 0:200
    i > 0 && agent_step!(model)
    plot_agents(model)
end

gif(frames)

# ----------------------------------------------------------------------------------




