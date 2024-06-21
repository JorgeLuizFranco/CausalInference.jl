using HTTP, CSV, DataFrames
#using CausalInference
#using TikzGraphs
# If you have problems with TikzGraphs.jl, 
# try alternatively plotting backend GraphRecipes.jl + Plots.jl
# and corresponding plotting function `plot_pc_graph_recipes`
#using CausalInference
import CausalInference as CI

url = "https://www.ccd.pitt.edu//wp-content/uploads/files/Retention.txt"

df = DataFrame(CSV.File(HTTP.get(url).body))

# for now, pcalg and fcialg only accepts Float variables...
# this should change soon hopefully
for name in names(df)
	df[!, name] = convert(Array{Float64,1}, df[!,name])
end

# make variable names a bit easier to read
variables = map(x->replace(x,"_"=>" "), names(df))

est_g = pcalg(df, 0.025, gausscitest)

est_dag= pdag2dag!(est_g)

scm= estimate_equations(df,est_dag)

display(scm)

#println(CI.SCM)

df_generated= DataFrame(generate_data(scm, 2000))

println("df: ")

display(df)

println("df_generated: ")



display(DataFrame(df_generated[:, sortperm(names(df_generated))]))