"""
    macro stack(into, structs...)

Stack the fields of multiple structs and create a new one.
The first argument is the name of the new struct followed by the
ones to be stacked. Parametric types are not supported and
the fieldnames needs to be unique.

Example:

    @stack Baz Foo Bar

Creates `Baz` with the concatenated fields of `Foo` and `Bar`

"""
macro stack(into, structs...)
    fields = []
    for _struct in structs
        names = fieldnames(getfield(__module__, _struct))
        types = [fieldtype(getfield(__module__, _struct), field) for field in names]
        for (n, t) in zip(names, types)
            push!(fields, :($n::$t))
        end
    end

    esc(
        quote
            struct $into
                $(fields...)
            end
        end
    )
end

"""
    unpack(x::CompressionHeader)

Return the following information:
- Name of compression algorithm
- Level of the compression
- compressedbytes and uncompressedbytes according to [uproot3](https://github.com/scikit-hep/uproot3/blob/54f5151fb7c686c3a161fbe44b9f299e482f346b/uproot3/source/compressed.py#L132)
"""
function unpack(x::CompressionHeader)
    algname = String(x.algo)
    # shift without casting to `Int` will give you 0x00 because we're shifting 0 bits into UInt8
    compressedbytes = x.c1 + (Int(x.c2) << 8) + (Int(x.c3) << 16)
    uncompressedbytes = x.u1 + (Int(x.u2) << 8) + (Int(x.u3) << 16)

    return algname, x.method, compressedbytes, uncompressedbytes
end


abstract type JaggType end
struct Nojagg      <:JaggType  end
struct Nooffsetjagg<:JaggType  end
struct Offsetjagg  <:JaggType  end
struct Offsetjaggjagg  <:JaggType  end

function JaggType(f, branch, leaf)
    # https://github.com/scikit-hep/uproot3/blob/54f5151fb7c686c3a161fbe44b9f299e482f346b/uproot3/interp/auto.py#L144
    (match(r"\[.*\]", leaf.fTitle) !== nothing) && return Nooffsetjagg
    leaf isa TLeafElement && leaf.fLenType==0 && return Offsetjagg
    !hasproperty(branch, :fClassName) && return Nojagg

    try
        streamer = streamerfor(f, branch.fClassName).streamer.fElements.elements[1]
        (streamer.fSTLtype == Const.kSTLvector) && return Offsetjagg
    catch
    end

    return Nojagg
end

"""
    parseTH(th::Dict{Symbol, Any})

Parse the output of [`TH`](@ref) into a tuple of `counts`, `edges`, and `sumw2`.
A `StatsBase.Histogram` can then be constructed with `Histogram(edges, counts)`.
TH1 and TH2 inputs are supported.
"""
function parseTH(th::Dict{Symbol, Any})
    xmin = th[:fXaxis_fXmin]
    xmax = th[:fXaxis_fXmax]
    xnbins = th[:fXaxis_fNbins]
    xbins = isempty(th[:fXaxis_fXbins]) ? range(xmin, xmax, length=xnbins+1) : th[:fXaxis_fXbins];
    counts = th[:fN]
    sumw2 = th[:fSumw2]
    if th[:fYaxis_fNbins] > 1
        ymin = th[:fYaxis_fXmin]
        ymax = th[:fYaxis_fXmax]
        ynbins = th[:fYaxis_fNbins]
        ybins = isempty(th[:fYaxis_fXbins]) ? range(ymin, ymax, length=ynbins+1) : th[:fYaxis_fXbins];
        counts = reshape(counts, (xnbins+2, ynbins+2))[2:end-1, 2:end-1]
        sumw2 = reshape(sumw2, (xnbins+2, ynbins+2))[2:end-1, 2:end-1]
        edges = (xbins, ybins)
    else
        counts = counts[2:end-1]
        sumw2 = sumw2[2:end-1]
        edges = (xbins,)
    end
    return counts, edges, sumw2
end

function samplefile(filename::AbstractString)
    return ROOTFile(normpath(joinpath(@__DIR__, "../test/samples", filename)))
end
