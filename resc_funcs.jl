# ==============================================================================
# Desc : Rescuer functions
# ==============================================================================
module RescFuncs
    using ..AgentTypes:Cas,Resc
    using ..CasFuncs: update_cas_status!
    using Agents: ABM

    export update_rescuers_at_pma!, print_hello

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
        + @ticks=0 --> :on_way_to_iz
    """
    function decide_next_step!(model::ABM, resc_id::Int)
        # ----------------------------------------------------------------------
        #  PMA
        # ----------------------------------------------------------------------
        if model[resc_id].status == :at_pma
            printstyled("Executed", color = :magenta)
            # If @ticks == 0 go to IZ 
            if model.ticks == 0
                model[resc_id].status = :on_way_to_iz
                if model[resc_id].which_pma == "VX" #!make sure to update .which_pma
                    model[resc_id].dist_to_agent = model.dist_vx_iz
                elseif model[resc_id].which_pma == "SM"
                    model[resc_id].dist_to_agent == model.dist_sm_iz
                else
                    @assert model[resc_id].which_pma != "VX" || model[resc_id].which_pma != "SM", ".which_pma != VX or SM"
                end
            # @ticks != 0
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
    """ ->
    function update_rescuers_at_pma!(model::ABM)
        print("Hello")
        printstyled("Executed-1", color = :blue)
        for resc_id in get_resc_by_prop(model, :at_pma)
            if model[resc_id].which_pma == "VX"

                printstyled("Executed", color = :blue)

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
            @show resc_id
            decide_next_step!(model, resc_id)
        end
    end

    function print_hello()
        print("hello")
    end

end



