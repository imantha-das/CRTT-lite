# ------------------------------------------------------------------------------
# Notes
# - Resc agent in VX PMA gets first priority to select casualties as they are closer
# - Rescuers travel some defined distance from PMA to impact zone plus the 2 times the distance to the casualty. 
#   - Its 2 time since we make the assumption that rescuers travel to central point in the impact zone and then go the distance 
#     from there to the casualty and back before making the next decision.
# ------------------------------------------------------------------------------
begin
    using Pkg
    Pkg.activate("envs/crttenv")
end

#using Agents:AbstractAgent

begin
    include("crtt_agents.jl")
    include("utils.jl")
    using .CrttAgents: Cas, Resc
    using Agents: ABM, Schedulers, add_agent!, nextid
    using .Utils: initialise
    using PlotlyJS: scatter, Layout, plot, show, PlotlyBase, attr
end
 

# @doc "Returns rescuers who are at a specific pma waiting for rescuing process" ->
# get_at_pma(model::ABM, pma_name::String)::Vector{Int64} = [
#     k for (k,v) in model.agents if (v isa Resc) && (v.at_pma == true) && (v.which_pma == pma_name)
# ]

@doc "Returns casualties who are the closest to the impact zone" ->
function get_awaiting_rescue(model::ABM)::Vector{Int}
    cas_awaiting_rescue_1::Vector{Tuple} = [(k, v.dist_from_iz) for (k,v) in model.agents if (v isa Cas) && (v.awaiting_rescue == true) && (v.ts == 1)]
    cas_awaiting_rescue_23::Vector{Tuple} = [(k, v.dist_from_iz) for (k,v) in model.agents if (v isa Cas) && (v.awaiting_rescue == true) && ((v.ts == 2) || (v.ts == 3))] 
    
    if length(cas_awaiting_rescue_23) > 0
        return [i[1] for i in sort(cas_awaiting_rescue_23, by = x -> x[2])]
    else 
        return [i[1] for i in sort(cas_awaiting_rescue_1, by = x -> x[2])]
    end
end

@doc """
Returns rescuers by property. Works for 
    :on_way_to_iz
    :at_iz
"""->
get_resc_by_prop(model::ABM, criteria::Symbol)::Vector{Int64} = [k for (k,v) in model.agents if (v isa Resc) && (getproperty(v,criteria) == true)]

@doc """
Updates casualty attributes. Used in occasions where one attribute requires to be set false
while other set is to true
"""
function update_cas_attr(casualty_ids::Array{Int64};inactive_attr::Symbol,active_attr::Symbol)
    for cas_id in casualty_ids
        if model[cas_id].is_deceased == false 
            setfield!(model[cas_id],inactive_attr,false) 
            setfield!(model[cas_id],active_attr,true)
        end
    end
end

# ==============================================================================
# At Venue update functions
# ==============================================================================

@doc """
At PMA
    + Updates location trajectory
    + Dump casualties into Pma, pre-stabilization-q
    + Decide to travel to IZ or Hospital
""" ->
function update_agents_at_pma(model::ABM)
    for resc_id in get_resc_by_prop(model,:at_pma)
        # Dump "rescued" casualties into pre stabilization queue
        if model[resc_id].which_pma == "VX"
            push!(model[resc_id].loc_traject, "at_VX") #update location trajectory
            push!(model.pre_stabilize_q_vx, model[resc_id].rescued...) #add rescued agents to pre_stabilization_q_vx
        else
            push!(model[resc_id].loc_traject, "at_SM") # update location trajectory
            push!(model.pre_stabilize_q_sm, model[resc_id].rescued...) # add rescude agents to pre_stabilization_q_sm
        end
        # Takes a decision to go either go to IZ or hospital
        decide_next_step!(model, resc_id)
    end
end


@doc """
At IZ
    + Updates location trajectory
    + Decides between PMA or Cas
"""->
function update_agents_at_iz(model)
    for resc_id in get_resc_by_prop(model, :at_iz)
        # Selects between on way to pma and on way to cas
        push!(model[resc_id].loc_traject, "at_iz")
        decide_next_step!(model,resc_id)
    end
end

@doc """
At Cas
    + Updates location trajectory
    + Updates rescued casualties by rescuer
    + Decides to go to IZ (deterministic)
""" ->
function update_agents_at_cas(model)
    for resc_id in get_resc_by_prop(model, :at_cas)
        # Go back to IZ 
        push!(model[resc_id].loc_traject, "at_cas")
        push!(model[resc_id].rescued, model[resc_id].cas_in_rescue) #note the agent is being pushed in to rescued list at IZ point but should be 
        model[resc_id].cas_in_rescue = 999
        decide_next_step!(model, resc_id) #Updates from, :at_cas -> 
    end 
end

# ------------------------------------------------------------------------------
# Function to make agents travel to IZ, PMA, 
# ------------------------------------------------------------------------------

@doc """
Allows rescuers with attributes :on_way_to_iz, :on_way_to_cas, :on_way_to_pma take
a step toward their target
+ Keeps track of distances at each step
+ Updates distance at each step
+ Keeps track of trajectory for on_way_to_{} attributes (at_{} attributes are updated in their respective funcs)
+ Initializes distance to zero upon reaching destination
"""->
function travel_to_loc(model)
    # Rescuers travel from  PMA to IZ
    for resc_id in get_resc_by_prop(model, :on_way_to_iz)
        push!(model[resc_id].dist_traject, model[resc_id].dist_to_agent) #keep track of the distances
        model[resc_id].dist_to_agent -= model.dist_per_step #update the distance to IZ at each step
        push!(model[resc_id].loc_traject, "on_way_to_iz") #update location trajectory

        if model[resc_id].dist_to_agent < 0 # you are at IZ
            model[resc_id].on_way_to_iz = false 
            model[resc_id].at_iz = true
            model[resc_id].dist_to_agent = 0
        end
    end

    # Rescuers traveling from IZ to Cas 
    for resc_id in get_resc_by_prop(model, :on_way_to_cas)
        push!(model[resc_id].dist_traject, model[resc_id].dist_to_agent) # keep track of distances
        model[resc_id].dist_to_agent -= model.dist_per_step # update distance to Cas at each step
        push!(model[resc_id].loc_traject, "on_way_to_cas")

        if model[resc_id].dist_to_agent < 0
            model[resc_id].on_way_to_cas = false 
            model[resc_id].at_cas = true 
            model[resc_id].dist_to_agent = 0
        end 
    end

    # Rescuers travel from IZ to Pma
    for resc_id in get_resc_by_prop(model, :on_way_to_pma)
        push!(model[resc_id].dist_traject, model[resc_id].dist_to_agent) #keep track of the distances
        model[resc_id].dist_to_agent -= model.dist_per_step
        push!(model[resc_id].loc_traject, "to_$(model[resc_id].which_pma)")

        if model[resc_id].dist_to_agent < 0
            model[resc_id].on_way_to_pma = false 
            model[resc_id].at_pma = true
            model[resc_id].dist_to_agent = 0
        end
    end

end

# ==============================================================================
# Functio to Make Choice
# ==============================================================================
@doc "Decision point on what to do" -> 
function decide_next_step!(model,resc_id)
    #todo next_step at PMA needs implementation
    # ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    # Decision between IZ or hosp at PMA
    if model[resc_id].at_pma == true
        # A ticks = 0, we need to account for the rescuers to make unanamous choice to go to IZ 
        if model.ticks == 0
            model[resc_id].at_pma = false 
            model[resc_id].on_way_to_iz = true
            if model[resc_id].which_pma == "VX"
                model[resc_id].dist_to_agent = model.dist_vx_iz #Update distabce from VX to IZ
            elseif model[resc_id].which_pma == "SM"
                model[resc_id].dist_to_agent = model.dist_sm_iz #Update distance_from SM to IZ
            else
                printstyled("1. Got something other than VX or SM for which_pma")
            end
        # Every other time an rescuer arrives at pma
        else
            model[resc_id].at_pma = false
            # Go to hospital if there are post_stab_cap has exceeded
            if (model[resc_id].which_pma == "VX") && (length(model.post_stabilize_q_vx) > model.post_stab_cap)
                model[resc_id].on_way_to_hosp = true
                model[resc_id].dist_to_agent = model.dist_vx_hosp
            elseif (model[resc_id].which_pma == "SM") && (length(model.post_stabilize_q_sm) > model.post_stab_cap)
                model[resc_id].on_way_to_hosp = true
                model[resc_id].dist_to_agent = model.dist_vx_hosp
            # Go to IZ since the post_stab_cap has not exceeded
            elseif (model[resc_id].which_pma == "VX") && (length(model.post_stabilize_q_vx) < model.post_stab_cap)
                model[resc_id].on_way_to_iz = true
                model[resc_id].dist_to_agent = model.dist_vx_iz
            elseif (model[resc_id].which_pma == "SM") && (length(model.post_stabilize_q_sm) < model.post_stab_cap)
                model[resc_id].on_way_to_iz = true
                model[resc_id].dist_to_agent = model.dist_sm_iz
            else
                printstyled("Rescuer found no actions to take at PMA", color = "red")
            end 
        end
    end

    # +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    # Decision between IZ or On way to Pma 
    if model[resc_id].at_iz == true
        # Decision between PMA and IZ at IZ(for Decision between VX amd SM see below)
        if length(model[resc_id].rescued) < model.resc_cap
            # Rescuer at IZ, and decided to go rescue 
            # update rescuer attributes
            model[resc_id].at_iz = false
            model[resc_id].on_way_to_cas = true

            # Select closest casualty and update distance
            closest_cas_id = get_awaiting_rescue(model)[1]
            model[resc_id].cas_in_rescue = closest_cas_id
            model[resc_id].dist_to_agent = model[closest_cas_id].dist_from_iz
            
            # Update casualty attributes
            model[closest_cas_id].awaiting_rescue = false
            model[closest_cas_id].in_rescue = true
            model[closest_cas_id].rescued_by = resc_id
        else
            # Rescuer at IZ and decided to travel to pma
            # Update rescuer attributes
            model[resc_id].at_iz = false 
            model[resc_id].on_way_to_pma = true

            # Update casualty attributes
            rescued_casualties = model[resc_id].rescued 
            update_cas_attr(rescued_casualties, inactive_attr = :in_rescue, active_attr = :on_way_to_pma)
            
        end
    end

    # +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    # Decision to be made once arriving at casualty
    if model[resc_id].at_cas == true
        model[resc_id].at_cas = false 
        model[resc_id].on_way_to_iz = true
        cas_just_rescued_id = model[resc_id].rescued[end]
        model[resc_id].dist_to_agent = model[cas_just_rescued_id].dist_from_iz
    end

    # ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    # Decision between VX or SM at IZ 
    if model[resc_id].on_way_to_pma == true
        # Go to pma as you may want to transfer casualties to hospital. VX is given priority over SM as its close
        if length(model.post_stabilize_q_vx) > length(model.post_stab_cap)
            model[resc_id].which_pma = "VX"
            model[resc_id].dist_to_agent = model.dist_vx_iz
        elseif length(model.post_stabilize_q_sm) > length(model.post_stab_cap)
            model[resc_id].which_pma = "SM"
            model[resc_id].dist_to_agent = model.dist_sm_iz
        # Travel to PMA with the lower queue length. If equal, VX is given priority
        elseif length(model.pre_stabilize_q_vx) < length(model.pre_stabilize_q_sm)
            model[resc_id].which_pma = "VX" 
            model[resc_id].dist_to_agent = model.dist_vx_iz 
        elseif length(model.pre_stabilize_q_sm) < length(model.pre_stabilize_q_vx)
            model[resc_id].which_pma = "SM" 
            model[resc_id].dist_to_agent = model.dist_sm_iz
        else
            model[resc_id].which_pma = "VX"
            model[resc_id].dist_to_agent = model.dist_vx_iz 
        end
    end

end




# ==============================================================================
# Main Run
# ==============================================================================

begin 
    properties = Dict(
        :ticks => 0,
        :dist_vx_iz => 10000, #10 km
        :dist_sm_iz => 20000, #20 km
        :dist_vx_hosp => 40000, #40km
        :dist_sm_hosp => 30000, #30km
        :dist_per_step => 30000 / 60, # 30km/60
        :resc_cap => 2,
        :stablize_cap => 5,
        :post_stab_cap => 3, #to be taken to hosp if above this value
        :burn_bed_cap => 5,
        :non_burn_bed_cap => 10,
        :pre_stabilize_q_vx => Int[],
        :in_stablize_q_vx => Int[],
        :post_stabilize_q_vx => Int[],
        :pre_stabilize_q_sm => Int[],
        :in_stabalize_q_sm => Int[],
        :post_stabilize_q_sm => Int[],
        :pre_treatment_q_hosp => Int[],
        :in_burn_beds => Int[],
        :in_non_burn_beds => Int[],
    )

    # Initialise
    model = initialise(6, 3, properties)
end

for tick = 1:100
    # Initialise model with agents
    update_agents_at_pma(model)
    update_agents_at_iz(model)
    update_agents_at_cas(model)

    travel_to_loc(model)
    

    model.ticks += 1
end

function plot_rescuer_trajectories(model)
    rescuers = [id for (id,agent) in model.agents if agent isa Resc]
    traces = PlotlyBase.GenericTrace[]
    for i in rescuers
        trajectory = model[i].loc_traject
        trace = scatter(
            x = 1:length(trajectory),
            y = trajectory,
            mode = "lines",
            line = attr(shape = "hv"),
            name = "rescuer $(i)"
        )
        push!(traces,trace)
    end
    layout = Layout(title = "Rescuer Trajectory", xaxis_title = "ticks", yaxis_title = "status", width = 900, height = 500, template = "plotly_white")
    return plot(traces, layout)
end

p = plot_rescuer_trajectories(model)

PlotlyBase.GenericTrace[]