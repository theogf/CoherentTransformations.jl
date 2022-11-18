# # CoherentTransformations logo creation
# We first generate 3 different circles for the Julia logo
using Colors: JULIA_LOGO_COLORS
using Luxor
red, green, blue, purple = JULIA_LOGO_COLORS


circles = map((red, green, purple)) do color
    buffer = zeros(ARGB32, 200, 200)
    Drawing(buffer)
    setcolor(color)
    circle(Point(100, 100), 90, action=:fill)
    finish()
    buffer |> display
    buffer
end
warped_circles = (checker_warp(circles[1]; crop=false),
ridged_warp(circles[2]; crop=false, scaling=2.0),
cylinder_warp(circles[3]; crop=false, scaling=0.05))

background("white")

Drawing(500, 500, "logo.png")
points = ngon(Point(250, 280), 150, 3, pi/6, vertices=true)
for i in 1:3
    placeimage(warped_circles[i], points[i] .- 100)
end
finish()
preview()