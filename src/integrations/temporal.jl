@require Temporal begin
using TableTraits
using DataValues

immutable TSIterator{T, S}
    source::S
end

TableTraits.isiterable(x::Temporal.TS) = true
TableTraits.isiterabletable(x::Temporal.TS) = true

function TableTraits.getiterator{S<:Temporal.TS}(ta::S)
    col_expressions = Array{Expr,1}()
    df_columns_tuple_type = Expr(:curly, :Tuple)

    # Add column for index
    push!(col_expressions, Expr(:(::), :Index, S.parameters[2]))
    push!(df_columns_tuple_type.args, S.parameters[2])

    etype = eltype(ta.values)
    if ndims(ta.values)==1
        push!(col_expressions, Expr(:(::), ta.fields[1], etype))
        push!(df_columns_tuple_type.args, etype)
    else
        for i in 1:size(ta.values,2)
            push!(col_expressions, Expr(:(::), Symbol(ta.fields[i]), etype))
            push!(df_columns_tuple_type.args, etype)
        end
    end
    t_expr = NamedTuples.make_tuple(col_expressions)

    t2 = :(TSIterator{Float64,Float64})
    t2.args[2] = t_expr
    t2.args[3] = S

    t = eval(t2)

    e_ta = t(ta)

    return e_ta
end

function Base.length{T,TS}(iter::TSIterator{T,TS})
    return length(iter.source)
end

function Base.eltype{T,TS}(iter::TSIterator{T,TS})
    return T
end

Base.eltype(::Type{TSIterator{T,TS}}) where {T,TS} = T

function Base.start{T,TS}(iter::TSIterator{T,TS})
    return 1
end

@generated function Base.next{T,S}(iter::TSIterator{T,S}, state)
    constructor_call = Expr(:call, :($T))
    args = []
    # Add index column
    push!(args, :(iter.source.index[i]))

    for i in 1:length(T.parameters)-1
        push!(args, :(iter.source.values[i,$i]))
    end
    push!(constructor_call.args, Expr(:tuple, args...))

    quote
        i = state
        a = $constructor_call
        return a, state+1
    end
end

function Base.done{T,TS}(iter::TSIterator{T,TS}, state)
    return state>length(iter.source.index)
end

# Sink

# TODO This is a terribly inefficient implementation. Minimally it
# should be changed to be more type stable.
function Temporal.TS(x; index_column::Symbol=:Index)
    isiterabletable(x) || error()

    iter = getiterator(x)

    if TableTraits.column_count(iter)<2
        error("Need at least two columns")
    end

    names = TableTraits.column_names(iter)
    
    timestep_col_index = findfirst(names, index_column)

    if timestep_col_index==0
        error("No index column found.")
    end
    
    col_types = TableTraits.column_types(iter)

    data_columns = collect(Iterators.filter(i->i[2][1]!=index_column, enumerate(zip(names, col_types))))

    orig_data_type = data_columns[1][2][2]

    data_type = orig_data_type <: DataValue ? orig_data_type.parameters[1] : orig_data_type

    orig_timestep_type = col_types[timestep_col_index]

    timestep_type = orig_timestep_type <: DataValue ? orig_timestep_type.parameters[1] : orig_timestep_type

    if any(i->i[2][2]!=orig_data_type, data_columns)
        error("All data columns need to be of the same type.")
    end

    t_column = Array{timestep_type,1}()
    d_array = Array{Array{data_type,1},1}()
    for i in data_columns
        push!(d_array, Array{data_type,1}())
    end

    for v in iter
        if orig_timestep_type <: DataValue
            push!(t_column, get(v[timestep_col_index]))
        else
            push!(t_column, v[timestep_col_index])
        end

        if orig_data_type <: DataValue
            for (i,c) in enumerate(data_columns)
                push!(d_array[i],get(v[c[1]]))
            end
        else
            for (i,c) in enumerate(data_columns)
                push!(d_array[i],v[c[1]])
            end
        end
    end

    d_array = hcat(d_array...)

    ta = Temporal.TS(d_array, t_column,[i[2][1] for i in data_columns])
    return ta
end

end
