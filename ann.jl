module ANN
include("./setup.jl")
using .Const, LinearAlgebra, Flux, Zygote
using Flux.Optimise: update!
using BSON: @save
using BSON: @load

mutable struct Parameters

    W::Array{Complex{Float32}, 2}
    b::Array{Complex{Float32}, 1}
end

o  = Vector{Parameters}(undef, Const.layers_num)
oe = Vector{Parameters}(undef, Const.layers_num)

function initO()

    for i in 1:Const.layers_num
        global o[i]  = Parameters(zeros(Complex{Float32}, Const.layer[i+1], Const.layer[i]), 
                                  zeros(Complex{Float32}, Const.layer[i+1]))
        global oe[i] = Parameters(zeros(Complex{Float32}, Const.layer[i+1], Const.layer[i]), 
                                  zeros(Complex{Float32}, Const.layer[i+1]))
    end
end

mutable struct Network

    f::Flux.Chain
    g::Flux.Dense
    p::Zygote.Params
    q::Zygote.Params
end

function Network()

    func(x::Float32) = σ(x)
    layer = Vector{Flux.Dense}(undef, Const.layers_num-1)
    for i in 1:Const.layers_num-1
        layer[i] = Dense(Const.layer[i], Const.layer[i+1], func)
    end
    f = Chain([layer[i] for i in 1:Const.layers_num-1]...)
    p = params(f)
    W = randn(Complex{Float32}, Const.layer[end], Const.layer[end-1])
    b = zeros(Complex{Float32}, Const.layer[end])
    g = Dense(W, b)
    q = params([W, b])
    Network(f, g, p, q)
end

network = Network()

function save(filename)

    f = getfield(network, :f)
    g = getfield(network, :g)
    @save filename f g
end

function load(filename)

    @load filename f g
    p = params(f)
    q = params(g)
    Flux.loadparams!(network.f, p)
    Flux.loadparams!(network.g, q)
end

function init()

    parameters = Vector{Parameters}(undef, Const.layers_num-1)
    for i in 1:Const.layers_num-1
        W = randn(Float32, Const.layer[i+1], Const.layer[i]) * sqrt(1.0f0 / Const.layer[i])
        b = zeros(Float32, Const.layer[i+1])
        parameters[i] = Parameters(W, b)
    end
    p  = params([[parameters[i].W, parameters[i].b] for i in 1:Const.layers_num-1]...)
    W  = Array(Diagonal(randn(Complex{Float32}, Const.layer[end], Const.layer[end-1]))) * 
    sqrt(1.0f0 / Const.layer[i])
    b  = zeros(Complex{Float32}, Const.layer[end])
    q  = params([W, b])
    Flux.loadparams!(network.f, p)
    Flux.loadparams!(network.g, q)
end

function forward(x::Vector{Float32})

    out = network.f(x)
    return network.g(out)
end

loss(x::Vector{Float32}, h::Vector{Float32}) = real(dot(h, forward(x)))

function backward(x::Vector{Float32}, h::Vector{Float32}, e::Complex{Float32})

    gs = gradient(() -> loss(x, h), network.p)
    for i in 1:Const.layers_num-1
        dw = gs[network.f[i].W]
        db = gs[network.f[i].b]
        o[i].W  += dw
        oe[i].W += dw * e
        o[i].b  += db
        oe[i].b += db * e
    end
    dw = transpose(network.f(x)) .* h
    o[end].W  += dw
    oe[end].W += dw * e
end

opt(lr::Float32) = ADAM(lr, (0.9, 0.999))

function update(energy::Float32, ϵ::Float32, lr::Float32)

    for i in 1:Const.layers_num-1
        ΔW = 4.0f0 * (energy - ϵ) * [(energy - ϵ)^2 - Const.η^2 > 0.0f0] .* 
        real.(oe[i].W .- energy * o[i].W) / Const.iters_num
        Δb = 4.0f0 * (energy - ϵ) * [(energy - ϵ)^2 - Const.η^2 > 0.0f0] .* 
        real.(oe[i].b .- energy * o[i].b) / Const.iters_num
        update!(opt(lr), network.f[i].W, ΔW)
        update!(opt(lr), network.f[i].b, Δb)
    end
    ΔW = 4.0f0 * (energy - ϵ) * [(energy - ϵ)^2 - Const.η^2 > 0.0f0] .* 
    (oe[end].W .- energy * o[end].W) / Const.iters_num
    update!(opt(lr), network.g.W, ΔW)
end

end
