# ==============================================================================
# Desc : Rescuer functions
# ==============================================================================
module RescFuncs
    using ..AgentTypes:Cas,Resc
    using ..CasFuncs: update_cas_status!, get_cas_by_prop, get_awaiting_rescue_ts1, get_awaiting_rescue_ts23
    using Agents: ABM
    using Distributions: Normal

    export update_resc_at_pma!, update_resc_searching_cas!, update_resc_at_iz!, update_resc_load_cas_at_iz!

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
    :at_pma
        + @ticks=0 
            - update status to :on_way_to_pma 
            - update dist_to_agent (dist to Iz from sm or vx)
        + @ticks != 0
            - Priority 1 : hosp_transfer_cap exceeded -> :load_cas_at_pma
            - priority 2 : hosp_transfer_cap NOT exceed && awaiting_rescue_ts23 > 0 -> :on_way_to_iz
                * Update dist from VX to IZ    
            #todo Need to account for cases where agent still goes to IZ due agent availability but find no agent
            - Priority 3 : hosp_transfer_cap NOT exceeded && post_stabilize_q_ts23 > 0 && awaiting_rescue_ts23 == 0 -> :load_cas_at_pma
            - priority 4 : hosp_transfer_cap NOT exceeded && (pre_stabilize_q_t23  || stabilize_q_ts23) > 0 -> :at_pma
            - Priority 5 : awaiting_rescue_TS1 > 0 -> :on_way_to_iz 
                * Update dist from VX to IZ
                #todo Need to account for cases where agent still goes to IZ due agent availability but find no agent
            - priority 6 : awaiting_rescue_TS1 == 0 -> :rescue_finished
    :at_iz 
        + rescued < resc_cap : (at_iz -> :search_cas)
            - update search_time (from 999 to some Integer value)
        + rescued == resc_cap : (at_iz -> :on_way_to_pma)
            - Priority 1 : vx.post_stabilize_q > hosp_transfer_cap -> VX (VX given priority over SM as its closer to PtP, go there since you have some casualties to transfer)
            - Priority 2 : sm.post_stabilize_q > hosp_transfer_cap -> SM (Go to sm as there are casualties to be taken to PtP)
                * Update dist to SM to IZ
            - Priority 3 : vx.pre_stabilize_q > sm.pre_stabilize_q -> VX (Go to Vx as it has a shorter queue)
            - Priority 4 : sm.pre_stabilize_q > vx.pre_stabilize_q -> SM (Go to SM as it has a shorter queue)
            - Priority 5 : VX (Go to VX since its closer to impact zone)
                * Update dist from SM to IZ
    :search_cas
    + search_time == 0 : (:search_cas -> :load_cas_at_iz)

    #?  + note there is status update at update_resc_load_cas_at_iz, :load_cas_at_iz -> :at_iz  
    """
    function decide_next_step!(model::ABM, resc_id::Int)
        # ----------------------------------------------------------------------
        #  :at_pma
        # ----------------------------------------------------------------------
        if model[resc_id].status == :at_pma
            #* If @ticks == 0 go to IZ 
            if model.ticks == 0
                model[resc_id].status = :on_way_to_iz
                if model[resc_id].which_pma == "VX" 
                    model[resc_id].dist_to_agent = model.dist_vx_iz
                elseif model[resc_id].which_pma == "SM"
                    model[resc_id].dist_to_agent = model.dist_sm_iz
                else
                    @assert model[resc_id].which_pma != "VX" || model[resc_id].which_pma != "SM", ".which_pma != VX or SM"
                end
            #* @ticks != 0
            else
                #todo Make sure you Check if there are TS23 agents in IZ. If no you should go to hospital first
                # -------------------------------------------------------------- VX
                if model[resc_id].which_pma == "VX"
                    # Priotity 1 : hosp_transfer_cap
                    if (length(model.vx.post_stabilize_q) > length(model.hosp_transfer_cap)) 
                        model[resc_id].status = :load_cas_at_pma
                        println("priority 1")
                    # priority 2 : hosp transfer cap NOT reached and there ts23 agent awaiting rescue
                    elseif (length(model.vx.post_stabilize_q) < length(model.hosp_transfer_cap)) && (length(get_awaiting_rescue_ts23(model)) > 0)
                        model[resc_id].status = :on_way_to_iz
                        model[resc_id].dist_to_agent = model[resc_id].which_pma == "VX" ? model.dist_vx_iz : model.dist_sm_iz
                        println("prority 2")
                    # priority 3 : hosp transfer cap not reached but there are ts23 casualties in post stabilize q and there are no ts23 agent awaiting rescue 
                    elseif (length(model.vx.post_stabilize_q) < length(model.hosp_transfer_cap)) && (length(get_awaiting_rescue_ts23(model)) == 0)
                        model[rescid].status = :load_cas_at_pma
                        println("priority 3")
                    # priority 4 : hosp transfer cap not reached but there are ts23 agents in either pre_stabilize_q or in_stabilize_q and there are no ts23 agents awaiting rescue
                    elseif (length(model.vx.post_stabilize_q) < length(model.hosp_transfer_cap)) && (length(model.vx.pre_stabilize_q) > 0 || length(model.vx.in_stabilize_q) > 0) && (length(get_awaiting_rescue_ts23(model)) == 0)
                        model[resc_id].status = :load_cas_at_pma 
                        println("prioirty 4")
                    # Priority 5 : There are no ts23 casualties in pma or iz -> go search for ts1 casualties
                    elseif (length(get_awaiting_rescue_ts1(model)) > 0)
                        model[resc_id].status = :on_way_to_iz
                        model[resc_id].dist_to_agent = model[resc_id].which_pma == "VX" ? model.dist_vx_iz : model.dist_sm_iz
                        println("Searching for TS1 casualties")
                        println("prioirty 5")
                    # priority 6 : There are no casualties to rescue anymore
                    elseif (length(get_awaiting_rescue_ts1(model)) == 0)
                        model[resc_id].status = :rescue_finished 
                        println("priority 6")
                    else
                        printstyled("Any of priority statements were NOT executed", color = :red)                     
                    end
                
                # -------------------------------------------------------------- SM
                else
                    # Priotity 1 : hosp_transfer_cap
                    if length(model.sm.post_stabilize_q) > length(model.hosp_transfer_cap)
                        model[resc_id].status = :load_cas_at_pma
                    # priority 2 : hosp transfer cap NOT reached and there ts23 agent awaiting rescue
                    elseif (length(model.sm.post_stabilize_q) < length(model.hosp_transfer_cap)) && (length(get_awaiting_rescue_ts23(model)) > 0)
                        model[resc_id].status = :on_way_to_iz
                        model[resc_id].dist_to_agent = model[resc_id].which_pma == "VX" ? model.dist_vx_iz : model.dist_sm_iz
                    # priority 3 : hosp transfer cap not reached but there are ts23 casualties in post stabilize q and there are no ts23 agent awaiting rescue 
                    elseif (length(model.sm.post_stabilize_q) < length(model.hosp_transfer_cap)) && (length(get_awaiting_rescue_ts23(model)) == 0)
                        model[resc_id].status = :load_cas_at_pma
                    # priority 4 : hosp transfer cap not reached but there are ts23 agents in either pre_stabilize_q or in_stabilize_q and there are no ts23 agents awaiting rescue
                    elseif (length(model.sm.post_stabilize_q) < length(model.hosp_transfer_cap)) && (length(model.sm.pre_stabilize_q) > 0 || length(model.sm.in_stabilize_q) > 0) && (length(get_awaiting_rescue_ts23(model)) == 0)
                        model[resc_id].status = :load_cas_at_pma 
                    # Priority 5 : There are no ts23 casualties in pma or iz -> go search for ts1 casualties
                    elseif (length(get_awaiting_rescue_ts1(model)) > 0)
                        model[resc_id].status = :on_way_to_iz
                        model[resc_id].dist_to_agent = model[resc_id].which_pma == "VX" ? model.dist_vx_iz : model.dist_sm_iz
                        println("Searching for TS1 casualties")
                    # priority 6 : There are no casualties to rescue anymore
                    elseif (length(awaiting_rescue_ts1) == 0)
                        model[resc_id].status = :rescue_finished 
                    else
                        printstyled("Any of priority statements were NOT executed", color = :red)                     
                    end

                end
            end
        end
        # ----------------------------------------------------------------------
        # :at_iz
        # ----------------------------------------------------------------------
        if model[resc_id].status == :at_iz
            # Make Decision between IZ or PMA
            # Havent reached rescuer capacity and there is someone to save : (:at_iz -> :search_cas)
            if (length(model[resc_id].rescued) < model.resc_cap) && (length(get_cas_by_prop(model, :awaiting_rescue)) > 0)
                model[resc_id].status = :search_cas
                model[resc_id].search_time = rand(model.search_time) |> abs |> x -> round(Int,x)
            # rescuer cap full or there are no agents to save : ():at_iz -> :on_way_to_pma)
            else
                model[resc_id].status = :on_way_to_pma
                # Go to VX (priotiry 1) or SM (priority 2) if the hosp_transfer_cap has reached since you need to casualtiy to PtP
                if length(model.vx.post_stabilize_q) > length(model.hosp_transfer_cap)
                    model[resc_id].which_pma = "VX"
                    model[resc_id].dist_to_agent = model.dist_vx_iz
                elseif length(model.sm.post_stabilize_q) > length(model.hosp_transfer_cap)
                    model[resc_id].which_pma = "SM"
                    model[resc_id].dist_to_agent = model.dist_sm_iz
                # Travel to PMA with the lower queue length (PMA). If equal, VX is given priority
                elseif length(model.vx.pre_stabilize_q) <= length(model.sm.pre_stabilize_q)
                    model[resc_id].which_pma = "VX" 
                    model[resc_id].dist_to_agent = model.dist_vx_iz 
                elseif length(model.sm.pre_stabilize_q) < length(model.vx.pre_stabilize_q)
                    model[resc_id].which_pma = "SM" 
                    model[resc_id].dist_to_agent = model.dist_sm_iz
                else
                    model[resc_id].which_pma = "VX"
                    model[resc_id].dist_to_agent = model.dist_vx_iz 
                end

            end
        end

        # ----------------------------------------------------------------------
        # :search_cas
        # ----------------------------------------------------------------------
        # Search time over, You have found a casualty
        if model[resc_id].status == :search_cas && model[resc_id].search_time == 0
            model[resc_id].status = :load_cas_at_iz
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
    function update_resc_at_pma!(model::ABM)
        # --------------------------------------------------------------------------
        # :at_pma
        # --------------------------------------------------------------------------
        for resc_id in get_resc_by_prop(model, :at_pma)
            if model[resc_id].which_pma == "VX"
                push!(model[resc_id].loc_traject, "at_VX")
                push!(model.vx.pre_stabilize_q, model[resc_id].rescued...) #note works when its an empty array
                update_cas_status!(model, model[resc_id].rescued,:in_pre_stabilize_q)
                map(cas_id -> model[cas_id].at_pma = "at_VX", model[resc_id].rescued) # Update .which_pma attribute 
                model[resc_id].rescued = [] #clear all rescued casualties
            else
                push!(model[resc_id].loc_traject, "at_SM")
                push!(model.sm.pre_stabilize_q, model[resc_id].rescued...) #note works when its an empty array
                update_cas_status!(model, model[resc_id].rescued,:in_pre_stabilize_q)
                map(cas_id -> model[cas_id].at_pma = "at_SM", model[resc_id].rescued) # Update .which_pma attribute 
                model[resc_id].rescued = [] #clear all rescued casualties
            end
            # Decide what to to do next
            decide_next_step!(model, resc_id)
        end
        # --------------------------------------------------------------------------
        # :load_cas_at_pma
        # --------------------------------------------------------------------------
        for resc_id in get_resc_by_prop(model, :load_cas_at_pma)
            if model[resc_id].which_pma == "VX"
                push!(model[resc_id].loc_traject, "load_cas")
                #todo search for ts2 casualties if not ts3 casualties in post_stabilize_q
            else
                #todo do the above to sm pma
            end
        end
    end

    # ==========================================================================
    # Update agents at IZ
    # ==========================================================================
    @doc """
    Desc : Updates rescuers at IZ 
    :at_iz
        + update loc traject, reinitialise distance to agent and take next decision
    :on_way_to_pma
    """->
    function update_resc_at_iz!(model::ABM)
        for resc_id in get_resc_by_prop(model, :at_iz)
            push!(model[resc_id].loc_traject, "at_iz")
            model[resc_id].dist_to_agent = 999 # reinitialize distance to agent 
            decide_next_step!(model, resc_id) # get next status
        end
    end

    # ==========================================================================
    # Update agents searching for casualties
    # ==========================================================================
    @doc """ 
    Desc : Update rescuers searching for casualties 
        + :search_cas -> @search_time -= 1 -> @search_time == 0 -> decide_next_step! -> :load_cas_at_iz
    """
    function update_resc_searching_cas!(model::ABM)
        for resc_id in get_resc_by_prop(model, :search_cas)
            model[resc_id].search_time -= 1
            push!(model[resc_id].loc_traject, "search_cas")
            decide_next_step!(model, resc_id)
        end 
    end

    # ==========================================================================
    # Update Load Cas at IZ
    # ==========================================================================
    @doc """
    Desc : Update rescuers loading casualties
        * rescued < resc_cap ALREADY CHECKED at Decide_on_next_step! :at_iz
        + ts23 > 0 -> add ts23 agent to rescued
            - update cas status
    #!      - update resc status
        + ts23 < 0 -> add ts1 agent to rescued 
    """->
    function update_resc_load_cas_at_iz!(model::ABM)
        
        for resc_id in get_resc_by_prop(model, :load_cas_at_iz)
            # Check if there are any casualties to rescue
            if length(get_cas_by_prop(model, :awaiting_rescue)) > 0
                # if length(get_awaiting_rescue_ts23) > select ts23 else ts1 (single agent)
                cas_in_rescue = length(get_awaiting_rescue_ts23(model)) > 0 ? first(get_awaiting_rescue_ts23(model)) : first(get_awaiting_rescue_ts1(model)) 
                push!(model[resc_id].rescued, cas_in_rescue)
                update_cas_status!(model, [cas_in_rescue],:in_rescue) #update cas status
                model[cas_in_rescue].rescued_by = resc_id
                push!(model[resc_id].loc_traject, "load_cas_at_iz") #update resc status
                model[resc_id].status = :at_iz 
            # There are no casualties, so head to PMA
            else
                model[resc_id].status = :on_way_to_pma
            end
        end

    end
    # ==========================================================================
    # Travel to loc
    # ==========================================================================
    @doc """
    Desc : Function that makes rescuers travel to location.
    + :on_way_to_iz
        + update dist_to_agent
        + update location trajectory and distance trajectory
    #?  + dist_to_agent < 0,status update : (:on_way_to_iz -> :at_iz)
            - dist_to_agent 
    + on_way_to_pma
        + update dist_to_agent
        + update loc_traject and dist_to_agent
    #?  + dist_to_agent < 0, status_update : (:on_way_to_pma -> :at_pma)
    """->
    function travel_to_loc(model)
        # ----------------------------------------------------------------------
        # :on_way_to_iz
        # ----------------------------------------------------------------------
        for resc_id in get_resc_by_prop(model,:on_way_to_iz)
            push!(model[resc_id].dist_traject, model[resc_id].dist_to_agent) #This is just for checking purposes
            model[resc_id].dist_to_agent -= model.dist_per_step 
            push!(model[resc_id].loc_traject, "on_way_to_iz")

            # You have reached IZ 
            if model[resc_id].dist_to_agent < 0
                model[resc_id].status = :at_iz
                model[resc_id].dist_to_agent = NaN
            end
        end
        # ----------------------------------------------------------------------
        # :on_way_to_pma
        # ----------------------------------------------------------------------
        for resc_id in get_resc_by_prop(model, :on_way_to_pma)
            push!(model[resc_id].dist_traject, model[resc_id].dist_to_agent)
            model[resc_id].dist_to_agent -= model.dist_per_step 
            push!(model[resc_id].loc_traject, "on_way_to_pma")

            # You have reached PMA 
            if model[resc_id].dist_to_agent < 0 
                model[resc_id].status = :at_pma 
                model[resc_id].dist_to_agent = NaN
            end
        end
    end

end

#= resc_agent props
        mutable struct Resc <: AbstractAgent
        const id::Int
        status::Symbol # :at_iz, :on_way_to_iz, :search_time, :load_cas_at_iz, :at_pma, :load_cas_at_pma, :on_way_to_pma, :at_hosp, :on_way_to_hosp, rescue_finished
        cas_in_rescue::Int - DELETE
        dist_to_agent::Float64
        rescued::Vector{Int}
        which_pma::String   
        dist_traject::Vector{Float64}
        loc_traject::Vector{String}
        search_time::Int
        function Resc(id;status=:at_pma,cas_in_rescue=999,dist_to_agent=999,rescued = Int[],which_pma = rand(["VX","SM"]),dist_traject=Float64[],loc_traject=String[],search_time = 999)
            new(id,status,cas_in_rescue,dist_to_agent,rescued,which_pma,dist_traject,loc_traject, search_time)
        end
    end
=#

