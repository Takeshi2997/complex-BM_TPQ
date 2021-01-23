include("./setup.jl")
include("./ml_core.jl")
include("./legendreTF.jl")
using .Const, .MLcore, .LegendreTF
using LinearAlgebra, Flux

function calculate()

    dirname = "./data"
    f = open("energy_data.txt", "w")
    num = 100000
    for iϵ in 1:Const.iϵmax
        filenameparams = dirname * "/params_at_" * lpad(iϵ, 3, "0") * ".bson"
        MLcore.Func.ANN.load(filenameparams)

        energyS, energyB, numberB, variance = MLcore.calculation_energy(num)

        β = LegendreTF.calc_temperature(energyB / Const.dimB)
        # Write energy
        write(f, string(β))
        write(f, "\t")
        write(f, string(energyS / Const.dimS))
        write(f, "\t")
        write(f, string(energyB / Const.dimB))
        write(f, "\t")
        write(f, string(numberB / Const.dimB))
        write(f, "\t")
        write(f, string(variance / Const.dimS))
        write(f, "\n")
    end
    close(f)
end

calculate()


