# copied from https://github.com/RelationalAI-oss/Blobs.jl/blob/master/src/vector.jl
# and modified `BlobVector` -> `MyBlobVector`
# which has an additional field: `ref::Base.RefValue{Vector{UInt8}}`
# to store the `rawdata` reference and prevent GC from deleting it.

struct MyBlobVector{T} <: AbstractArray{T, 1}
    data::Blob{T}
    length::Int64
    ref::Base.RefValue{Vector{UInt8}}
end

Base.size(blob::MyBlobVector) = (blob.length,)

Base.@propagate_inbounds function get_address(blob::MyBlobVector{T}, i::Int)::Blob{T} where T
    @boundscheck begin
        (0 < i <= blob.length) || throw(BoundsError(blob, i))
    end
    blob.data + (i-1)*Blobs.self_size(T)
end

Base.@propagate_inbounds function Base.getindex(blob::MyBlobVector{T}, i::Int)::T where T
    get_address(blob, i)[]
end

Base.@propagate_inbounds function Base.setindex!(blob::MyBlobVector{T}, v, i::Int)::T where T
    get_address(blob, i)[] = v
end

function Base.iterate(blob::MyBlobVector, i=1)
    (i % UInt) - 1 < length(blob) ? (@inbounds blob[i], i + 1) : nothing
end
