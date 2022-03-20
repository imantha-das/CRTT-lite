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
    using InteractiveDynamics
    using OpenStreetMapXPlot
    using Plots
    using ProgressBars: ProgressBar
end

begin
    include("agent_types.jl")
    include("vis_agents.jl")
    using .Agent_Types: Casualty, Rescuer, PMA
    using .Vis_Agents: plot_agents
    using .Model_plots: plot_queue
end

function initialise(;map_path=OSM.TEST_MAP,num_casualties, num_rescuers, num_medical, properties)
    model = AgentBasedModel(
        Union{Casualty, Rescuer,PMA},
        OpenStreetMapSpace(map_path),
        scheduler = Schedulers.fastest;
        properties = properties
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

    for i=(num_casualties + num_rescuers + 1):(num_casualties + num_rescuers + num_medical)
        init_pos=(775,775,0.0)
        pma = PMA(i, init_pos)
        add_agent_pos!(pma,model)
    end
    return model
end

# Agent Step functions ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

# Filters agents by type + attributes
@doc "Return casualties/rescuers by their boolean attributes only" ->
function agent_by_property(model::ABM, agent_type::DataType, prop::Symbol, prop_value::Bool)::Union{Vector{Casualty}, Vector{Rescuer}}
    if prop_value
        return [model[id] for id in 1:length(model.agents) if model[id] isa agent_type && getproperty(model[id], prop)]
    else
        return [model[id] for id in 1:length(model.agents) if model[id] isa agent_type && !getproperty(model[id], prop)]
    end
end

# Updating agent attributes
@doc "Update agent attributes" ->
function update_agent_attributes!(agent::Union{Casualty,Rescuer},attr::Dict{Symbol,T}) where T <: Any
    for (k,v) in attr
        setfield!(agent,k,v)
    end 
end

# Assigns casualties to each rescuer "awaiting instructions"
@doc "Rescuers : awaiting_instructions, locate casualties" ->
function find_casualties!(agent,model)
    # Locate a random casualty who is awaiting rescue
    casualty_to_be_rescued = agent_by_property(model, Casualty, :awaiting_rescue, true) |> rand
    # Update rescuer attributes
    rescuer_attributes = Dict(
        :travel_to => casualty_to_be_rescued.id, 
        :destination => casualty_to_be_rescued.pos,
        :awaiting_instructions => false,
        :rescuing_in_progress => true
    )
    update_agent_attributes!(agent, rescuer_attributes)
    # update casualty attributes
    casualty_to_be_rescued_attributes = Dict(
        :awaiting_rescue => false,
        :rescued_by => agent.id
    )
    update_agent_attributes!(casualty_to_be_rescued, casualty_to_be_rescued_attributes)
end


@doc "Move rescuer to destination" ->
function agent_travel!(agent,model)
    route = OSM.plan_route(agent.pos,agent.destination,model)
    agent.route = route 
    move_along_route!(agent,model,model.dist_per_step)
end

@doc "Step Model" ->
function model_step!(model; stab_open = [60,180], stab_cap = [10,30])
    # update model  ticks
    model.ticks += 1
    # Update stabilisation capacity
    if model.ticks >= stab_open[1] && model.ticks < stab_open[2]
        model.stab_cap = stab_cap[1]
    elseif model.ticks >= stab_open[2]
        model.stab_cap = stab_cap[2]
    else 
        model.stab_cap = 0
    end
end

@doc "PMA : Move from queue to stabilisation"
function queue_to_stabilisation(model,agent)
    while (length(agent.stabilisation) < model.stab_cap) && (length(agent.queue) > 0)
        push!(agent.stabilisation, (agent.queue[1][1], model.ticks))
        popfirst!(agent.queue)
    end
end


function go!(model::AgentBasedModel)
    # Initiate rescue
    #find_casualties_awaiting_rescue(model)
    # Iterate through all agents
    for (id,agent) in model.agents
        # Are there any casualties to be rescued
        any_to_be_rescued = filter(x -> x isa Casualty && x.awaiting_rescue == true, model.agents |> values |> collect)
        # Rescuers : awaiting_instructions --> find_casualties
        if (agent isa Rescuer) && (agent.awaiting_instructions) && length(any_to_be_rescued) > 0
            find_casualties!(agent,model)
        end

        # Rescuers : rescue_in_progress --> in_rescue
        if (agent isa Rescuer) && (agent.rescuing_in_progress)
            agent_travel!(agent,model)
            if is_stationary(agent,model)
                # Update rescuer attributes
                rescuer_attributes = Dict(:rescuing_in_progress => false, :to_medical => true)
                update_agent_attributes!(agent, rescuer_attributes)
                # Update casualty under rescue attributes
                casualty_attributes = Dict(:awaiting_rescue => false, :in_rescue => true)
                cas_agent = model[agent.travel_to]
                update_agent_attributes!(cas_agent, casualty_attributes)
            end
        end

        # Rescuers : to_medical --> awaiting_instructions (cycle)
        if (agent isa Rescuer) && (agent.to_medical)
            # Selects PMA to travel to
            rand_pma = filter(x -> x isa PMA, collect(values(model.agents))) |> rand
            rescuer_attributes = Dict(:destination => rand_pma.pos, :travel_to => rand_pma.id)
            update_agent_attributes!(agent, rescuer_attributes)
            agent_travel!(agent,model)
            if is_stationary(agent,model)
                rescuer_attributes = Dict(:to_medical => false, :awaiting_instructions => true)
                update_agent_attributes!(agent, rescuer_attributes)
            end
        end

        # Casualties : in_rescue --> in_pma_queue
        if (agent isa Casualty) && (agent.in_rescue)
            casualty_attributes = Dict(
                :at_pma => model[agent.rescued_by].travel_to,
                :destination => model[agent.rescued_by].pos
            )
            update_agent_attributes!(agent, casualty_attributes)
            agent_travel!(agent,model)
            final_destination = model[agent.rescued_by].destination # location of pma
            if agent.pos == final_destination
                casualty_attributes = Dict(:in_rescue => false, :in_pma_queue => true)
                update_agent_attributes!(agent, casualty_attributes)
                push!(model[agent.at_pma].queue, (agent.id, model.ticks)) #add casualty into PMA's queue
            end
        end

        if (agent isa PMA)
            queue_to_stabilisation(model,agent)
            @show agent.queue 
            @show agent.stabilisation
        end
    end
end


# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


properties = Dict(:ticks => 0, :dist_per_step => 50, :stab_cap => NaN, :stab_time => 20)
model = initialise(num_casualties = 25, num_rescuers = 10, num_medical=1, properties = properties)


frames = @animate for i = ProgressBar(0:200)
    i > 0 && go!(model)
    model_step!(model,stab_open=[60,180],stab_cap=[10,30])
    plot_agents(model)
end

gif(frames)

# ----------------------------------------------------------------------------------


