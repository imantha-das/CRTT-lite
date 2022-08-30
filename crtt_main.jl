using Pkg
Pkg.activate("envs/crttenv")

#using Agents:AbstractAgent

include("crtt_agents.jl")
using .CrttAgents: Cas, Resc

cas = Cas(1,2)
