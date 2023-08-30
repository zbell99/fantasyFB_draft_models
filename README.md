Repo Last Updated: August 30, 2023

This repository creates a fantasy football optimization model as aid to drafting your team. The README will walk through the purpose of each file in the repository, as well as instruction on how to use the files.

Necessary installations to use the files in the repo:

Julia: all code is in Julia; you can install Julia at https://julialang.org/downloads/
JuMP: JuMP is a modeling language and collection of supporting packages for mathematical optimization in Julia. The installation steps can be followed at https://jump.dev/JuMP.jl/stable/installation/
Gurobi: the optimization models use Gurobi as the solver; you can install Gurobi following the steps from https://github.com/jump-dev/Gurobi.jl #note: other MI(LP) solvers should work perfectly fine with the models created.



Data:
vorp.csv: This file contains the cleaned data used for the model. For the top ~300 players eligible in the draft, the player's ADP (currently just redraft 0.5 PPR, dynasty superflex) as well as their projected Value of Positional Replacement are listed. Players have a VORP value for each of the next 20 seasons. The VORP data is from FantasyCalc - go check out their great work at https://www.fantasycalc.com/blog/dynasty-player-projections-2023!



Functions:
functions.jl: This file contains helper functions used for the models



Models:
dynasty_sf_sleeper.jl: This file connects to a Sleeper app draft and runs the dynasty superflex model. Edit the draft id, present value, and team number, as well as the more specific parameters in the model itself, and this file will output the top 7 options for your next draft pick.

redraft_sleeper.jl: Same as dynasty_sf_sleeper.jl, but using ADP for redraft league and only considering VORP of the current season

models.ipynb: This notebook has the same functionality as the sleeper files, but it allows for manual updates to the draft if you don't have a sleeper league, as well as the ability to view some of the other helper functions created in functions.jl



Extra:
links.xlsx: Links to other research in dynasty rankings and/or sequential order optimization models. Check them out!