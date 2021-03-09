
[![Latest](https://img.shields.io/badge/docs-latest-blue.svg)](https://mschauer.github.io/CausalInference.jl/latest/)
	
# Causalinference.jl

Julia package for causal inference, graphical models and structure learning.

This package contains code for the stable version of the PC algorithm and the FCI algorithm as described in Zhang's article.

The algorithms use the Julia packages [LightGraphs](https://github.com/JuliaGraphs/LightGraphs.jl) and [MetaGraphs](https://github.com/JuliaGraphs/MetaGraphs.jl). Graphs are represented by sorted adjacency lists (vectors in the implementation). CPDAGs are just `DiGraph`s where unoriented edges are represented by both a forward and a backward directed edge. PAGs are `MetaDiGraph`s where every edge is represented by a forward and a backward edge. The marks of the endpoint of an edge are stored in the `:marks` property. Marks can be checked and set using the `has_marks` and `set_marks!` functions (see documentation for details).

The PC algorithm is tested on random DAGs by comparing the result of the PC algorithm using the *d*-separation oracle with CPDAGs computed with Chickering's DAG->CPDAG conversion algorithm (implemented as `dsep` and `cpdag` in this package).

See the [documentation](https://mschauer.github.io/CausalInference.jl/latest/) for other implemented functionality and [issue #1 (Roadmap/Contribution)](https://github.com/mschauer/CausalInference.jl/issues/1) for coordination of the development.

# Examples

A few example data sets can be useful to illustrate how to work with the PC algorithm and the different independence tests implemented in this package. The examples discussed here are based on the example models discussed in chapter 2 of Judea Pearl's book. The causal model we are going to study can be represented using the following DAG:

![True example DAG](true_graph.png)

We can easily create some sample data that corresponds to the causal structure described by the DAG. For the sake of simplicity, let's create data from a simple linear model that follows the structure defined by the DAG shown above:

```Julia
# Generate some sample data to use with the PC algorithm

N = 1000 # number of data points

# define simple linear model with added noise
x = randn(N)
v = x + randn(N)*0.25
w = x + randn(N)*0.25
z = v + w + randn(N)*0.25
s = z + randn(N)*0.25

df = (x=x, v=v, w=w, z=z, s=s)
```

With this data ready, we can now see to what extent we can back out the underlying causal structure from the data using the PC algorithm. Under the hood, the PC algorithm uses repeated conditional independence tests to determine the causal influence between different variables in a data set. In order to run the PC algorithm on our test data set, we need to specify not only the data set we want to use, but also the conditional independence test alongside a p-value. For now, let's use a simple Gaussian conditional independence test with a p-value of 0.01. 

```Julia
est_g = pcalg(df, 0.01, gausscitest)
```

In order to investigate the output of the PC algorithm, this package also provides a function to easily plot and visually analyse this output.

```Julia
variables = [String(k) for k in keys(df)]
tp = plot_pc_dag(est_g, variables)
```



![Dag from the example](https://raw.githubusercontent.com/mschauer/CausalInference.jl/master/exampledag.png)

Not all causal directions are indentified (and identifiable) in this example, and visualized by edges with circled/unknown arrow marks.

But we can conclude without intervention from observations alone that for example `W` and `V` are causal for `Z` and `Z` for `S`.

# FAQ

**Q:** I looked for "causal inference" and found [CausalInference.jl](.) and [Omega.jl](http://www.zenna.org/Omega.jl/latest/causal/)... **A:** CausalInference.jl is about causal discovery, you observe the data and want to infer the causal structure. Omega lets you reason what happens then: when you intervene ("do calculus") and want to cause changes.

# References

* P. Spirtes, C. Glymour, R. Scheines, R. Tillman: Automated search for causal relations: Theory and practice. *Heuristics, Probability and Causality: A Tribute to Judea Pearl* 2010
* P. Spirtes, C. Glymour, R. Scheines: Causation, Prediction, and Search. *MIT Press* 2000
* J. Zhang: On the completeness of orientation rules for causal discovery in the presence of latent confounders and selection bias. *Artificial Intelligence* 16-17 (2008), 1873-1896
* T. Richardson, P. Spirtes: Ancestral Graph Markov Models. *The Annals of Statistics* 30 (2002), 962-1030
* D. M. Chickering: Learning Equivalence Classes of Bayesian-Network Structures. *Journal of Machine Learning Research* 2 (2002), 445-498.
* D. Colombo, M. H. Maathuis: Order-Independent Constraint-Based Causal Structure Learning. *Journal of Machine Learning Research* 15 (2014), 3921-3962.


