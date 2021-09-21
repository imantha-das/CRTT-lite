using Agents
using Distributions: Normal
using GLMakie
using InteractiveDynamics

# Casualty Agents
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

CasAgent(id, pos; TS, dist_from_med_fac, targeted, awaiting_rescue, on_route_pma, awaiting_stabilisation, in_stabilisation, awaiting_hospital_transfer, on_route_hospital, awaiting_treatment, in_treatment_NBB, in_treatment_BB, deceased) = CasAgent(id, pos, TS, dist_from_med_fac, targeted,  awaiting_rescue, on_route_pma, awaiting_stabilisation, in_stabilisation, awaiting_hospital_transfer, on_route_hospital, awaiting_treatment, in_treatment_NBB, in_treatment_BB, deceased)

mutable struct RescAgent
    id::Int
    mode::String
    targeted_cas:: Any
    rescued_cas:: Array{CasAgent}
    dist:: Float64 
end

RescAgent(id; mode, targeted_cas, rescued_cas, dist) = RescAgent(id, mode, targeted_cas, rescued_cas, dist)


function initialize(; num_ts1, num_ts2, num_ts3, num_resc, dist_from_med_fac, speed)

    # Define model properties
    dims_rqd = sqrt(num_ts1 + num_ts2 + num_ts3) |> ceil |> Int
    space = GridSpace((dims_rqd, dims_rqd), periodic = false)

    dist_traveled_per_minute = speed * (1000/60)

    properties = Dict(
        :resc => Array{RescAgent}([]), 
        :dist_traveled => dist_traveled_per_minute
    )

    model = AgentBasedModel(
        CasAgent,
        space,
        properties = properties,
        scheduler = Schedulers.randomly,
        
    )

    # Add Casualties into the model
    ts_array = vcat(map(x -> 1, 1:num_ts1), map(x -> 2, 1:num_ts2), map(x -> 3, 1:num_ts3))

    for idx = 1:length(ts_array)
        add_agent!(
            model,
            TS = ts_array[idx],
            dist_from_med_fac = dist_from_med_fac + rand(Normal(1000,500)),
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

    # All casualty agents
    cas_TS23 =  filter(x -> ((model.agents[x].TS == 2) && (model.agents[x].targeted == false)) || ((model.agents[x].TS == 3) && (model.agents[x].targeted == false)), model.agents |> keys)
    cas_TS1 = filter(x -> ((model.agents[x].TS == 1) && (model.agents[x].targeted == false)), model.agents |> keys)

    cas_TS23 = [i for i in cas_TS23]
    cas_TS1 = [i for i in cas_TS1]


    # Add Rescuers in to the model
    for i = 1:num_resc
        if !isempty(cas_TS23)
            r = RescAgent(i, mode = "active", targeted_cas = cas_TS23[1], rescued_cas = [], dist = dist_from_med_fac + model.agents[cas_TS23[1]].dist_from_iz)
            model.agents[cas_TS23[1]].targeted = true
            popfirst!(cas_TS23)
            push!(model.resc, r)
        elseif !isempty(cas_TS1)
            r = RescAgent(i, mode = "active", targeted_cas = cas_TS1[1], rescued_cas = [], dist = dist_from_med_fac + model.agents[cas_TS1[1]].dist_from_iz)
            model.agents[cas_TS1[1]].targeted = true
            popfirst!(cas_TS1)
            push!(model.resc, r)
        else
            r = RescAgent(i, mode = "inactive", targeted_cas = NaN, rescued_cas = [], dist = dist_from_med_fac)
            push!(model.resc, r)
        end
    end

    return model
end

model = initialize(num_ts1 = 25,num_ts2 =25,num_ts3 =25,num_resc = 25, dist_from_med_fac = 10000, speed = 30)

@doc """
    -- Inputs : model
    -- Reduce a unit distance from RescAgent dist value
""" ->
function update_active_resc(model)
    # Filter active agents

    for r_agent in model.resc
        if r_agent.mode == "active" && r_agent.dist > 0
            r_agent.dist -= model.dist_traveled
        elseif r_agent.mode == "active" && r_agent.dist < 0
            r_agent.mode = "at iz"
        else 

        end
    end
end


function agent_step!(agent, model; dist_per_tick = 500)
    # Make active agents take one step closer towards i

end

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
