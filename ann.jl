module ANN
include("./setup.jl")
using .Const, LinearAlgebra, Flux, Zygote, Distributions
using Flux: @functor
using Flux.Optimise: update!
using BSON: @save
using BSON: @load

mutable struct Parameters

    W::Array
    b::Array
end

o  = Vector{Parameters}(undef, Const.layers_num)
oe = Vector{Parameters}(undef, Const.layers_num)

function initO()

    for i in 1:Const.layers_num-1
        W = zeros(Complex{Float32}, Const.layer[i+1], Const.layer[i])
        b = zeros(Complex{Float32}, Const.layer[i+1])
        global o[i]  = Parameters(W, b)
        global oe[i] = Parameters(W, b)
    end
    W = zeros(Complex{Float32}, Const.layer[end], Const.layer[end-1])
    b = zeros(Complex{Float32}, Const.layer[1])
    global o[end]  = Parameters(W, b)
    global oe[end] = Parameters(W, b)
end

struct Output{S<:AbstractArray,T<:AbstractArray}
    W::S
    b::T
end

function Output(in::Integer, out::Integer, out2::Integer;
             initW = Flux.glorot_uniform, initb = zeros)
  return Output(initW(out, in), initb(Float32, out2))
end

@functor Output

function (m::Output)(x::AbstractArray)
    W, b = m.W, m.b
    W*x, b
end

mutable struct Network

    f::Flux.Chain
    p::Zygote.Params
end

function Network()

    layer = Vector{Any}(undef, Const.layers_num)
    for i in 1:Const.layers_num-1
        layer[i] = Dense(Const.layer[i], Const.layer[i+1], tanh)
    end
    layer[end] = Output(Const.layer[end-1], Const.layer[end], Const.layer[1])
    f = Chain([layer[i] for i in 1:Const.layers_num]...)
    p = Flux.params(f)
    Network(f, p)
end

network = Network()

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
        W = Flux.glorot_uniform(Const.layer[i+1], Const.layer[i])
        b = zeros(Float32, Const.layer[i+1])
        parameters[i] = [W, b]
    end
    e = Exponential(2f0)
    W = Array{Float32, 2}(undef, Const.layer[end], Const.layer[end-1])
    W[1, :] = log.(sqrt.(rand(e, Const.layer[end-1])))
    W[2, :] = rand(Float32, Const.layer[end-1]) .* π
    b = zeros(Float32, Const.layer[1])
    parameters[end] = [W, b]
 
    paramset = [param for param in parameters]
    p = Flux.params(paramset...)
    Flux.loadparams!(network.f, p)
end

function forward(x::Vector{Float32})

    out, b = network.f(x)
    return log(out[1] + im * out[2]) + transpose(b) * x
end

loss(x::Vector{Float32}) = real(forward(x))

function backward(x::Vector{Float32}, e::Complex{Float32})

    gs = gradient(() -> loss(x), network.p)
    for i in 1:Const.layers_num
        dw = gs[network.f[i].W]
        db = gs[network.f[i].b]
        o[i].W  += dw
        oe[i].W += dw * e
        o[i].b  += db
        oe[i].b += db * e
    end
end

opt(lr::Float32) = ADAM(lr, (0.9, 0.999))

function update(energy::Float32, ϵ::Float32, lr::Float32)

    x = (energy - ϵ)
    α = 2f0 * x / Const.iters_num
    for i in 1:Const.layers_num
        ΔW = α .* 2f0 .* real.(oe[i].W .- energy * o[i].W)
        Δb = α .* 2f0 .* real.(oe[i].b .- energy * o[i].b)
        update!(opt(lr), network.f[i].W, ΔW)
        update!(opt(lr), network.f[i].b, Δb)
    end
end

end
