using Agents: AbstractAgent, AgentBasedModel, Schedulers, add_agent!, ABM
include("CrttAgents.jl")

function initialise(num_cas,num_resc)
    model = ABM(
        Cas,
        scheduler = Schedulers.fastest,
        properties = Dict(
            :ticks => 0, 
            :dist_per_step => 50,
            :dist_from_vx => 2000,
            :dist_from_sm => 2500,
            :dist_from_hosp => 10000
        )
    )

    for i = 1:num_cas
        cas = Cas(
            i,
            rand([1,2,3]);
            dist_from_vx = model.dist_from_vx,
            dist_from_sm = model.dist_from_sm,
            dist_from_hosp = model.dist_from_hosp,
            rescued_by = 999, #just an initialised value
            at_pma = 999 # just an initialised value
        )
        add_agent!(model, Cas)
    end

    return model
end

model = initialise(100, 5)


