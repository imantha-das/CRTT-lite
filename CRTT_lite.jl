using Pkg
Pkg.activate("envs/abmEnv")
using Base: Bool, @kwdef, end_base_include, color_normal
using Agents
using GLMakie 
using InteractiveDynamics
using Distributions: Normal


mutable struct CasAgent <: AbstractAgent
    id::Int
    pos::Dims{2}
    TS::Int64 
    dist_from_iz::Float64 
    targeted::Bool
    awaiting_rescue::Bool 
    on_route_pma::Bool 
    awaiting_stabilisation::Bool 
    in_stabilisation::Bool 
    awaiting_hospital_transfer::Bool
    on_route_hospital::Bool 
    awaiting_treatment::Bool 
    in_treatment_NBB::Bool 
    in_treatment_BB::Bool 
    deceased::Bool
end

CasAgent(id, pos; TS, dist_from_iz, targeted, awaiting_rescue, on_route_pma, awaiting_stabilisation, in_stabilisation, awaiting_hospital_transfer, on_route_hospital, awaiting_treatment, in_treatment_NBB, in_treatment_BB, deceased) = CasAgent(id, pos, TS, dist_from_iz, targeted,  awaiting_rescue, on_route_pma, awaiting_stabilisation, in_stabilisation, awaiting_hospital_transfer, on_route_hospital, awaiting_treatment, in_treatment_NBB, in_treatment_BB, deceased)

@kwdef mutable struct RescAgent 
    id::Int
    targeted_agent::Bool = false
    rescued_cas::Array{CasAgent} = Array{CasAgent}([])
    dist_to_target::Float64 = NaN
    mode::String = "searching"
end


function initialize(;num_ts1 = 75, num_ts2 = 75, num_ts3 = 75)
    dims_rqd = sqrt(num_ts1 + num_ts2 + num_ts3) |> ceil |> Int
    space = GridSpace((dims_rqd, dims_rqd), periodic = false)
    model = AgentBasedModel(
        CasAgent, 
        space,
        scheduler = random_activation
    )

    ts_array = vcat(map(x -> 1, 1:num_ts1), map(x -> 2, 1:num_ts2), map(x -> 3, 1:num_ts3))

    for idx = 1:length(ts_array)
        add_agent!(
            model,
            TS = ts_array[idx],
            dist_from_iz = rand(Normal(500,100)),
            targeted = false,
            awaiting_rescue = true,
            on_route_pma = false,
            awaiting_stabilisation = false,
            in_stabilisation = false,
            awaiting_hospital_transfer = false,
            on_route_hospital = false,
            awaiting_treatment = false,
            in_treatment_NBB = false,
            in_treatment_BB = false,
            deceased = false
        )
    end
    return model
end

model = initialize()
model.agents

# ----------------------------------------------------------------------------------------------------------
# Plotting

# Function to define shape of agents TS1 = ⊚ | TS2 = ▦ | TS3 = ⬥ |
function ashape(a)
    if a.TS == 1
        return :circle
    elseif a.TS == 2
        return :rect
    else
        return :diamond
    end
end

# Function to define color 
function acolor(a)
    if (a.awaiting_rescue == true) && (a.deceased == false)
        return :indianred
    elseif (a.on_route_pma == true) && (a.deceased == false) 
        return :fuchsia
    elseif (a.awaiting_stabilisation == true) && (a.deceased == false)
        return :lightseagreen
    elseif (a.in_stabilisation == true) && (a.deceased == false)
        return :lawngreen
    elseif (a.awaiting_hospital_transfer == true) && (a.deceased == false)
        return :limegreen
    elseif (a.on_route_hospital == true) && (a.deceased == false)
        return :bisque 
    elseif (a.awaiting_treatment == true) && (a.deceased == false)
        return :lightsteelblue
    elseif (a.in_treatment_NBB == true) && (a.deceased == false)
        return :dodgerblue
    elseif (a.in_treatment_BB == true) && (a.deceased == false)
        return :steelblue 
    else
        return :slategray
    end
end

plotkwargs = (
    as = 15,
    am = ashape,
    ac = acolor
)



fig,_ = abm_plot(model; plotkwargs...)
display(fig)
