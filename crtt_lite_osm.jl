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
    using ProgressBars: ProgressBar
end

begin
    include("AgentTypes.jl")
    include("VisAgents.jl")
end

function initialise(;map_path=OSM.TEST_MAP,num_casualties, num_rescuers, num_medical)
    model = AgentBasedModel(
        Union{Casualty, Rescuer,PMA},
        OpenStreetMapSpace(map_path),
        scheduler = Schedulers.fastest;
        properties = Dict(:ticks => 0, :dist_per_step => 50)
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
        :casualty_in_rescue => casualty_to_be_rescued.id, 
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


function go!(model::AgentBasedModel)
    # Initiate rescue
    #find_casualties_awaiting_rescue(model)
    # Iterate through all agents
    for (id,agent) in model.agents

        # Rescuers : awaiting_instructions
        if (agent isa Rescuer) && (agent.awaiting_instructions)
            find_casualties!(agent,model)
        end

        # Rescuers : rescue_in_progress
        if (agent isa Rescuer) && (agent.rescuing_in_progress)
            agent_travel!(agent,model)
            if is_stationary(agent,model)
                # Update rescuer attributes
                rescuer_attributes = Dict(:rescuing_in_progress => false, :to_medical => true)
                update_agent_attributes!(agent, rescuer_attributes)
                # Update casualty under rescue attributes
                casualty_attributes = Dict(:awaiting_rescue => false, :in_rescue => true)
                cas_agent = model[agent.casualty_in_rescue]
                update_agent_attributes!(cas_agent, casualty_attributes)
            end
        end

        # Rescuers : to_medical
        if (agent isa Rescuer) && (agent.to_medical)
            rand_pma = filter(x -> x isa PMA, collect(values(model.agents))) |> rand
            agent.destination = rand_pma.pos 
            agent_travel!(agent,model)
            if is_stationary(agent,model)
                
            end
        end

        # Casualties --> PMA
        if (agent isa Casualty) && (agent.in_rescue)
            pma_dst = model[agent.rescued_by].destination
            agent.destination = pma_dst
            agent_travel!(agent,model)
            if is_stationary(agent,model)

            end

        end
    end
end


# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


model = initialise(num_casualties = 5, num_rescuers = 1, num_medical=1)


frames = @animate for i = ProgressBar(0:200)
    i > 0 && go!(model)
    model.ticks += 1
    plot_agents(model)
end

gif(frames)

# ----------------------------------------------------------------------------------

