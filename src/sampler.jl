using Revise
using LinearAlgebra
using CausalInference
using CausalInference.Graphs
using StatsBase
using ProgressMeter
const as_pairs = vpairs
using Random
Random.seed!(2)

include("mcs.jl")

using CausalInference: isadjacent, tails_and_adj_neighbors, adj_neighbors, isclique, Insert!, Delete!
using CausalInference: isundirected, parents, meek_rule1, meek_rule2, meek_rule3, meek_rule4, children, 
    neighbors_adjacent, neighbors_undirected
using CausalInference.Combinatorics
const adjacents = neighbors_adjacent

"""
    keyedreduce(op, key::AbstractVector{T}, a, init=0.0) where T

Similar to `countmap` returning a dictionary mapping unique key in `key` to the 
reduction the given collection itr with the given binary operator `op`.

```
julia> keyedreduce(+, [:a, :b, :a], [7, 3, 2])
Dict{Symbol, Float64} with 2 entries:
  :a => 9.0
  :b => 3.0
```
"""
function keyedreduce(op, key::AbstractVector{T}, a, init=0.0) where T
    cm = Dict{T,typeof(init)}()
    for (v, τ) in zip(key, a)
        index = Base.ht_keyindex2!(cm, v)
        if index > 0
            @inbounds cm.vals[index] = op(cm.vals[index] , τ)
        else
            @inbounds Base._setindex!(cm, op(init, τ), v, -index)
        end
    end
    return cm
end

"""
    ne_undirected(g)

Number of undirected edges in a PDAG represented as DiGraph.
"""
function ne_undirected(g)
    s = 0
    for x in vertices(g)
        for y in vertices(g)
            y < x && continue
            s += isadjacent(g, x, y)
        end
    end
    s
end

isblocked(g, x, y, nodesRemoved) = !has_a_path(g, [x], y, nodesRemoved)

ncpdags = [1, 2, 11, 185, 8782, 1067825, 312510571, 212133402500, 326266056291213, 1118902054495975181, 8455790399687227104576, 139537050182278289405732939, 4991058955493997577840793161279]

"""
    nup(g, total)

Number of directed edges that can be add to a PDAG `g` with `total` number of edges.
"""
nup(g, total) = nup(nv(g), total)
nup(n::Int, total) = 2*(n*(n - 1)÷2 - total) # twice as number of undirected edges

"""
    ndown(g, total)

Number of edges that can be removed from a `pdag` counting undirected edges twice.
"""
ndown(g, total) = ne(g)



function exact(g, κ, dir=:both) 
    s1, s2, _ = exact2(g, κ, dir)
    -s1 + s2
end

"""
    exact2(g, κ, dir=:both)

Return 
"""
function exact2(g, κ, dir=:both)
    s1 = s2 = 0.0
    x1 = y1 = x2 = y2 = 0
    T1 = Int[]
    H2 = Int[] 
    for x in vertices(g)
        for y in vertices(g)
            x == y && continue
            if !isadjacent(g, x, y) && dir != :down
                if length(neighbors_adjacent(g, x)) < κ && length(neighbors_adjacent(g, y)) < κ 
                    Tyx, NAyx = tails_and_adj_neighbors(g, x, y)
                    for i in 0:2^length(Tyx) - 1
                        T = Tyx[digits(Bool, i, base=2, pad=length(Tyx))]
                        NAyxT = CausalInference.sorted_union_(NAyx, T)
                        valid = (isclique(g, NAyxT) && isblocked(g, y, x, NAyxT))
                        if valid && rand() > s1/(s1 + 1) # sequentially draw sample
                            x1, y1 = x, y
                            T1 = T
                        end
                        s1 = s1 + valid
                    end
                end
            elseif has_edge(g, x, y) && dir != :up
                Hyx = adj_neighbors(g, x, y)
                for i in 0:2^length(Hyx) - 1
                    mask = digits(Bool, i, base=2, pad=length(Hyx))
                    H = Hyx[mask] 
                    NAyx_H = Hyx[map(~, mask)] 
                    valid = isclique(g, NAyx_H)
                    if valid && rand() > s2/(s2 + 1)
                        x2, y2 = x, y
                        H2 = H
                    end
                    s2 = s2 + valid 
                end
            end 
        end
    end
    s1, s2, (x1, y1, T1), (x2, y2, H2)
end

function randcpdag(n, G = (DiGraph(n), 0); σ = 0.0, ρ = 1.0,
                        κ = min(n - 1, 10), iterations=10, verbose=false)
    g, total = G
    if κ >= n 
        κ = n - 1
        @warn "Truncate κ to $κ"
    end
    total = 0
    gs = Vector{Tuple{typeof(g),Float64,Int,Int}}()
    dir = 1
    τ = 0.0
    @showprogress for iter in 1:iterations
        τ = 0.0
        total_old = total
        dir_old = dir
        
        s1, s2, up1, down1 = exact2(g, κ)
        λbar = max(dir*(-s1 + s2), 0.0)
        λrw = (s1 + s2) 
        λup = s1   
        λ = dir == 1 ? abs(s1) : abs(s2)

        while true 

            Δτ = randexp()/(ρ*λ)
            Δτrw = randexp()/(σ*λrw)
            Δτflip = randexp()/(ρ*λbar)
            τ += min(Δτ, Δτflip, Δτrw)
            if isinf(τ) 
                error("$Δτ, $Δτrw, $Δτflip")
            end
            if Δτflip < Δτ &&  Δτflip < Δτrw 
                @goto flip
            end
            up = rand() < λup/λrw           
         
            if  (Δτ < Δτrw  && dir == 1) || (Δτ > Δτrw  && up)

                local x, y
                x, y, T = up1
                @assert x != y
                push!(gs, (g, τ, dir, total))
                total += 1
		h = next_CPDAG(g, :up, x, y, T)
                #g = copy(g)
                #Insert!(g, x, y, T)
                #vskel!(g)
                #meek_rules!(g)
		#@assert g == h
                break
            else
                x, y, H = down1
                @assert x != y
                push!(gs, (g, τ, dir, total))
                total -= 1
		h = next_CPDAG(g, :down, x, y, H)
                #g = copy(g)
                #Delete!(g, x, y, H)
                #vskel!(g)
                #meek_rules!(g)
		#@assert g == h
                break
            end
            @label flip
            dir *= -1
            push!(gs, (g, τ, dir, total))
            break            
        end # break
        verbose && println(total_old, dir_old == 1 ? "↑" : "↓", total, " ", round(τ, digits=8))
        verbose && println("\t", vpairs(g))
    end
    gs
end

iterations = 10_000; verbose = false
n = 50 # vertices
κ = n - 1 # max degree
reversible_too = true # do baseline 
#iterations = 50; verbose = true
burnin = iterations÷2
gs = @time randcpdag(n; ρ=1.0, σ=0.0, κ, iterations, verbose)[burnin:end]

graphs = first.(gs)
graph_pairs = as_pairs.(graphs)
hs = hsnonrev = map(last, gs)

i = rand(eachindex(hs))
g, h = graphs[i], hs[i]

τs = map(x->getindex(x, 2), gs)
ws = wsnonrev = normalize(τs, 1)

if reversible_too
    gsrev = @time randcpdag(n; ρ=0.0, σ=1.0, κ, iterations, verbose)[burnin:end]
    hsrev = map(last, gsrev)
    τsrev = map(x->getindex(x, 2), gsrev)
    wsrev = normalize(τsrev, 1)
end

@show sum(τs)
cm = keyedreduce(+, graph_pairs, ws)
dirs = map(x->getindex(x, 3), gs)
cm2 = keyedreduce(+, graph_pairs, ws .* dirs)

println("# cpdags: $( n ≤ length(ncpdags) ? ncpdags[n] : "NA") (true), $(length(cm)) (sampled) " )
println("prob: ", n ≤ length(ncpdags) ? round(1/(ncpdags[n]), sigdigits=3) : "NA"," (true), ", extrema(values(cm)), "(estimates) " )

n ≤ length(ncpdags) && println("rmse ", norm(values(cm) .- 1/(ncpdags[n])))
println("mean repetitions ", mean(rle(hash.(graph_pairs))[2]))


function figure() 
    fig = Figure()
    ax1 = fig[1,1] = Axis(fig)
    ax2 = fig[2,1] = Axis(fig)
    r1 = eachindex(hsnonrev)[end-2000:end]
    
    stairs!(ax1, cumsum(wsnonrev[r1]), hsnonrev[r1], step=:post)
    lines!(ax2, autocor(hsnonrev))

    if @isdefined hsrev 
        r2 = eachindex(hsrev)[end-2000:end]
        stairs!(ax1, cumsum(wsrev[r2]), hsrev[r2], color=:orange, step=:post)
        lines!(ax2, autocor(hsrev))
    end

    ylims!(ax1, 0, n*(n-1)÷2)


    fig
end
# using GLMakie
@isdefined(Figure) && (fig = figure(); display(fig))

cm
