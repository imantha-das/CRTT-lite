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

# Get agent by type 
@doc "Return ids of casualties/rescuers by their boolean attributes only" ->
function agent_by_property(model::ABM, agent_type::DataType, prop::Symbol, prop_value::Bool)::Vector{Int64}
    if prop_value
        return [id for id in 1:length(model.agents) if model[id] isa agent_type && getproperty(model[id], prop)]
    else
        return [id for id in 1:length(model.agents) if model[id] isa agent_type && !getproperty(model[id], prop)]
    end
end

# Get 
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
            model[casualty_to_be_rescued].rescued_by = model[awaiting_instructions[i]].id
            # update rescuer properties
            model[awaiting_instructions[i]].awaiting_instructions = false
            model[awaiting_instructions[i]].rescuing_in_progress = true
            model[awaiting_instructions[i]].casualty_in_rescue = casualty_to_be_rescued
            model[awaiting_instructions[i]].destination = destination_at
        end
    end
end

 
@doc "Move rescuer to destination" ->
function agent_step!(agent)
    route = OSM.plan_route(agent.pos,agent.destination,model)
    agent.route = route 
    move_along_route!(agent,model,model.dist_per_step)
end

function go!(model::AgentBasedModel)
    # Initiate rescue
    find_casualties_awaiting_rescue(model)
    # Iterate through all agents
    for (id,agent) in model.agents
        # Rescuers --> rescue_in_progress
        if (agent isa Rescuer) && (agent.rescuing_in_progress)
            agent_step!(agent)
            if is_stationary(agent,model)
                # Update rescuer attributes
                agent.rescuing_in_progress = false
                agent.to_medical = true
                # Update casualty under rescue attributes
                cas_agent = model[agent.casualty_in_rescue]
                cas_agent.awaiting_rescue = false
                cas_agent.in_rescue = true

            end
        end

        # Rescuers --> to_medical
        if (agent isa Rescuer) && (agent.to_medical)
            rand_pma = filter(x -> x isa PMA, collect(values(model.agents))) |> rand
            agent.destination = rand_pma.pos 
            agent_step!(agent)
            if is_stationary(agent,model)
                
            end
        end

        # Casualties --> PMA
        if (agent isa Casualty) && (agent.in_rescue)
            pma_dst = model[agent.rescued_by].destination
            agent.destination = pma_dst
            agent_step!(agent)
            if is_stationary(agent,model)

            end
        end
    end
end


# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


model = initialise(num_casualties = 100, num_rescuers = 20, num_medical=2)


frames = @animate for i = ProgressBar(0:200)
    i > 0 && go!(model)
    model.ticks += 1
    plot_agents(model)
end

gif(frames)

# ----------------------------------------------------------------------------------

