module IterableTables

using NamedTuples, Requires

export getiterator, isiterable, isiterabletable

struct HasLengthAfterStart <: Base.IteratorSize end

iteratorsize2(x) = iteratorsize2(typeof(x))
iteratorsize2{T}(::Type{T}) = Base.iteratorsize(T)

isiterable{T}(x::T) = method_exists(start, Tuple{T})

function getiterator(x)
    if !isiterable(x)
        error("Can't get iterator for non iterable source.")
    end
    return x
end

isiterabletable{T}(x::T) = isiterable(x) && Base.iteratoreltype(x)==Base.HasEltype() && Base.eltype(x)<: NamedTuple

include("utilities.jl")

include("generic_implementation.jl")

include("integrations/dataframes.jl")
include("integrations/datastreams.jl")
include("integrations/datatables.jl")
include("integrations/gadfly.jl")
include("integrations/indexedtables.jl")
include("integrations/statsmodels.jl")
include("integrations/timeseries.jl")
include("integrations/typedtables.jl")
include("integrations/vegalite.jl")
include("integrations/differentialequations.jl")
include("integrations/juliadb.jl")
include("integrations/generators.jl")
include("integrations/temporal.jl")

end # module
