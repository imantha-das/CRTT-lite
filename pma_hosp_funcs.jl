module PmaHosp
    using Base:@kwdef
    using Agents: ABM
    using ..CasFuncs: update_cas_status!
    export vx, sm, ptp, update_pma_q!

    @doc """Vieux Habitants PMA queues""" ->
    @kwdef mutable struct vx
        pre_stabilize_q::Vector{Int} = Int[]
        in_stabilize_q::Vector{Int} = Int[]
        post_stabilize_q::Vector{Int} = Int[]
        recovered::Vector{Int} = Int[]
    end

    @doc """Sainte Marie PMA queues"""->
    @kwdef mutable struct sm
        pre_stabilize_q::Vector{Int} = Int[]
        in_stabilize_q::Vector{Int} = Int[]
        post_stabilize_q::Vector{Int} = Int[]
        recovered::Vector{Int} = Int[]
    end

    @doc """Point Pitre Hospital queues"""
    @kwdef mutable struct ptp
        pre_treatment_q::Vector{Int} = Int[]
        in_burn_beds::Vector{Int} = Int[]
        in_non_burn_beds::Vector{Int} = Int[]
    end

    @doc """ 
    Desc : Rearranges casualties based on TS, where ts2 takes precedence over ts3
    """->
    function rearrange_post_stablize_q(model,post_stabilize_q)
        post_stab_q_ts1 = Int64[]
        post_stab_q_ts2 = Int64[]
        post_stab_q_ts3 = Int64[]
        for cas_id in post_stabilize_q
            if model[cas_id].ts == 1
                push!(post_stab_q_ts1,cas_id)
            elseif model[cas_id].ts == 2
                push!(post_stab_q_ts2, cas_id)
            else 
                push!(post_stab_q_ts3, cas_id)
            end
        end
        return vcat(post_stab_q_ts2, post_stab_q_ts3, post_stab_q_ts1)
    end

    @doc """
    Desc : Stabilization Process
    + Moves casualties who have been stabilized from in_stabilize_q to post_stabilize_q
    + Otherwise Deducts 1 for every tick from stab_ticker
    """->
    #! NEED TO TAKE CARE OF TS1 : THEY CANNOT BE MOVED TO POST_STABILIZE_Q
    function stabilize_cas_in_stabilize_q!(model::ABM)
        # FOR VX
        # Move casualties who's stab ticker is 0
        stabilized_cas_vx_idx::Vector{Int64} = findall(cas_id -> model[cas_id].stab_ticker == 0, model.vx.in_stabilize_q)
        push!(model.vx.post_stabilize_q, (model.vx.in_stabilize_q[stabilized_cas_vx_idx])...)
        # Update casualty status - You use in_stabilize_q still since you havent deleted those casualties
        update_cas_status!(model, model.vx.in_stabilize_q[stabilized_cas_vx_idx],:in_post_stabilize_q)
        # Now delete thos casualties
        deleteat!(model.vx.in_stabilize_q,stabilized_cas_vx_idx)
        # Who ever is lef is not stabilized hence reduce 1 from their stabilize counter
        map(cas_id -> model[cas_id].stab_ticker -= 1, model.vx.in_stabilize_q)

        # FOR SM
        # Move casualties who's stab ticker is 0
        stabilized_cas_sm_idx::Vector{Int64} = findall(cas_id -> model[cas_id].stab_ticker == 0, model.sm.in_stabilize_q)
        push!(model.sm.post_stabilize_q, (model.sm.in_stabilize_q[stabilized_cas_sm_idx])...)
        # Update casualty status - You use in_stabilize_q still since you havent deleted those casualties
        update_cas_status!(model, model.sm.in_stabilize_q[stabilized_cas_sm_idx],:in_post_stabilize_q)
        # Now delete thos casualties
        deleteat!(model.sm.in_stabilize_q,stabilized_cas_sm_idx)
        # Who ever is lef is not stabilized hence reduce 1 from their stabilize counter
        map(cas_id -> model[cas_id].stab_ticker -= 1, model.sm.in_stabilize_q)
    end

    @doc """
    Desc : Update Queues
        - NOTE you dont need to worry about ts1 agents since they will only be brought after ts23 are rescued
    + Move from pre_stabilize_q -> in_stabilize_q 
        - FIFO (first in first out strategy)
        - ticks > stab_opening_ticks, move cas from :pre_stabilize_q -> in_stabilize_q till capacity is reached
    + Move from in_stabilize_q -> post_stabilize_1
        - FIFO
        - - (ticks - stab_ticks) > stab_time_ticks move cas :in_stabilize_q -> post_stabilize_q till capcity is reached
    """-> 
    function update_pma_q!(model::ABM)
        if model.ticks > model.stab_opening_ticks
    
            # Update in_stabilize_q
            # VX : Add casualty from pre-stabilize-q to stabilize-q
            while (length(model.vx.in_stabilize_q) < model.stab_cap) && (length(model.vx.pre_stabilize_q) > 0)
                cas_to_transfer = first(model.vx.pre_stabilize_q)
                push!(model.vx.in_stabilize_q, cas_to_transfer)
                popfirst!(model.vx.pre_stabilize_q)
                update_cas_status!(model,[cas_to_transfer],:in_stabilize_q) #accepts and array of casualties that need updating
                model[cas_to_transfer].stab_ticker = model.stab_time_ticks #initialise stabilise counter
            end
            # SM : Add casualty from pre-stabilization-q to stabilization-q
            while (length(model.sm.in_stabilize_q) < model.stab_cap) && (length(model.sm.pre_stabilize_q) > 0)
                cas_to_transfer = first(model.sm.pre_stabilize_q)
                push!(model.sm.in_stabilize_q, cas_to_transfer)
                popfirst!(model.sm.pre_stabilize_q)
                update_cas_status!(model,[cas_to_transfer], :in_stabilize_q) #accepts and array of casualties that need updating
                model[cas_to_transfer].stab_ticker = model.stab_time_ticks
            end
    
            # Update post_stabilize_q
            # VX & SM : Add casualties from in_stabilize_q to post_stabilize_q
            stabilize_cas_in_stabilize_q!(model)            
        end
    end
end