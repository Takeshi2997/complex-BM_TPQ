module MLcore
include("./setup.jl")
include("./functions.jl")
include("./legendreTF.jl")
using .Const, .Func, .LegendreTF

function entropy_enhancement(lr::Float32)

    x = rand([1f0, -1f0], Const.dimB+Const.dimS)
    y = rand([1f0, -1f0], Const.dimB+Const.dimS)
    xdata = Vector{Vector{Float32}}(undef, Const.iters_num)
    ydata = Vector{Vector{Float32}}(undef, Const.iters_num)
    for i in 1:Const.burnintime
        Func.update(x)
        Func.update(y)
    end
    for i in 1:Const.burnintime
        Func.update(x)
        Func.update(y)
        xdata[i] = x
        ydata[i] = y
    end

    entropy = 0f0
    energyS = 0f0
    energyB = 0f0
    numberB = 0f0
    Func.ANN.initS()
    for i in 1:Const.iters_num

        x = xdata[i]
        eS = Func.energyS(x)
        eB = Func.energyB(x)
        energyS += eS
        energyB += eB
        numberB += sum(x[1:Const.dimB])
        for j in 1:Const.iters_num
            y = ydata[j]
            s  = Func.entropy(x, y)
            entropy += s
            Func.ANN.init_backward(x, y, s)
        end
    end
    entropy  = real(entropy) / Const.iters_num^2
    energyS  = real(energyS) / Const.iters_num
    energyB  = real(energyB) / Const.iters_num
    numberB /= Const.iters_num

    Func.ANN.init_update(entropy, lr)

    entropy = -log(entropy)
    return entropy, energyS, energyB, numberB
end


function sampling(ϵ::Float32, lr::Float32)

    x = rand([1f0, -1f0], Const.dimB+Const.dimS)
    energy  = 0f0
    energyS = 0f0
    energyB = 0f0
    numberB = 0f0

    Func.ANN.initO()

    for i in 1:Const.burnintime
        Func.update(x)
    end

    for i in 1:Const.iters_num
        Func.update(x)

        eS = Func.energyS(x)
        eB = Func.energyB(x)
        e  = eS + eB
        energyS += eS
        energyB += eB
        energy  += e
        numberB += sum(x[1:Const.dimB])

        Func.ANN.backward(x, e)
    end
    energy   = real(energy)  / Const.iters_num
    energyS  = real(energyS) / Const.iters_num
    energyB  = real(energyB) / Const.iters_num
    numberB /= Const.iters_num

    Func.ANN.update(energy, ϵ, lr)

    return error, energyS, energyB, numberB
end

function calculation_energy()

    x = ones(Float32, Const.dimB+Const.dimS)
    energy  = 0.0f0
    energyS = 0.0f0
    energyB = 0.0f0
    numberB = 0.0f0

    for i in 1:Const.burnintime
        Func.update(x)
    end

    for i in 1:Const.num
        Func.update(x)

        eS = Func.energyS(x)
        eB = Func.energyB(x)
        e  = eS + eB
        energy    += e
        energyS   += eS
        energyB   += eB
        numberB   += sum(x[1:Const.dimB])
    end
    energy   = real(energy)  / Const.num
    energyS  = real(energyS) / Const.num
    energyB  = real(energyB) / Const.num
    numberB /= Const.num

    return energyS, energyB, numberB
end

end
