module Const

# System Size
const dimS = 8
const dimB = 80

# System Param
const t = 1.0f0
const J = 1.0f0
const λ = 0.001f0
const η = 0.1f0

# Repeat Number
const burnintime = 100
const iters_num = 200
const it_num = 1000
const iϵmax = 10
const num = 10000

# Network Params
<<<<<<< HEAD
const layer = [dimB+dimS, 48, 48, 2]
=======
const layer = [dimB+dimS, 48, 16]
>>>>>>> bm_extended
const layers_num = length(layer) - 1

# Learning Rate
const lr = 0.001f0

end
