module Utils
export initialise,filter_rescuers

include("CrttAgents.jl")
using Agents: Schedulers, add_agent!, nagents, ABM
using .Crtt_Agents: Cas, Resc

# ------------------------------------------------------------------------------
# Initialise Model
# ------------------------------------------------------------------------------
function initialise(num_cas::Int64,num_resc::Int64)
    model = ABM(
        Union{Cas,Resc},
        scheduler = Schedulers.fastest,
        properties = Dict(
            :ticks => 0, 
            :dist_per_step => 50.,
            :dist_from_vx => 2000.,
            :dist_from_sm => 2500.,
            :dist_from_hosp => 10000.
        )
    )

    # Add Casualties
    for i = 1:num_cas
        cas = Cas(
            i,
            rand([1,2,3]),
            model.dist_from_vx,
            model.dist_from_sm,
            model.dist_from_hosp
        )
        add_agent!(cas, model)
    end

    # Add Rescuers 
    for i = nagents(model) + 1:nagents(model) + num_resc
        resc = Resc(
            i
        )
        add_agent!(resc,model)
    end

    return model
end 

# ------------------------------------------------------------------------------
# Filter Rescuers
# ------------------------------------------------------------------------------

function filter_rescuers(model::ABM)
    rescuers = filter(a -> isa(a, Resc), model.agents)
    println(rescuers)
end

end

# ==============================================================================
# Main.jl
# ==============================================================================




