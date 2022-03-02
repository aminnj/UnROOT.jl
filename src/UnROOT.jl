module UnROOT

using LazyArrays
import Mmap: mmap
export ROOTFile, LazyBranch, LazyTree

import Base: close, keys, get, getindex, getproperty, show, length, iterate, position, ntoh, reinterpret
ntoh(b::Bool) = b

import AbstractTrees: children, printnode, print_tree

using CodecLz4, CodecXz, CodecZstd, StaticArrays, LorentzVectors, ArraysOfArrays
using Mixers, Parameters, Memoization, LRUCache
import IterTools: groupby

import LibDeflate: zlib_decompress!, Decompressor

import Tables, TypedTables, PrettyTables

@static if VERSION < v"1.6"
    Base.first(itr, n::Integer) = collect(Iterators.take(itr, n))
    Base.first(a::AbstractVector{S}, n::Integer) where S<: AbstractString = a[1:(length(a) > n ? n : end)]
    Base.first(a::S, n::Integer) where S<: AbstractString = a[1:(length(a) > n ? n : end)]
end

"""
    OffsetBuffer

Works with seek, position of the original file. Think of it as a view of IOStream that can be
indexed with original positions.
"""
struct OffsetBuffer{T}
    io::T
    offset::Int
end
Base.read(io::OffsetBuffer, nb) = Base.read(io.io, nb)
Base.seek(io::OffsetBuffer, i) = Base.seek(io.io, i - io.offset)
Base.skip(io::OffsetBuffer, i) = Base.skip(io.io, i)
Base.position(io::OffsetBuffer) = position(io.io) + io.offset

include("constants.jl")
include("streamsource.jl")
include("io.jl")
include("types.jl")
include("utils.jl")
include("streamers.jl")
include("bootstrap.jl")
include("root.jl")
include("iteration.jl")
include("custom.jl")
include("displays.jl")

if ccall(:jl_generating_output, Cint, ()) == 1   # if we're precompiling the package
    let
        r = ROOTFile("https://scikit-hep.org/uproot3/examples/Zmumu.root")
        show(devnull, r)
    end
end

end # module
