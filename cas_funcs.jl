# ==============================================================================
# Desc : Contains Casualty Functions
# ==============================================================================
module CasFuncs

    using Agents: ABM

    export update_cas_status!
    @doc """Updates casualty functions"""->
    function update_cas_status!(model::ABM,cas_ids::Array{Int64},update_attr::Symbol)
        for cas_id in cas_ids
            # Keep track of current status 
            push!(model[cas_id].status_traject, model[cas_id].status)
            # Update to next status
            setfield!(model[cas_id],:status,update_attr)
        end
    end

end
