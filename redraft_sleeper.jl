include("functions.jl")

#println("Enter the draft ID")
id = "999801974084202496"

const GRB_ENV = Gurobi.Env(output_flag=0);

function redraft_model(team, num_teams, drafted, temp=[])
    """
    team: team number (1st round pick number)
    num_teams: number of teams in the league
    drafted: dictionary of drafted players
    temp: list of players to exclude from model

    returns: next pick, optimal roster
    """
    # create model
    model = Model(() -> Gurobi.Optimizer(GRB_ENV))
    set_optimizer_attribute(model, "TimeLimit", 300)

    # PARAMETERS
    T = num_teams # num teams
    P = size(data)[1] # num_players
    R = 16 # roster size

    #position limits on the roster
    min_qbs = 1
    max_qbs = 2
    min_rbs = 4
    max_rbs = 8
    min_wrs = 4
    max_wrs = 8
    min_tes = 1
    max_tes = 3

    #how many players we draft that are producing for our starting lineup, as opposed to being on the bench with their value going unused
    starting_qbs_now = 1
    starting_rbs_now = 2
    starting_wrs_now = 2
    starting_flex_now = 7 # includes the 4 starting RBs, WRs
    starting_tes_now = 1

    alpha = 3 # weight on starting players

    # boolean dictionary of whether or not player has been drafted by an opponent
    opps = players_drafted_opps(team, T)

    num_picked = sum(opps[i, "Drafted"] for i in 1:P) + length(drafted[team])

    # array of teams picks (THIS BREAKS IF YOU HAVE TRADES - manually insert team picks in this case)
    picks = [team, (2*T+1)-team]
    for i in 3:R
        push!(picks, picks[i-2]+(2*T))
    end

    # VARIABLES
    @variable(model, x[i = 1:P], Bin) # whether or not player was drafted by desired team
    @variable(model, y[i = 1:P], Bin) # whether or not player is "starting" in year j on your roster

    # OBJECTIVE FUNCTION
    @objective(model, Max, sum(data[i, "Y0_VORP"]*(x[i]+alpha*y[i]) for i in 1:P))

    # CONSTRAINTS
    # roster must contain already drafted num_players
    @constraint(model, [i = drafted[team]], x[player_to_index[i]] == 1)

    # roster must not contain any opps
    @constraint(model, [i=1:P], x[i]+opps[i,"Drafted"] <= 1)

    # selecting players to start only if on roster
    @constraint(model, [i = 1:P], y[i] <= x[i])

    # roster must not contain any temps
    @constraint(model, [i=1:length(temp)], x[player_to_index[temp[i]]] == 0)

    # roster must contain 26 players (no kicker/DEF)
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
    @constraint(model, sum(y[player_to_index[i]] for i in qbs) == starting_qbs_now)
    @constraint(model, sum(y[player_to_index[i]] for i in rbs) >= starting_rbs_now)
    @constraint(model, sum(y[player_to_index[i]] for i in wrs) >= starting_wrs_now)
    @constraint(model, sum(y[player_to_index[i]] for i in flex) == starting_flex_now)
    @constraint(model, sum(y[player_to_index[i]] for i in tes) == starting_tes_now)


    # DRAFT POSITION CONSTRAINTS

    #figuring out where the pool of available players begins
    first_avail = 1
    while opps[first_avail, "Drafted"] == 1
        first_avail += 1
    end

    #next pick is best available player, disregarding ADP
    @constraint(model, sum(x[i] for i in first_avail:P) >= R-length(drafted[team]))

    #future picks must only be used on players projected to still be available based on ADP
    for pick in length(drafted[team])+1:R
        @constraint(model, sum(x[i] for i in (picks[pick]-sum(opps[j, "Drafted"] for j in picks[pick]:P)):P) >= R+1-pick)
    end

    # OPTIMIZE
    # solvetime = @elapsed optimize!(model)
    optimize!(model)

    #showing roster of names (instead of numbers)

    roster = DataFrame(Name = String[], Position = String[], Pick = Int64[], ADP = Float64[])
    count = 1
    for i in drafted[team]
        if i == "QB" || i == "RB" || i == "WR" || i == "TE"
            push!(roster, [i, i, picks[count], 500])
            continue
        end
        push!(roster, [data[player_to_index[i], "Name"], data[player_to_index[i], "Position"], picks[count], data[player_to_index[i], "RedraftHalfPPR"]])
        count += 1
    end
    for i in 1:P
        if value.(x[i]) == 1
            if data[i, "Name"] in drafted[team]
                continue
            else
                push!(roster, [data[i, "Name"], data[i, "Position"], picks[count], data[i, "RedraftHalfPPR"]])
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

#set the data to be ordered by dynasty_sf ADP
data, player_to_index, qbs, rbs, wrs, tes, flex, names = initialize_data(false)

#connect to sleeper
drafted = update_draft(id)

#set params and run model for top 7 options
num_teams = 8
team = 4

first_choice, roster = redraft_model(team, num_teams, drafted);
second_choice, r2 = redraft_model(team, num_teams, drafted, [first_choice]);
third_choice, r3 = redraft_model(team, num_teams, drafted, [first_choice, second_choice])
fourth_choice, r4 = redraft_model(team, num_teams, drafted, [first_choice, second_choice, third_choice])
fifth_choice, r5 = redraft_model(team, num_teams, drafted, [first_choice, second_choice, third_choice, fourth_choice])
sixth_choice, r6 = redraft_model(team, num_teams, drafted, [first_choice, second_choice, third_choice, fourth_choice, fifth_choice])
seventh_choice, r7 = redraft_model(team, num_teams, drafted, [first_choice, second_choice, third_choice, fourth_choice, fifth_choice, sixth_choice])

println(first_choice)
println(second_choice)
println(third_choice)
println(fourth_choice)
println(fifth_choice)
println(sixth_choice)
println(seventh_choice)