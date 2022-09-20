begin
    using Pkg 
    Pkg.activate("envs/crtt")
end

include("agent_types_abm.jl")
using .AgentTypes: Cas, Resc