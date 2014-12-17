function roc{T<:Real}(tar::Vector{T}, non::Vector{T}; laplace::Bool=true) 
    xo, tc = sortscores(tar, non)
    ## first collect point of the same threshold (for discrete score data)
    θ, tc, nc, = binscores(xo, tc)
    ## now we can compute pmiss and pfa
    pfa = [1, 1 - cumsum(nc)/length(non)]
    pmiss = [0, cumsum(tc)/length(tar)]
    ## convex hull and llr
    ch, llr = chllr(tc, nc, xo, laplace)
    ## remove points on the ROC in the middle of a horizontal or vertical segment
    changes = changepoints(pfa, pmiss)
    (pfa, pmiss, ch) = map(a -> a[changes], (pfa, pmiss, ch))
    (llr, θ) = map(a -> a[changes[1:end-1]], (llr, θ))
    Roc(pfa, pmiss, ch, θ, llr)
end

## this returns the target count (1's an 0's for targets and non targets) and scores, 
## in the order of the scores. 
function sortscores{T<:Real}(tar::Vector{T}, non::Vector{T})
    x = vcat(tar, non)                     # order targets before non-targets
    so = sortperm(x)                       # sort order
    xo = x[so]                             # scores oredered
    tc = vcat(ones(Int, length(tar)), zeros(Int, length(non)))[so] # target count
    return xo, tc
end    

## bins scores that are the same into aggredated score counts
function binscores{T<:Real}(xo::Vector{T},tc::Vector{Int})
    nc = 1 - tc
    changes = find([true, diff(xo) .!= 0, true])                  # points where threshold change
    θ = xo                      # threshold
    remove = Int[]
    for i=1:length(changes)-1
        start = changes[i]
        stop = changes[i+1]-1
        if stop>start
            tc[start] = sum(tc[start:stop])
            nc[start] = sum(nc[start:stop])
            for j=start+1:stop 
                push!(remove,j)
            end
        end
    end
#    println(remove)
    if length(remove)>0
        keep = setdiff(1:length(tc),remove)
        (tc, nc, θ) = map(a -> a[keep], (tc, nc, θ))
    else
        keep = trues(length(tc))
    end
    return θ, tc, nc, keep
end

## This finds the chnge points on the ROC (the corner points)
function changepoints(pfa::Vector{Float64}, pmiss::Vector{Float64})
    (const_pfa, const_pmiss) = map(a -> diff(a) .== 0, (pfa, pmiss)) # no changes
    return [true, ! (const_pfa[1:end-1]  &  const_pfa[2:end] | 
                     const_pmiss[1:end-1] & const_pmiss[2:end]), true]
end
    

## compute convex hull and optimal llr from target count, nontarget count, and ordered scores
function chllr{T}(tc::Vector{Int}, nc::Vector{Int}, xo::Vector{T}, laplace::Bool=true)
    if laplace
        tc = [1, 0, tc, 1, 0]
        nc = [0, 1, nc, 0, 1]
        xo = [-Inf, -Inf, xo, Inf, Inf]
    end
    ntar = sum(tc)
    nnon = sum(nc)
    pfa = [1, 1 - cumsum(nc)/nnon]
    pmiss = [0, cumsum(tc)/ntar]
    ## convex hull
    hull = chull(vcat(hcat(pfa, pmiss), [2 2])) # convex hull points
    index = sort(hull.vertices[:,1])[1:end-1]   # indices of the points on the CH
    ch = falses(length(pfa))
    ch[index] = true
    ## LLR
    (Δpfa, Δpmiss) = map(a -> diff(a[ch]), (pfa, pmiss))
    llr = log(abs(Δpmiss ./ Δpfa))[cumsum(ch)[1:end-1]]
    if laplace
        return [true, ch[4:end-3], true], llr[3:end-2]
    else
        return ch, llr
    end
end
