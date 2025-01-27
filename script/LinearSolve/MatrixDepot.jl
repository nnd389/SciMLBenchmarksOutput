
using BenchmarkTools, Random, VectorizationBase, Statistics
using LinearAlgebra, SparseArrays, LinearSolve, Sparspak
import Pardiso
using Plots
using MatrixDepot

BenchmarkTools.DEFAULT_PARAMETERS.seconds = 0.5

# Why do I need to set this ?
BenchmarkTools.DEFAULT_PARAMETERS.samples = 10

algs = [
    UMFPACKFactorization(),
    KLUFactorization(),
    MKLPardisoFactorize(),
    SparspakFactorization(),
]
algnames = ["UMFPACK", "KLU", "Pardiso", "Sparspak"]
algnames_transpose = reshape(algnames, 1, length(algnames))

cols = [:red, :blue, :green, :magenta, :turqoise] # one color per alg

# matrices = ["HB/1138_bus", "HB/494_bus", "HB/662_bus", "HB/685_bus", "HB/bcsstk01", "HB/bcsstk02", "HB/bcsstk03", "HB/bcsstk04",  "HB/bcsstk05", "HB/bcsstk06", "HB/bcsstk07", "HB/bcsstk08", "HB/bcsstk09", "HB/bcsstk10", "HB/bcsstk11", "HB/bcsstk12", "HB/bcsstk13", "HB/bcsstk14", "HB/bcsstk15", "HB/bcsstk16"]
allmatrices_md = listnames("*/*")

@info "Total number of matrices: $(allmatrices_md.content[1].rows)"
times = fill(NaN, length(allmatrices_md.content[1].rows), length(algs))
percentage_sparsity = fill(NaN, length(allmatrices_md.content[1].rows))
matrix_size = fill(NaN, length(allmatrices_md.content[1].rows))


for z in 1:length(allmatrices_md.content[1].rows)
    try
        matrix = allmatrices_md.content[1].rows[z]
        matrix = string(matrix[1])

        currMTX = matrix

        rng = MersenneTwister(123)
        A = mdopen(currMTX).A
        A = convert(SparseMatrixCSC, A)
        n = size(A, 1)
        matrix_size[z] = n
        percentage_sparsity[z] = length(nonzeros(A)) / n^2
        @info "$n × $n"

        n > 100 && error("Skipping too large matrices")

        b = rand(rng, n)
        u0 = rand(rng, n)

        for j in 1:length(algs)
            bt = @belapsed solve(prob, $(algs[j])).u setup=(prob = LinearProblem(copy($A),
                copy($b);
                u0 = copy($u0),
                alias_A = true,
                alias_b = true))
            times[z,j] = bt
        end

        #=
        p = bar(algnames, times[z, :];
            ylabel = "Time/s",
            yscale = :log10,
            title = "Time on $(currMTX)",
            fmt = :png,
            legend = :outertopright)
        display(p)
        =#

        println("successfully factorized $(currMTX)")
    catch e
        matrix = allmatrices_md.content[1].rows[z]
        matrix = string(matrix[1])

        currMTX = matrix

        println("$(currMTX) failed to factorize.")
        println(e)
    end
end


meantimes = vec(mean(times, dims=1))
p = bar(algnames, meantimes;
    ylabel = "Time/s",
    yscale = :log10,
    title = "Mean factorization time",
    fmt = :png,
    legend = :outertopright)


p = scatter(percentage_sparsity, times;
    ylabel = "Time/s",
    yscale = :log10,
    xlabel = "Percentage Sparsity",
    xscale = :log10,
    label = algnames_transpose,
    title = "Factorization Time vs Percentage Sparsity",
    fmt = :png,
    legend = :outertopright)


p = scatter(matrix_size, times;
    ylabel = "Time/s",
    yscale = :log10,
    xlabel = "Matrix Size",
    xscale = :log10,
    label = algnames_transpose,
    title = "Factorization Time vs Matrix Size",
    fmt = :png,
    legend = :outertopright)


using SciMLBenchmarks
SciMLBenchmarks.bench_footer(WEAVE_ARGS[:folder],WEAVE_ARGS[:file])

