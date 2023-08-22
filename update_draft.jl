include("functions.jl")

#println("Enter the draft ID")
id = "999801974084202496"

const GRB_ENV = Gurobi.Env(output_flag=0);

function dynasty_sf_model(team, pv, drafted, temp=[])
    # create model
    model = Model(() -> Gurobi.Optimizer(GRB_ENV))
    set_optimizer_attribute(model, "TimeLimit", 300)

    # PARAMETERS
    T = 10 # num teams
    P = size(data)[1] # num_players
    Y = 10 # num_years projecting
    R = 26 # roster size

    alpha = 0.5 # starter weight (bench = 1, starter = 1+alpha)
    pv = 0.9 # present value of future years 
    #(0.9 = next year projections discounted by 0.9, two year out projections discounted by 0.9^2 = 0.81, etc.)
    
    min_qbs = 3
    max_qbs = 5
    min_rbs = 7
    max_rbs = 11
    min_wrs = 7
    max_wrs = 11
    min_tes = 2
    max_tes = 4

    # this year and next year as of now
    starting_qbs_now = 2
    starting_rbs_now = 3
    starting_wrs_now = 3
    starting_flex_now = 8
    starting_tes_now = 1

    #years 3-5
    starting_qbs_mid = 2
    starting_rbs_mid = 2
    starting_wrs_mid = 2
    starting_flex_mid = 6
    starting_tes_mid = 1

    #years 6-7
    starting_qbs_fut = 1
    starting_flex_fut = 4
    starting_tes_fut = 1


    opps = players_drafted_opps(team, T)

    num_picked = sum(opps[i, "Drafted"] for i in 1:P) + length(drafted[team])

    picks = [team, (2*T+1)-team]
    for i in 3:R
        push!(picks, picks[i-2]+(2*T))
    end

    # VARIABLES
    @variable(model, x[i = 1:P], Bin) # whether or not player was drafted by desired team
    @variable(model, y[i = 1:P, j = 1:Y], Bin) # whether or not player is "starting" in year j on your roster

    # OBJECTIVE FUNCTION
    @objective(model, Max, sum(data[i, j+5]*(x[i]+alpha*y[i,j])*(pv^(j-1)) for i in 1:P, j in 1:Y))

    # CONSTRAINTS
    # roster must contain already drafted num_players
    @constraint(model, [i = drafted[team]], x[player_to_index[i]] == 1)

    # roster must not contain any opps
    @constraint(model, [i=1:P], x[i]+opps[i,"Drafted"] <= 1)

    # roster must not contain any temps
    @constraint(model, [i=1:length(temp)], x[player_to_index[temp[i]]] == 0)

    # selecting players in y only if on roster
    @constraint(model, [i = 1:P, j = 1:Y], y[i,j] <= x[i])

    # roster must contain R players (no kicker/DEF)
    @constraint(model, sum(x[i] for i in 1:P) <= R)

    # positional constraints
    @constraint(model, sum(x[player_to_index[i]] for i in qbs) >= min_qbs)
    @constraint(model, sum(x[player_to_index[i]] for i in qbs) <= max_qbs)
    @constraint(model, sum(x[player_to_index[i]] for i in rbs) >= min_rbs)
    @constraint(model, sum(x[player_to_index[i]] for i in rbs) <= max_rbs)
    @constraint(model, sum(x[player_to_index[i]] for i in wrs) >= min_wrs)
    @constraint(model, sum(x[player_to_index[i]] for i in wrs) <= max_wrs)
    @constraint(model, sum(x[player_to_index[i]] for i in tes) >= min_tes)
    @constraint(model, sum(x[player_to_index[i]] for i in tes) <= max_tes)

    # starting constraints
    @constraint(model, [j = 1:2], sum(y[player_to_index[i],j] for i in qbs) == starting_qbs_now)
    @constraint(model, [j = 1:2], sum(y[player_to_index[i],j] for i in rbs) >= starting_rbs_now)
    @constraint(model, [j = 1:2], sum(y[player_to_index[i],j] for i in wrs) >= starting_wrs_now)
    @constraint(model, [j = 1:2], sum(y[player_to_index[i],j] for i in flex) == starting_flex_now)
    @constraint(model, [j = 1:2], sum(y[player_to_index[i],j] for i in tes) == starting_tes_now)

    @constraint(model, [j = 3:5], sum(y[player_to_index[i],j] for i in qbs) == starting_qbs_mid)
    @constraint(model, [j = 3:5], sum(y[player_to_index[i],j] for i in rbs) >= starting_rbs_mid)
    @constraint(model, [j = 3:5], sum(y[player_to_index[i],j] for i in wrs) >= starting_wrs_mid)
    @constraint(model, [j = 3:5], sum(y[player_to_index[i],j] for i in flex) == starting_flex_mid)
    @constraint(model, [j = 3:5], sum(y[player_to_index[i],j] for i in tes) == starting_tes_mid)

    @constraint(model, [j = 6:7], sum(y[player_to_index[i],j] for i in qbs) == starting_qbs_fut)
    @constraint(model, [j = 6:7], sum(y[player_to_index[i],j] for i in flex) == starting_flex_fut)
    @constraint(model, [j = 6:7], sum(y[player_to_index[i],j] for i in tes) == starting_tes_fut)

    @constraint(model, [j = 8:10], sum(y[i,j] for i in 1:P) >= 2)


    # DRAFT POSITION CONSTRAINTS
    #at least 1 pick from set of players after each round
    for pick in length(drafted[team])+1:R
        @constraint(model, sum(x[i] for i in (picks[pick]-sum(opps[j, "Drafted"] for j in picks[pick]:P)):P) >= R+1-pick)
    end

    # OPTIMIZE
    # solvetime = @elapsed optimize!(model)
    optimize!(model)

    roster = DataFrame(Name = String[], Position = String[], Pick = Int64[], ADP = Float64[])
    count = 1
    for i in drafted[team]
        if i == "QB" || i == "RB" || i == "WR" || i == "TE"
            push!(roster, [i, i, picks[count], 500])
            continue
        end
        push!(roster, [data[player_to_index[i], "Name"], data[player_to_index[i], "Position"], picks[count], data[player_to_index[i], "Dyn_SF"]])
        count += 1
    end
    for i in 1:P
        if value.(x[i]) == 1
            if data[i, "Name"] in drafted[team]
                continue
            else
                push!(roster, [data[i, "Name"], data[i, "Position"], picks[count], data[i, "Dyn_SF"]])
                count += 1
            end
        end
    end
    next_pick = ""
    for i in 1:P
        if value.(x[i]) == 1
            if data[i, "Name"] in drafted[team]
                continue
            else
                next_pick = data[i, "Name"]
                break
            end
        end
    end
    println("Total VORP: " * string(round(objective_value(model), digits = 1)))
    return next_pick, roster
end

data, player_to_index, qbs, rbs, wrs, tes, flex, names = initialize_data()

drafted = update_draft(id)

pv = 0.90
first_choice, roster = dynasty_sf_model(5, pv, drafted);
second_choice, r2 = dynasty_sf_model(5, pv, drafted, [first_choice]);
third_choice, r3 = dynasty_sf_model(5, pv, drafted, [first_choice, second_choice])
println(first_choice * "    " * second_choice * "    " * third_choice)