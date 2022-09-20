# ==============================================================================
# Desc : Rescuer functions
# ==============================================================================
module RescFuncs
    using ..AgentTypes:Cas,Resc
    using ..CasFuncs: update_cas_status!, get_cas_by_prop, get_awaiting_rescue_ts1, get_awaiting_rescue_ts23
    using Agents: ABM

    export update_rescuers_at_pma!,get_cas_by_prop

    # ==========================================================================
    # Get rescuers by property
    # ==========================================================================
    @doc """Filters rescuers by property"""
    get_resc_by_prop(model::ABM,prop::Symbol)::Set{Int} = filter(
        id -> 
        (getfield(model[id], :status) == prop) && (model[id] isa Resc)
        , keys(model.agents)
    )
    # ==========================================================================
    # Decide on Next Step
    # ==========================================================================

    @doc """ 
    Desc : Decides what to do next at PMA, IZ, & Hosp 
    PMA
        + @ticks=0 
            + update status to :on_way_to_pma 
            + update dist_to_agent (dist to Iz from sm or vx)
    IZ 
        + Make a decision between IZ or PMA (criteria : rescuer capacity)
        + Decide on which casualty to save : TS23 given priority 
    """
    function decide_next_step!(model::ABM, resc_id::Int)
        # ----------------------------------------------------------------------
        #  PMA
        # ----------------------------------------------------------------------
        if model[resc_id].status == :at_pma
            # If @ticks == 0 go to IZ 
            if model.ticks == 0
                model[resc_id].status = :on_way_to_iz
                if model[resc_id].which_pma == "VX" 
                    model[resc_id].dist_to_agent = model.dist_vx_iz
                elseif model[resc_id].which_pma == "SM"
                    model[resc_id].dist_to_agent = model.dist_sm_iz
                else
                    @assert model[resc_id].which_pma != "VX" || model[resc_id].which_pma != "SM", ".which_pma != VX or SM"
                end
            # @ticks != 0
            else
                #todo Make sure you Check if there are TS23 agents in IZ. If no you should go to hospital first
            end
        end
        # ----------------------------------------------------------------------
        # IZ
        # ----------------------------------------------------------------------
        if model[resc_id].status == :at_iz
            # Make Decision between IZ or PMA
            # Havent reached rescuer capacity and there is someone to save
            if (length(model[resc_id].rescued) < model.resc_cap) && (length(get_cas_by_prop(model, :awaiting_rescue)) > 0)
                model[resc_id].status = :on_way_to_cas
                # There are TS23 casualties to rescue
                if length(get_awaiting_rescue_ts23(model)) > 0
                    # todo : need to rearange these casualties based on their distance and pick the closest
                # There are no TS23 casualties, go check for TS1 casualties. Statement above checks if there are any casualties.
                else

                end

            else

            end
        end
    end

    # ==========================================================================
    # Update Rescuers at PMA
    # ==========================================================================
    
    @doc """
    Desc : Updates rescuers who are at PMA. Updates location trajectory and
    rescuer and casualty status changes. Decide_on_next_step! function is called
    inside this function 
    + Status Updates
        + update loc_traject with current status
        + update casulty current status (:on_way_to_pma -> :pre_stabilize_q)
    + Next Decision 
        + go either to Hospital or IZ
    """->
    function update_rescuers_at_pma!(model::ABM)
        for resc_id in get_resc_by_prop(model, :at_pma)
            if model[resc_id].which_pma == "VX"
                push!(model[resc_id].loc_traject, "at_VX")
                push!(model.vx_q.pre_stabilize_q, model[resc_id].rescued...) #note works when its an empty array
                update_cas_status!(model, model[resc_id].rescued,:pre_stabilize_q)
                map(cas_id -> model[cas_id].which_pma = "at_VX", model[resc_id].rescued) # Update .which_pma attribute 
            else
                push!(model[resc_id].loc_traject, "at_SM")
                push!(model.sm_q.pre_stabilize_q, model[resc_id].rescued...) #note works when its an empty array
                update_cas_status!(model, model[resc_id].rescued,:pre_stabilize_q)
                map(cas_id -> model[cas_id].which_pma = "at_SM", model[resc_id].rescued) # Update .which_pma attribute 
            end
            # Decide what to to do next
            decide_next_step!(model, resc_id)
        end
    end

    # ==========================================================================
    # 
    # ==========================================================================

    # ==========================================================================
    # Travel to loc
    # ==========================================================================
    @doc """
    Desc : Function that makes rescuers travel to location.
    + Agents traveing :on_way_to_iz
        + update dist_to_agent
        + update location trajectory and distance trajectory
        + Once you reach IZ, update status and revert dist to agent as zero
    """->
    function travel_to_loc(model)
        for resc_id in get_resc_by_prop(model,:on_way_to_iz)
            push!(model[resc_id].dist_traject, model[resc_id]) #This is just for checking purposes
            model[resc_id].dist_to_agent -= model.dist_per_step 
            push!(model[resc_id].loc_traject, "on_way_to_iz")

            # You have reached IZ 
            if model[resc_id].dist_to_agent < 0
                model[resc_id].status = :at_iz
                model[resc_id].dist_to_agent = 0
            end
        end



    end

end



