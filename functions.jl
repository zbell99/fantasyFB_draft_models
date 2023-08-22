using DataFrames, CSV, JuMP, Gurobi, Random, LibPQ, Statistics
using HTTP, JSON

function initialize_data(dynasty = true)
    #data = projections for each player
    data = DataFrame(CSV.File("dynasty_data.csv"))
    #fill missing with 0 in julia
    replace!(data.Dyn_SF, missing => 500)
    replace!(data.RedraftHalfPPR, missing => 500)
    data.Name .= data.FirstName .* " " .* data.LastName
    if dynasty
        sort!(data, :Dyn_SF)
    else
        sort!(data, :RedraftHalfPPR)
    end

    player_to_index = Dict()
    #iterate thorugh each row in the data
    for i in 1:size(data)[1]
        #get the player name
        player = data[i, :Name]
        #if the player is not in the dictionary, add them
        player_to_index[player] = i
    end

    qbs = Set()
    rbs = Set()
    wrs = Set()
    tes = Set()
    flex = Set()
    names = Set()

    for player in eachrow(data)
        push!(names, player.Name)
        if player.Position == "QB"
            push!(qbs, player.Name)
        elseif player.Position == "RB"
            push!(rbs, player.Name)
            push!(flex, player.Name)
        elseif player.Position == "WR"
            push!(wrs, player.Name)
            push!(flex, player.Name)
        elseif player.Position == "TE"
            push!(tes, player.Name)
        end
    end
    return data, player_to_index, qbs, rbs, wrs, tes, flex, names
end

function reset_draft(num_teams)
    drafted = Dict()
    for i in range(1, num_teams)
        drafted[i] = []
    end
    return drafted
end

function just_drafted(player, team, num_teams)
    if length(filter(:Name => n -> n == player, data)[!,1]) < 1
        return "Player not found"
    end
    if team < 1 || team > num_teams
        return "Team not found"
    end
    for i in 1:num_teams
        if player in drafted[i]
            return "Player already drafted"
        end
    end
    push!(drafted[team], player)
    return "Team " * string(team) * " drafted " * player * "!"
end

function players_drafted_opps(team, num_teams)
    drafted_opps = DataFrame(Name = data.Name, Drafted = fill(false, size(data)[1]))
    for i in 1:num_teams
        if i == team
            continue
        else
            for player in drafted[i]
                if player == "QB" || player == "RB" || player == "WR" || player == "TE"
                    continue
                end
                drafted_opps[player_to_index[player], "Drafted"] = true
            end
        end
    end
    return drafted_opps
end

function draft_board(num_teams, num_rounds)
    if num_teams == 8
        board = DataFrame(T1 = String[], T2 = String[], T3 = String[], T4 = String[], T5 = String[], T6 = String[], T7 = String[], T8 = String[])
        for i in 1:num_rounds
            push!(board, ["", "", "", "", "", "", "", ""])
        end
    elseif num_teams == 10
        board = DataFrame(T1 = String[], T2 = String[], T3 = String[], T4 = String[], T5 = String[], T6 = String[], T7 = String[], T8 = String[], T9 = String[], T10 = String[])
        for i in 1:num_rounds
            push!(board, ["", "", "", "", "", "", "", "", "", ""])
        end
    else #num_teams == 12
        board = DataFrame(T1 = String[], T2 = String[], T3 = String[], T4 = String[], T5 = String[], T6 = String[], T7 = String[], T8 = String[], T9 = String[], T10 = String[], T11 = String[], T12 = String[])
        for i in 1:num_rounds
            push!(board, ["", "", "", "", "", "", "", "", "", "", "", ""])
        end
    end
    
    for team in 1:num_teams
        num = 1
        for player in drafted[team]
            board[team, num] = player
            num += 1
        end
    end
    return board
end

function view_roster(team)
    roster = DataFrame(Position = String[], Player = String[])
    push!(roster, ["QB1", ""])
    push!(roster, ["QB2", ""])
    push!(roster, ["RB1", ""])
    push!(roster, ["RB2", ""])
    push!(roster, ["WR1", ""])
    push!(roster, ["WR2", ""])
    push!(roster, ["TE", ""])
    push!(roster, ["FLEX", ""])
    push!(roster, ["FLEX", ""])
    push!(roster, ["Bench", ""])
    push!(roster, ["Bench", ""])
    push!(roster, ["Bench", ""])
    push!(roster, ["Bench", ""])
    push!(roster, ["Bench", ""])
    push!(roster, ["Bench", ""])
    push!(roster, ["Bench", ""])
    push!(roster, ["Bench", ""])
    push!(roster, ["Bench", ""])
    push!(roster, ["Bench", ""])
    push!(roster, ["Bench", ""])
    push!(roster, ["Bench", ""])
    push!(roster, ["Bench", ""])
    push!(roster, ["Bench", ""])
    push!(roster, ["Bench", ""])
    push!(roster, ["Bench", ""])
    push!(roster, ["Bench", ""])

    qb_spots = [1, 2, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26]
    rb_spots = [3, 4, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26]
    wr_spots = [5, 6, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26]
    te_spots = [7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26]

    for player in drafted[team]
        if player == "QB"
            for spot in qb_spots
                if roster[spot, "Player"] == ""
                    roster[spot, "Player"] = player
                    break
                end
            end
            continue
        elseif player == "RB"
            for spot in rb_spots
                if roster[spot, "Player"] == ""
                    roster[spot, "Player"] = player
                    break
                end
            end
            continue
        elseif player == "WR"
            for spot in wr_spots
                if roster[spot, "Player"] == ""
                    roster[spot, "Player"] = player
                    break
                end
            end
            continue
        elseif player == "TE"
            for spot in te_spots
                if roster[spot, "Player"] == ""
                    roster[spot, "Player"] = player
                    break
                end
            end
            continue
        end
        player_pos = data[player_to_index[player], "Position"]
        if player_pos == "QB"
            for spot in qb_spots
                if roster[spot, "Player"] == ""
                    roster[spot, "Player"] = player
                    break
                end
            end
        elseif player_pos == "RB"
            for spot in rb_spots
                if roster[spot, "Player"] == ""
                    roster[spot, "Player"] = player
                    break
                end
            end
        elseif player_pos == "WR"
            for spot in wr_spots
                if roster[spot, "Player"] == ""
                    roster[spot, "Player"] = player
                    break
                end
            end
        elseif player_pos == "TE"
            for spot in te_spots
                if roster[spot, "Player"] == ""
                    roster[spot, "Player"] = player
                    break
                end
            end
        end
    end
    return roster
end

function update_draft(id)
    url = "https://api.sleeper.app/v1/draft/" *id*"/picks"
    response = HTTP.get(url)
    response_body = String(response.body)
    parsed_json = JSON.parse(response_body)
    drafted = reset_draft(10) #MIGHT NEED EDITING
    for pick in parsed_json
        team = Int64(pick["draft_slot"])
        position = pick["metadata"]["position"]
        name = pick["metadata"]["first_name"] * " " * pick["metadata"]["last_name"]
        name = replace(name, "." => "")
        if name in names
            push!(drafted[team], name)
        else
            push!(drafted[team], position)
        end
    end
    return drafted
end