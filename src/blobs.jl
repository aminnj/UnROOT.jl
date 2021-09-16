# copied from https://github.com/RelationalAI-oss/Blobs.jl/blob/master/src/vector.jl
# and modified `BlobVector` -> `MyBlobVector`
# which has an additional field: `ref::Base.RefValue{Vector{UInt8}}`
# to store the `rawdata` reference and prevent GC from deleting it.
#
# TODO figure out what is used/needed

"A fixed-length vector whose data is stored in a Blob."
struct MyBlobVector{T} <: AbstractArray{T, 1}
    data::Blob{T}
    length::Int64
    ref::Base.RefValue{Vector{UInt8}}
end

function Base.pointer(bv::MyBlobVector{T}, i::Integer=1) where {T}
    return get_address(bv, i)
end

Base.@propagate_inbounds function get_address(blob::MyBlobVector{T}, i::Int)::Blob{T} where T
    @boundscheck begin
        (0 < i <= blob.length) || throw(BoundsError(blob, i))
    end
    blob.data + (i-1)*Blobs.self_size(T)
end

# array interface

function Base.size(blob::MyBlobVector)
    (blob.length,)
end

function Base.IndexStyle(_::Type{MyBlobVector{T}}) where T
    Base.IndexLinear()
end

Base.@propagate_inbounds function Base.getindex(blob::MyBlobVector{T}, i::Int)::T where T
    get_address(blob, i)[]
end

Base.@propagate_inbounds function Base.setindex!(blob::MyBlobVector{T}, v, i::Int)::T where T
    get_address(blob, i)[] = v
end

# copying, with correct handling of overlapping regions
function Base.copy!(
    dest::MyBlobVector{T}, doff::Int, src::MyBlobVector{T}, soff::Int, n::Int
) where T
    @boundscheck begin
        if doff < 1 || doff + n - 1 > length(dest)
            throw(BoundsError(dest, doff:doff+n-1))
        elseif soff < 1 || soff + n - 1 > length(src)
            throw(BoundsError(src, soff:soff+n-1))
        end
    end
    # Use memmove for speedy copying. Note: this correctly handles overlapping regions.
    blob_size = Blobs.self_size(T)
    ccall(
        :memmove,
        Ptr{Cvoid},
        (Ptr{Cvoid}, Ptr{Cvoid}, Csize_t),
        Base.pointer(dest.data) + (doff - 1) * blob_size,
        Base.pointer(src.data) + (soff - 1) * blob_size,
        n * blob_size,
    )
end

# iterate interface

@inline function Base.iterate(blob::MyBlobVector, i=1)
    (i % UInt) - 1 < length(blob) ? (@inbounds blob[i], i + 1) : nothing
end

