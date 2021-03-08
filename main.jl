include("./setup.jl")
include("./init/ml_init.jl")
include("./calc/ml_core.jl")
using .Const, .MLinit, .MLcore
using Flux

function learning(iϵ::Integer, dirname::String, dirnameerror::String, it_num::Integer, lr::Float32)
    # Initialize
    error   = 0f0
    energyS = 0f0
    energyB = 0f0
    numberB = 0f0
    ϵ = -0.4f0 * iϵ / Const.iϵmax * Const.t * Const.dimB
    filenameparams = dirname * "/params_at_" * lpad(iϵ, 3, "0") * ".bson"
    filename = dirnameerror * "/error" * lpad(iϵ, 3, "0") * ".txt"
    MLcore.Func.ANN.load(dirname * "/params_at_000.bson")
    touch(filename)

    # Learning
    for n in 1:it_num
        energy, energyS, energyB, numberB = MLcore.sampling(ϵ, lr)
        error = ((energy - ϵ) / (Const.dimS + Const.dimB))^2 / 2f0
        open(filename, "a") do io
            write(io, string(n))
            write(io, "\t")
            write(io, string(error))
            write(io, "\t")
            write(io, string(energyS / Const.dimS))
            write(io, "\t")
            write(io, string(energyB / Const.dimB))
            write(io, "\t")
            write(io, string(numberB / Const.dimB))
            write(io, "\n")
        end
    end

    MLcore.Func.ANN.save(filenameparams)
end

function initialize(dirname::String, dirnameerror::String, n::Integer, lr::Float32)
    # Initialize
    filenameparams = dirname * "/params_at_000.bson"
    filename = dirnameerror * "/error000.txt"
    dirnameonestep = dirnameerror * "/step"
    mkdir(dirnameonestep)
    MLinit.Func.ANN.load_f(dirname * "/params_at_000.bson")
 
    # Learning
    touch(filename)
    for it in 1:n
        MLinit.Func.ANN.load(dirname * "/params_at_000.bson")
        # Calculate expected value
        energy, energyS, energyB, numberB = MLinit.initialize(lr, dirnameonestep, it)
        open(filename, "a") do io
            write(io, string(it))
            write(io, "\t")
            write(io, string(energy  / (Const.dimS + Const.dimB)))
            write(io, "\t")
            write(io, string(energyS / Const.dimS))
            write(io, "\t")
            write(io, string(energyB / Const.dimB))
            write(io, "\t")
            write(io, string(numberB / Const.dimB))
            write(io, "\n")
        end
    end

    MLinit.Func.ANN.save(filenameparams)
end

function main()

    dirname = "./data"
    rm(dirname, force=true, recursive=true)
    mkdir(dirname)
    dirnameerror = "./error"
    rm(dirnameerror, force=true, recursive=true)
    mkdir(dirnameerror)
    MLinit.Func.ANN.init()
    MLinit.Func.ANN.save(dirname * "/params_at_000.bson")
    initialize(dirname, dirnameerror, 10, Const.lr)
    map(iϵ -> learning(iϵ, dirname, dirnameerror, Const.it_num, Const.lr), 1:Const.iϵmax)
end

main()

