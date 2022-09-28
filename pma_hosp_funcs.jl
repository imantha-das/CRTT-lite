module PmaHosp
    using Base:@kwdef
    using Agents: ABM
    using ..CasFuncs: update_cas_status!
    export vx, sm, ptp, update_pma_q!

    @doc """Vieux Habitants PMA queues""" ->
    @kwdef mutable struct vx
        pre_stabilize_q::Vector{Int} = Int[]
        in_stabilize_q::Vector{Tuple{Int,Int}} = Vector{Tuple{Int,Int}}([])
        post_stabilize_q::Vector{Int} = Int[]
    end

    @doc """Sainte Marie PMA queues"""->
    @kwdef mutable struct sm
        pre_stabilize_q::Vector{Int} = Int[]
        in_stabilize_q::Vector{Tuple{Int,Int}} = Vector{Tuple{Int,Int}}([])
        post_stabilize_q::Vector{Int} = Int[]
    end

    @doc """Point Pitre Hospital queues"""
    @kwdef mutable struct ptp
        pre_treatment_q::Vector{Int} = Int[]
        in_burn_beds::Vector{Int} = Int[]
        in_non_burn_beds::Vector{Int} = Int[]
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
                push!(model.vx.in_stabilize_q, (cas_to_transfer, model.ticks))
                popfirst!(model.vx.pre_stabilize_q)
                update_cas_status!(model,[cas_to_transfer],:in_stabilize_q) #accepts and array of casualties that need updating
                
            end
            # SM : Add casualty from pre-stabilization-q to stabilization-q
            while (length(model.sm.in_stabilize_q) < model.stab_cap) && (length(model.sm.pre_stabilize_q) > 0)
                cas_to_transfer = first(model.sm.pre_stabilize_q)
                push!(model.sm.in_stabilize_q, (cas_to_transfer, model.ticks))
                popfirst!(model.sm.pre_stabilize_q)
                update_cas_status!(model,[cas_to_transfer], :in_stabilize_q) #accepts and array of casualties that need updating
            end
    
            # Update post_stabilize_q
            # VX : Add casualties from in_stabilize_q to post_stabilize_q
            i = 1
            while i <= length(model.vx.in_stabilize_q) && length(model.vx.in_stabilize_q) > 0
                cas_to_transfer, stab_ticks = first(model.vx.in_stabilize_q)
                if (model.ticks - stab_ticks) > model.stab_time_ticks 
                    push!(model.vx.post_stabilize_q, cas_to_transfer)
                    deleteat!(model.vx.in_stabilize_q, i)
                    update_cas_status!(model,[cas_to_transfer], :in_post_stabilize_q)
                end
                i += 1
            end
    
            # SM : Add casualties from in_stabilize_q to post_stabilize_q
            i = 1
            while i <= length(model.sm.in_stabilize_q) && length(model.sm.in_stabilize_q) > 0
                cas_to_transfer, stab_ticks = first(model.sm.in_stabilize_q)
                if (model.ticks - stab_ticks) > model.stab_time_ticks 
                    push!(model.sm.post_stabilize_q, cas_to_transfer)
                    deleteat!(model.sm.in_stabilize_q, i)
                    update_cas_status!(model,[cas_to_transfer], :in_post_stabilize_q)
                end
                i += 1
            end
        end
    end
end