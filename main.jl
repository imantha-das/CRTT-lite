using Pkg
Pkg.activate("envs/abm")
using Agents: AbstractAgent, AgentBasedModel, Schedulers, add_agent!, ABM, nagents
include("CrttAgents.jl")

function initialise(num_cas,num_resc)
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
    for i = nagents(model):nagents(model) + num_resc
        resc = Resc(
            i
        )
        add_agent!(resc,model)
    end

    return model
end

model = initialise(20,5)




