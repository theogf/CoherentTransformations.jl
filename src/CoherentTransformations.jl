module CoherentTransformations

using CoherentNoise
using ImageTransformations
using Random: AbstractRNG, default_rng


"""
This is a cheaper version of `gen_image` from `CoherentNoise`, which does not generate
a RGB matrix but a matrix of type T
"""
function gen_coherent_matrix(
    sampler::S;
    rng::AbstractRNG=default_rng(),
    ::Type{T} = Float64,
    width::Integer=1024,
    height::Integer=1024,
    (xmin, xmax)::NTuple{2,Float64}=(-1.0, 1.0),
    (ymin, ymax)::NTuple{2,Float64}=(-1.0, 1.0),
) where {N,T,S<:AbstractSampler{N}}
    xd = (xmax - xmin) / width
    yd = (ymax - ymin) / height
    X = Matrix{T}(undef, heigth, width)
    zw = rand(rng, Float64, N - 2) * 1000
    Threads.@threads for x in 1:height
        cx = x * xd + x1
        for y in 1:width
            cy = y * yd + y1
            X[x, y] = clamp(sample(sampler, cx, cy, zw...) * 0.5 + 0.5, 0, 1)
        end
    end
    return X
end

"""
    noise_warp(img, noise_source::AbstractSampler; squared=true, variance=0.1, crop=true)

`noise_warp` takes both an `img` and a `noise_source` built from `CoherentNoise.jl`
and returns a warpped image.
The principle is simple:

- Two matrices of noise are generated using `noise_source`.
- These matrices are converted into vector field by centering the values around 0
and scaling them with `variance * size`.
- The vector field corresponds to the displacement of the pixels in the x/y coordinate field.
- `ImageTransformations` apply the transformations and adaptively warp the image.
- If `crop` is true, the image will be cropped to ensure no `NaN` values are contained.
"""

function noise_warp(
    img, noise_source::AbstractSampler; squared=true, variance=0.1, crop=true
)
    !crop ||
        variance < 0.5 ||
        error(
            "(relative) variance needs to be smaller to 50% (0.5) to avoid cropping the whole image.",
        )
    height, width = size(img)
    variances =
        floor.(Int, variance * (squared ? min(height, width) * ones(2) : [height, width]))
    vals = [
        (gen_coherent_matrix(noise_source; width, height) .- 0.5) * variances[i] for
        i in 1:2
    ]
    vecs = [SVector{2}(vals[1][i], vals[2][i]) for i in CartesianIndices(img)]
    function move_from_vecs(x::SVector{N}) where {N}
        return SVector{N}(x .+ vecs[x...])
    end
    img = warp(img, move_from_vecs, axes(img))
    return if crop
        imresize(
            img[
                (begin + variances[1]):(end - variances[1]),
                (begin + variances[2]):(end - variances[2]),
            ],
            (h, w),
        ) # This crops out given the variances.
    else
        img # This crops out given the variances.
    end # This crops out given the variances.
end

"Use the `checkered_2d` noise from `CoherenNoise` for a checker effect"
function checker_warp(
    img; rng::AbstractRNG=default_rng(), squared=true, variance=0.1, scaling=0.1, crop=true
)
    return noise_warp(
        img,
        CoherentNoise.scale(checkered_2d(; seed=rand(rng, UInt)), scaling);
        squared,
        variance,
        crop,
    )
end

function ridged_warp(
    img;
    rng::AbstractRNG=default_rng(),
    squared=true,
    variance=0.1,
    frequency=2.5,
    persistence=0.4,
    attenuation=1,
    scaling=0.1,
    crop=true,
)
    source = opensimplex2_3d(; seed=rand(rng, UInt))
    source = ridged_fractal_3d(; source, frequency, persistence, attenuation)
    return noise_warp(img, CoherentNoise.scale(source, scaling); squared, variance, crop)
end

function cylinder_warp(
    img;
    rng::AbstractRNG=default_rng(),
    squared=true,
    variance=0.1,
    frequency=2,
    scaling=0.1,
    crop=true,
)
    source = cylinders_2d(; seed=rand(rng, UInt), frequency)
    return noise_warp(img, CoherentNoise.scale(source, scaling); squared, variance, crop)
end

function sphere_warp(
    img;
    rng::AbstractRNG=default_rng(),
    frequency=100,
    squared=true,
    variance=0.1,
    crop=true,
    scaling=0.1,
)
    source = spheres_3d(; seed=rand(rng, UInt), frequency)
    return noise_warp(img, CoherentNoise.scale(source, scaling); squared, variance, crop)
end

end
