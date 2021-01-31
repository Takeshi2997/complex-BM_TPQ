module ANN
include("./setup.jl")
using .Const, LinearAlgebra, Flux, Zygote
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
    for i in 1:Const.layers_num
        W = zeros(Complex{Float32}, Const.layer[i+1], Const.layer[i])
        b = zeros(Complex{Float32}, Const.layer[i+1])
        global o[i]  = Parameters(W, b)
        global oe[i] = Parameters(W, b)
    end
end

mutable struct Network
    f::Flux.Chain
    p::Zygote.Params
end

struct Res{F,S<:AbstractArray,T<:AbstractArray}
    W::S
    b::T
    σ::F
end

function Res(in::Integer, out::Integer, σ = identity;
             initW = Flux.glorot_uniform, initb = Flux.zeros)
  return Res(initW(out, in), initb(out), σ)
end
@functor Res
function (m::Res)(x::AbstractArray)
    W, b, σ = m.W, m.b, m.σ
    x .+ σ.(W*x.+b)
end

function Network()
    layer = Vector(undef, Const.layers_num)
    for i in 1:Const.layers_num-1
        layer[i] = Dense(Const.layer[i], Const.layer[i+1], tanh)
    end
    layer[end] = Dense(Const.layer[end-1], Const.layer[end])
    f = Chain([layer[i] for i in 1:Const.layers_num]...)
    p = params(f)
    Network(f, p)
end

network = Network()

function save(filename)
    f = getfield(network, :f)
    @save filename f
end

function load(filename)
    @load filename f
    p = params(f)
    Flux.loadparams!(network.f, p)
end

function init()
    parameters = Vector{Array}(undef, Const.layers_num)
    for i in 1:Const.layers_num
        W = randn(Float32, Const.layer[i+1], Const.layer[i]) ./ Float32(sqrt(Const.layer[i]))
        b = zeros(Float32, Const.layer[i+1])
        parameters[i] = [W, b]
    end
    paramset = [param for param in parameters]
    p = params(paramset...)
    Flux.loadparams!(network.f, p)
end

function forward(x::Vector{Float32})
    out = network.f(x)
    return out[1] + im * out[2]
end

loss(x::Vector{Float32}) = real(forward(x))

function backward(x::Vector{Float32}, e::Complex{Float32})
    gs = gradient(() -> loss(x), network.p)
    for i in 1:Const.layers_num-1
        dw = gs[network.f[i].W]
        db = gs[network.f[i].b]
        o[i].W  += dw
        oe[i].W += dw * e
        o[i].b  += db
        oe[i].b += db * e
    end
    dw = gs[network.f[end].W]
    o[end].W  += dw
    oe[end].W += dw * e
end

opt(lr::Float32) = ADAM(lr, (0.9, 0.999))

function update(energy::Float32, ϵ::Float32, lr::Float32)
    α = 2f0 * (energy - ϵ) / Const.iters_num
    for i in 1:Const.layers_num-1
        ΔW = α .* real.(oe[i].W .- energy * o[i].W)
        Δb = α .* real.(oe[i].b .- energy * o[i].b)
        update!(opt(lr), network.f[i].W, ΔW)
        update!(opt(lr), network.f[i].b, Δb)
    end
    ΔW = α .* real(oe[end].W .- energy * o[end].W)
    update!(opt(lr), network.f[end].W, ΔW)
end

end
