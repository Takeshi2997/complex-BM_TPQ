module ANN
include("./setup.jl")
using .Const, LinearAlgebra, Flux, Zygote
using Flux: @functor
using Flux.Optimise: update!
using BSON: @save
using BSON: @load

# Initialize
abstract type Parameters end
mutable struct Params{S<:AbstractArray, T<:AbstractArray} <: Parameters
    W::S
    b::T
end

mutable struct ParamSet{T <: Parameters}
    o::Vector{T}
    oe::Vector{T}
end

function ParamSet()
    p  = Vector{Parameters}(undef, Const.layers_num)
    for i in 1:Const.layers_num
        W = zeros(Complex{Float32}, Const.layer[i+1], Const.layer[i])
        b = zeros(Complex{Float32}, Const.layer[i+1])
        p[i]  = Params(W, b)
    end
    ParamSet(p, p)
end

# Define Network

mutable struct Network
    f::Flux.Chain
    p::Zygote.Params
end

function Network()
    layers = Vector(undef, Const.layers_num)
    for i in 1:Const.layers_num-1
        layers[i] = Dense(Const.layer[i], Const.layer[i+1], swish)
    end
    W = randn(Complex{Float32}, Const.layer[end], Const.layer[end-1])
    b = zeros(Complex{Float32}, Const.layer[end])
    layers[end] = Dense(W, b)
    f = Chain([layers[i] for i in 1:Const.layers_num]...)
    p = Flux.params(f)
    Network(f, p)
end

network = Network()

# Network Utility

function save(filename)
    f = getfield(network, :f)
    @save filename f
end

function load(filename)
    @load filename f
    p = Flux.params(f)
    Flux.loadparams!(network.f, p)
end

function init()
    parameters = Vector{Array}(undef, Const.layers_num)
    for i in 1:Const.layers_num-1
        W = Flux.kaiming_normal(Const.layer[i+1], Const.layer[i])
        b = Flux.zeros(Const.layer[i+1])
        parameters[i] = [W, b]
    end
    W = randn(Complex{Float32}, Const.layer[end], Const.layer[end-1])
    b = zeros(Complex{Float32}, Const.layer[end])
    parameters[i] = [W, b]
    paramset = [param for param in parameters]
    p = Flux.params(paramset...)
    Flux.loadparams!(network.f, p)
end

# Learning Method

function forward(x::Vector{Float32})
    out = network.f(x)
    return transpose(x) * out
end

loss(x::Vector{Float32}) = real(forward(x))

function backward(x::Vector{Float32}, e::Complex{Float32}, paramset::ParamSet)
    gs = gradient(() -> loss(x), network.p)
    for i in 1:Const.layers_num
        dw = gs[network.f[i].W]
        db = gs[network.f[i].b]
        paramset.o[i].W  += dw
        paramset.o[i].b  += db
        paramset.oe[i].W += dw .* e
        paramset.oe[i].b += db .* e
    end
end

function updateparams(energy::Float32, lr::Float32, paramset::ParamSet, Δparamset::Vector)
    for i in 1:Const.layers_num - 1
        oW   = real.(paramset.o[i].W  / Const.iters_num)
        ob   = real.(paramset.o[i].b  / Const.iters_num)
        oeW  = real.(paramset.oe[i].W / Const.iters_num)
        oeb  = real.(paramset.oe[i].b / Const.iters_num)
        ΔW = oeW - energy * oW
        Δb = oeb - energy * ob
        Δparamset[i][1] += ΔW
        Δparamset[i][2] += Δb
    end
    oW   = paramset.o[end].W  / Const.iters_num
    ob   = paramset.o[end].b  / Const.iters_num
    oeW  = paramset.oe[end].W / Const.iters_num
    oeb  = paramset.oe[end].b / Const.iters_num
    ΔW = oeW - energy * oW
    Δb = oeb - energy * ob
    Δparamset[end][1] += ΔW
    Δparamset[end][2] += Δb
end

opt(lr::Float32) = Descent(lr)

function update(Δparamset::Vector, lr::Float32)
    for i in 1:Const.layers_num
        update!(opt(lr), network.f[i].W, Δparamset[i][1])
        update!(opt(lr), network.f[i].b, Δparamset[i][2])
    end
end
end
