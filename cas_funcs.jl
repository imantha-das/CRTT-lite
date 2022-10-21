# ==============================================================================
# Desc : Contains Casualty Functions
# ==============================================================================
module CasFuncs

    using Agents: ABM
    using ..AgentTypes: Cas

    export update_cas_status!, get_cas_by_prop, get_awaiting_rescue_ts23, get_awaiting_rescue_ts1

    @doc """Updates casualty functions"""->
    function update_cas_status!(model::ABM,cas_ids::Array{Int64},update_attr::Symbol)
        for cas_id in cas_ids
            # Update to next status
            setfield!(model[cas_id],:status,update_attr)
            # Keep track of current status 
            push!(model[cas_id].status_traject, (model[cas_id].status,model.ticks))
        end
    end

    @doc """Get Casualties with status"""
    get_cas_by_prop(model::ABM,prop::Symbol)::Set{Int} = filter(
        id -> 
        (getfield(model[id], :status) == prop) && (model[id] isa Cas)
        , keys(model.agents)
    )

    @doc """Get TS23 casualties"""->
    get_awaiting_rescue_ts23(model::ABM)::Vector{Int} = [
        k for (k,v) in model.agents if (v isa Cas) && (v.status == :awaiting_rescue) && ((v.ts == 2) || (v.ts == 3))
    ]

    @doc """Get TS1 casualties"""->
    get_awaiting_rescue_ts1(model::ABM)::Vector{Int} = [
        k for (k,v) in model.agents if (v isa Cas) && (v.status == :awaiting_rescue) && (v.ts == 1)
    ]
    
end
