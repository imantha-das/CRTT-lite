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
    using GLMakie: lines!, Figure, Axis, lines
    using Plots
    using DrWatson: @dict
end
 

# @doc "Returns rescuers who are at a specific pma waiting for rescuing process" ->
# get_at_pma(model::ABM, pma_name::String)::Vector{Int64} = [
#     k for (k,v) in model.agents if (v isa Resc) && (v.at_pma == true) && (v.which_pma == pma_name)
# ]

@doc """
Returns casualties who are the closest to the impact zone, Returns casualties who are TS = 2 or 3 initially upon all rescure returns TS1
Filter conditions
    + Cas = True 
    + awaiting_rescue == true 
    + ts = 2 or 3 at first later ts = 1
    + is_deceased == false
""" ->
function get_awaiting_rescue(model::ABM)::Vector{Int}
    cas_awaiting_rescue_1::Vector{Tuple} = [(k, v.dist_from_iz) for (k,v) in model.agents if (v isa Cas) && (v.awaiting_rescue == true) && (v.ts == 1) && (v.is_deceased == false)]
    cas_awaiting_rescue_23::Vector{Tuple} = [(k, v.dist_from_iz) for (k,v) in model.agents if (v isa Cas) && (v.awaiting_rescue == true) && ((v.ts == 2) || (v.ts == 3)) && v.is_deceased == false] 
    
    if length(cas_awaiting_rescue_23) > 0
        return [i[1] for i in sort(cas_awaiting_rescue_23, by = x -> x[2])]
    else 
        return [i[1] for i in sort(cas_awaiting_rescue_1, by = x -> x[2])]
    end
end

@doc """
Returns rescuers by property. Works only for 2 filter conditions, 1st must v
Filters rescuers with a single criteria
"""->
get_resc_by_prop(model::ABM, criteria::Symbol)::Vector{Int64} = [k for (k,v) in model.agents if (v isa Resc) && (getproperty(v,criteria) == true)]

@doc """
Updates casualty attributes. Used in occasions where one attribute requires to be set false while otherneeds to be set to true
"""
function update_cas_attr!(casualty_ids::Array{Int64};inactive_attr::Symbol,active_attr::Symbol)
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
    + Dump casualties into Pma, pre_stabilize_q
        + Rescues to empty rescued casualties (:rescued -> [])
        + update casulity attributes (:on_way_to_pma -> :pre_stabilize_q)
    + Decide to travel to IZ or Hospital
""" ->
function update_rescuers_at_pma(model::ABM)
    for resc_id in get_resc_by_prop(model,:at_pma)
        # Dump "rescued" casualties into pre stabilization queue in VX
        if model[resc_id].which_pma == "VX"
            push!(model[resc_id].loc_traject, "at_VX") #update location trajectory
            push!(model.pre_stabilize_q_vx, model[resc_id].rescued...) #add rescued agents to pre_stabilization_q_vx
            update_cas_attr!(model[resc_id].rescued, inactive_attr = :on_way_to_pma, active_attr = :pre_stabilize_q) #Update casuality attributes
            model[resc_id].rescued = [] #cleanup rescued agent list

        # Dump "rescued" casualties into pre stabilization queue in SM
        else
            push!(model[resc_id].loc_traject, "at_SM") # update location trajectory
            push!(model.pre_stabilize_q_sm, model[resc_id].rescued...) # add rescude agents to pre_stabilization_q_sm

            update_cas_attr!(model[resc_id].rescued, inactive_attr = :on_way_to_pma, active_attr = :pre_stabilize_q) # Update casualty attributes
            model[resc_id].rescued = [] # cleanup rescued agent list
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
function update_rescuers_at_iz(model)
    for resc_id in get_resc_by_prop(model, :at_iz)
        # Selects between on way to pma and on way to cas
        push!(model[resc_id].loc_traject, "at_iz")
        decide_next_step!(model,resc_id)
    end
end

@doc """
At Cas
    + Updates location trajectory
    + Checks if casualiy is desceased
        + Updates rescued casualties by rescuer
    + Decides to go to IZ (deterministic)
""" ->
function update_rescuers_at_cas(model)
    for resc_id in get_resc_by_prop(model, :at_cas)
        # Updates location trajectory
        push!(model[resc_id].loc_traject, "at_cas")
        if model[model[resc_id].cas_in_rescue].is_deceased == false #only add casualty into rescued list if not deceased
            push!(model[resc_id].rescued, model[resc_id].cas_in_rescue) #note the agent is being pushed in to rescued list at IZ point but should be 
        end
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
@doc """Decision point on what to do
Decisions
    + at_pma
        + (@ticks = 0) -> on_way_to_iz
        + (post_stab_cap reached) -> on_way_to_hosp
        + (post_stab_cap NOT reached) -> on_way_to_IZ 
        + (post_sta_cap NOT reached but no cas in IZ)
""" -> 
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
            is_awaiting_rescue = get_awaiting_rescue(model) # Are there any casualties awaiting rescue

            # Priority 1 : post_stab_cap has exceeded -> go to hosp
            if (model[resc_id].which_pma == "VX") && (length(model.post_stabilize_q_vx) > model.post_stab_cap)
                model[resc_id].on_way_to_hosp = true
                model[resc_id].dist_to_agent = model.dist_vx_hosp
            elseif (model[resc_id].which_pma == "SM") && (length(model.post_stabilize_q_sm) > model.post_stab_cap)
                model[resc_id].on_way_to_hosp = true
                model[resc_id].dist_to_agent = model.dist_sm_hosp
            # Priority 2 : post_stab_cap has not exceeded -> go to IZ
            elseif (model[resc_id].which_pma == "VX") && (length(model.post_stabilize_q_vx) < model.post_stab_cap) && (length(is_awaiting_rescue) > 0)
                model[resc_id].on_way_to_iz = true
                model[resc_id].dist_to_agent = model.dist_vx_iz
            elseif (model[resc_id].which_pma == "SM") && (length(model.post_stabilize_q_sm) < model.post_stab_cap) && (length(is_awaiting_rescue) > 0)
                model[resc_id].on_way_to_iz = true
                model[resc_id].dist_to_agent = model.dist_sm_iz
            # Priority 3 : There are no casualties at IZ but there are some in post_stabilize_q but less than post_stab_cap -> Go to hospital
            elseif (model[resc_id].which_pma == "VX") && (length(model.post_stabilize_q_vx) < model.post_stab_cap) && (length(model.post_stabilize_q_vx) > 0) && (length(is_awaiting_rescue) == 0)
                model[resc_id].on_way_to_hosp = true
                model[resc_id].dist_to_agent = model.dist_vx_hosp
            elseif (model[resc_id].which_pma == "SM") && (length(model.post_stabilize_q_sm) < model.post_stab_cap) && (length(model.post_stabilize_q_sm) > 0) && (length(is_awaiting_rescue) == 0)
                model[resc_id].on_way_to_hosp = true
                model[resc_id].dist_to_agent = model.dist_sm_hosp
            # Priority 4 : There are no casualities at IZ and no casualties in post_stabilize_q but there are some in the other queues (stabilize_q) -> stay at pma
            elseif (model[resc_id].which_pma == "VX") && (length(model.in_stabilize_q_vx) > 0 || length(model.pre_stabilize_q_vx) > 0) && (length(is_awaiting_rescue) == 0)
                model[resc_id].at_pma = true
            elseif (model[resc_id].which_pma == "SM") && (length(model.in_stabilize_q_sm) > 0 || length(model.pre_stabilize_q_sm) > 0) && (length(is_awaiting_rescue) == 0)
                model[resc_id].at_pma = true
            # Priority 5 : Model run ended
            else
                printstyled("Model Run Ended", color = "green")
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

            # Check if there are any casualties to survive 
            if length(get_awaiting_rescue(model)) > 0
                # Select closest casualty and update distance
                closest_cas_id = get_awaiting_rescue(model)[1]
                model[resc_id].cas_in_rescue = closest_cas_id
                model[resc_id].dist_to_agent = model[closest_cas_id].dist_from_iz
                
                # Update casualty attributes
                model[closest_cas_id].awaiting_rescue = false
                model[closest_cas_id].in_rescue = true
                model[closest_cas_id].rescued_by = resc_id
            # There are no more casualties at IZ - You have rescued every one of them !
            else
                model[resc_id].on_way_to_cas = false
                model[resc_id].on_way_to_pma = true
            end
        else
            # Rescuer at IZ and decided to travel to pma
            # Update rescuer attributes
            model[resc_id].at_iz = false 
            model[resc_id].on_way_to_pma = true

            # Update casualty attributes
            rescued_casualties = model[resc_id].rescued 
            update_cas_attr!(rescued_casualties, inactive_attr = :in_rescue, active_attr = :on_way_to_pma)
            
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
# Update PMA
# ==============================================================================
@doc """ 
Updates PMA queues
    + Updates in_stabilize_queues 
        + Update casualty attributes (:pre_stabilize_q -> :in_stabilize_q)
    + Updates post_stabilize_queues 
        + Update casualty attributes (:in_stabilize_q -> :post_stabilize_q)
"""->
function update_pma(model)
    if model.ticks > model.stab_opening_ticks

        # Update in_stabilize_q
        # VX : Add casualty from pre-stabilize-q to stabilize-q
        while (length(model.in_stabilize_q_vx) < model.stab_cap) && (length(model.pre_stabilize_q_vx) > 0)
            cas_id = model.pre_stabilize_q_vx[1]
            push!(model.in_stabilize_q_vx, (cas_id, model.ticks))
            popfirst!(model.pre_stabilize_q_vx)
            update_cas_attr!([cas_id],inactive_attr = :pre_stabilize_q, active_attr = :in_stabilize_q) #accepts and array of casualties that need updating
            
        end
        # SM : Add casualty from pre-stabilization-q to stabilization-q
        while (length(model.in_stabilize_q_sm) < model.stab_cap) && (length(model.pre_stabilize_q_sm) > 0)
            cas_id = model.pre_stabilize_q_sm[1]
            push!(model.in_stabilize_q_sm, (cas_id, model.ticks))
            popfirst!(model.pre_stabilize_q_sm)
            update_cas_attr!([cas_id],inactive_attr = :pre_stabilize_q, active_attr = :in_stabilize_q) #accepts and array of casualties that need updating
        end

        # Update post_stabilize_q
        # VX : Add casualties from in_stabilize_q to post_stabilize_q
        i = 1
        while i <= length(model.in_stabilize_q_vx) && length(model.in_stabilize_q_vx) > 0
            cas_id, stab_ticks = model.in_stabilize_q_vx[i]
            if (model.ticks - stab_ticks) > model.stab_time_ticks 
                push!(model.post_stabilize_q_vx, cas_id)
                deleteat!(model.in_stabilize_q_vx, i)
                update_cas_attr!([cas_id],inactive_attr = :in_stabilize_q, active_attr = :post_stabilize_q)
            end
            i += 1
        end

        # SM : Add casualties from in_stabilize_q to post_stabilize_q
        i = 1
        while i <= length(model.in_stabilize_q_sm) && length(model.in_stabilize_q_sm) > 0
            cas_id, stab_ticks = model.in_stabilize_q_sm[i]
            if (model.ticks - stab_ticks) > model.stab_time_ticks 
                push!(model.post_stabilize_q_sm, cas_id)
                deleteat!(model.in_stabilize_q_sm, i)
                update_cas_attr!([cas_id],inactive_attr = :in_stabilize_q, active_attr = :post_stabilize_q)
            end
            i += 1
        end
    end
end

# ==============================================================================
# Functions for Plotting
# ==============================================================================
@doc """Plot Rescuer Trajectories"""->
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

@doc """Plot PMA Queues""" ->
function plot_pma_queues(track_queues::Dict,method::String)
    if method == "static"
        p1 = Plots.plot(track_queues[:pre_stabilize_q_vx], ylim = 25, xlabel = "ticks", ylabel = "No of Casualties", title = "Pre Stabilization", label = "vx")
        Plots.plot!(track_queues[:pre_stabilize_q_sm], label = "sm")
        p2 = Plots.plot(track_queues[:in_stabilize_q_vx], ylim = 25, xlabel = "ticks", ylabel = "No of Casualties", title = "In Stabilization", label = "vx")
        Plots.plot!(track_queues[:in_stabilize_q_sm], label = "sm")
        p3 = Plots.plot(track_queues[:post_stabilize_q_vx], ylim = 25, xlabel = "ticks", ylabel = "No of Casualties", title = "Post Stabilization", label = "vx")
        Plots.plot!(track_queues[:post_stabilize_q_sm], label = "sm")
        p = Plots.plot(p1,p2,p3, layout = (3,1), size = (1000, 800))
        return p
    else
        anim = @animate for i = 1:500
            p1 = Plots.plot(track_queues[:pre_stabilize_q_vx][1:i], ylim = 25, xlabel = "ticks", ylabel = "No of Casualties", title = "Pre Stabilization", label = "vx")
            Plots.plot!(track_queues[:pre_stabilize_q_sm][1:i], label = "sm")
            p2 = Plots.plot(track_queues[:in_stabilize_q_vx][1:i], ylim = 25, xlabel = "ticks", ylabel = "No of Casualties", title = "In Stabilization", label = "vx")
            Plots.plot!(track_queues[:in_stabilize_q_sm][1:i], label = "sm")
            p3 = Plots.plot(track_queues[:post_stabilize_q_vx][1:i], ylim = 25, xlabel = "ticks", ylabel = "No of Casualties", title = "Post Stabilization", label = "vx")
            Plots.plot!(track_queues[:post_stabilize_q_sm][1:i], label = "sm")
            p = Plots.plot(p1,p2,p3, layout = (3,1), size = (1000, 800))
        end
        return anim
    end
end

@doc """Filters casualties by trauma"""->
filter_cas_by_ts(model::ABM,ts::Int)::Array{Int} = [k for (k,v) in model.agents if model[k] isa Cas && model[k].ts == ts]


@doc """Gets total casualties with particular attribute set to true"""
function count_casualties_with_prop(cas_ids::Array{Int}, attr::Symbol)
    count = 0
    for cas_id in cas_ids
        if getfield(model[cas_id], attr) 
            count += 1
        end
    end
    return count
end

# ==============================================================================
# Main Run
# ==============================================================================

begin 
    properties = Dict(
        :ticks => 0,
        :dist_vx_iz => 15000, #15 km
        :dist_sm_iz => 32000, #32 km
        :dist_vx_hosp => 57000, #57 km
        :dist_sm_hosp => 27000, #27 km
        :dist_per_step => 30000 / 60, # 30km/h = 500m/min
        :stab_opening_ticks => 180, #no of ticks when the stabilization opens up
        :stab_cap => 3, #no of casualties that can be taken into stabilization
        :stab_time_ticks => 20, #time taken for stabilization
        :resc_cap => 2,
        :post_stab_cap => 3, #to be taken to hosp if above this value
        :burn_bed_cap => 5,
        :non_burn_bed_cap => 10,
        :pre_stabilize_q_vx => Int[],
        :in_stabilize_q_vx => Array{Tuple{Int,Int}}([]), #(cas_id, ticks)
        :post_stabilize_q_vx => Int[],
        :pre_stabilize_q_sm => Int[],
        :in_stabilize_q_sm => Array{Tuple{Int,Int}}([]), #(cas_id, ticks)
        :post_stabilize_q_sm => Int[],
        :pre_treatment_q_hosp => Int[],
        :in_burn_beds => Int[],
        :in_non_burn_beds => Int[],
        :desceased => Array{Tuple{Int,String}}([]) #(cas_id, "awaiting_rescue")
    )

    # Initialise
    model = initialise(14, 3, properties)
end

begin
    track_pma_queues = @dict(
        pre_stabilize_q_vx = Int[],
        in_stabilize_q_vx = Int[],
        post_stabilize_q_vx = Int[],
        pre_stabilize_q_sm = Int[],
        in_stabilize_q_sm = Int[],
        post_stabilize_q_sm = Int[]
    )

    track_cas_attr_ts1 = @dict(
        awaiting_rescue = Int[],
        in_rescue = Int[],
        on_way_to_pma = Int[],
        pre_stabilize_q = Int[],
        in_stabilize_q = Int[],
        post_stabilize_q = Int[],
        on_way_to_hosp = Int[],
        in_hosp_q = Int[],
        in_burn_beds = Int[],
        in_non_burn_beds = Int[],
        is_deceased = Int[],
    )

    track_cas_attr_ts2 = @dict(
        awaiting_rescue = Int[],
        in_rescue = Int[],
        on_way_to_pma = Int[],
        pre_stabilize_q = Int[],
        in_stabilize_q = Int[],
        post_stabilize_q = Int[],
        on_way_to_hosp = Int[],
        in_hosp_q = Int[],
        in_burn_beds = Int[],
        in_non_burn_beds = Int[],
        is_deceased = Int[],
    )

    track_cas_attr_ts3 = @dict(
        awaiting_rescue = Int[],
        in_rescue = Int[],
        on_way_to_pma = Int[],
        pre_stabilize_q = Int[],
        in_stabilize_q = Int[],
        post_stabilize_q = Int[],
        on_way_to_hosp = Int[],
        in_hosp_q = Int[],
        in_burn_beds = Int[],
        in_non_burn_beds = Int[],
        is_deceased = Int[],
    )
end

for tick = 1:500
    # Initialise model with agents
    #todo Mortality be applied at start of run 
    #todo Array must be cleaned at start

    update_rescuers_at_pma(model)
    update_rescuers_at_iz(model)
    update_rescuers_at_cas(model)
    update_pma(model)
    travel_to_loc(model)

    # Keep track of stuff
    push!(track_pma_queues[:pre_stabilize_q_vx], length(model.pre_stabilize_q_vx))
    push!(track_pma_queues[:in_stabilize_q_vx], length(model.in_stabilize_q_vx))
    push!(track_pma_queues[:post_stabilize_q_vx], length(model.post_stabilize_q_vx))
    push!(track_pma_queues[:pre_stabilize_q_sm], length(model.pre_stabilize_q_sm))
    push!(track_pma_queues[:in_stabilize_q_sm], length(model.in_stabilize_q_sm))
    push!(track_pma_queues[:post_stabilize_q_sm], length(model.post_stabilize_q_sm))

    for k in keys(track_cas_attr_ts1)
        push!(track_cas_attr_ts1[k], count_casualties_with_prop(filter_cas_by_ts(model,1),k))
        push!(track_cas_attr_ts2[k], count_casualties_with_prop(filter_cas_by_ts(model,2),k))
        push!(track_cas_attr_ts3[k], count_casualties_with_prop(filter_cas_by_ts(model,3),k))
    end


    model.ticks += 1
end

plot_rescuer_trajectories(model)
plot_pma_queues(track_pma_queues, "static")
gif(anim, fps = 40)


