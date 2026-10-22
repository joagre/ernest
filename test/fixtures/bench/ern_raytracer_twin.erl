%% The ray tracer of test/fixtures/bench/raytracer.ern as Erlang writes it,
%% for `make bench` (test/ern_program_costs.erl): the same scene, the same
%% functions and the same order of operations, over records. A constant is
%% a macro, which the host's compiler folds to a literal; the two
%% directions of the picture that are computed, ahead and upward, are
%% computed once and passed to each pixel's ray, as Erlang holds a value
%% computed at the start. An optional distance is `{ok, Distance}` or
%% `none`.
-module(ern_raytracer_twin).

-export([render/0]).

-record(vector, {x, y, z}).
-record(ray, {origin, direction}).
-record(color, {red, green, blue}).

-define(WIDTH, 400).
-define(HEIGHT, 300).
-define(RAYS, 2).
-define(CENTER, #vector{x = 0.0, y = 1.2, z = 0.0}).
-define(RADIUS, 1.0).
-define(EYE, #vector{x = 0.0, y = 1.5, z = -5.0}).
-define(RIGHTWARD, #vector{x = 1.0, y = 0.0, z = 0.0}).
-define(SPACING, (0.85 / ?HEIGHT)).
-define(LIGHT, #vector{x = -5.0, y = 7.0, z = -2.0}).
-define(AMBIENT, 0.2).
-define(DIFFUSE, 0.8).
-define(HIGHLIGHT, 0.6).
-define(SHININESS, 40.0).
-define(SKY, #color{red = 0.55, green = 0.65, blue = 0.85}).
-define(BALL_RED, #color{red = 0.85, green = 0.05, blue = 0.05}).
-define(BALL_WHITE, #color{red = 0.95, green = 0.95, blue = 0.95}).
-define(FLOOR_GRAY, #color{red = 0.25, green = 0.25, blue = 0.25}).
-define(MIRROR, 0.5).
-define(LATITUDE_BANDS, 8).
-define(LONGITUDE_BANDS, 16).

add(Left, Right) ->
    #vector{x = Left#vector.x + Right#vector.x, y = Left#vector.y + Right#vector.y,
            z = Left#vector.z + Right#vector.z}.

subtract(Left, Right) ->
    #vector{x = Left#vector.x - Right#vector.x, y = Left#vector.y - Right#vector.y,
            z = Left#vector.z - Right#vector.z}.

scaled(Vector, Factor) ->
    #vector{x = Vector#vector.x * Factor, y = Vector#vector.y * Factor,
            z = Vector#vector.z * Factor}.

dot(Left, Right) ->
    Left#vector.x * Right#vector.x + Left#vector.y * Right#vector.y
        + Left#vector.z * Right#vector.z.

vector_length(Vector) ->
    math:sqrt(dot(Vector, Vector)).

normalized(Vector) ->
    scaled(Vector, 1.0 / vector_length(Vector)).

reflected(Direction, Normal) ->
    subtract(Direction, scaled(Normal, 2.0 * dot(Direction, Normal))).

along(Ray, Distance) ->
    add(Ray#ray.origin, scaled(Ray#ray.direction, Distance)).

color_add(Left, Right) ->
    #color{red = Left#color.red + Right#color.red, green = Left#color.green + Right#color.green,
           blue = Left#color.blue + Right#color.blue}.

color_times(Left, Right) ->
    #color{red = Left#color.red * Right#color.red, green = Left#color.green * Right#color.green,
           blue = Left#color.blue * Right#color.blue}.

gray(Level) ->
    #color{red = Level, green = Level, blue = Level}.

%% The picture, a row of bytes for each row of pixels, top to bottom.
-spec render() -> [binary()].
render() ->
    Ahead = normalized(subtract(#vector{x = 0.0, y = 0.7, z = 0.0}, ?EYE)),
    Upward = #vector{x = 0.0, y = Ahead#vector.z, z = -Ahead#vector.y},
    [render_row(Ahead, Upward, Y) || Y <- lists:seq(0, ?HEIGHT - 1)].

render_row(Ahead, Upward, Y) ->
    Pixels = [pixel(trace(pixel_ray(Ahead, Upward, X, Y), ?RAYS)) || X <- lists:seq(0, ?WIDTH - 1)],
    iolist_to_binary(Pixels).

pixel(Color) ->
    <<(channel(Color#color.red)), (channel(Color#color.green)), (channel(Color#color.blue))>>.

channel(Level) ->
    round(min(Level, 1.0) * 255.0).

pixel_ray(Ahead, Upward, X, Y) ->
    Across = (float(X) + 0.5 - float(?WIDTH) / 2.0) * ?SPACING,
    Up = (float(?HEIGHT) / 2.0 - float(Y) - 0.5) * ?SPACING,
    #ray{origin = ?EYE,
         direction = normalized(add(add(Ahead, scaled(?RIGHTWARD, Across)), scaled(Upward, Up)))}.

trace(Ray, Depth) ->
    case nearest(Ray) of
        {ball, Distance} ->
            Point = along(Ray, Distance),
            Normal = scaled(subtract(Point, ?CENTER), 1.0 / ?RADIUS),
            shade(Point, Normal, Ray#ray.direction, check(Normal));
        {floor, Distance} ->
            Point = along(Ray, Distance),
            Normal = #vector{x = 0.0, y = 1.0, z = 0.0},
            Own = shade(Point, Normal, Ray#ray.direction, ?FLOOR_GRAY),
            if
                Depth > 1 ->
                    Mirrored = #ray{origin = Point,
                                    direction = reflected(Ray#ray.direction, Normal)},
                    color_add(color_times(Own, gray(1.0 - ?MIRROR)),
                              color_times(trace(Mirrored, Depth - 1), gray(?MIRROR)));
                true ->
                    Own
            end;
        none ->
            ?SKY
    end.

nearest(Ray) ->
    case {hit_sphere(Ray), hit_floor(Ray)} of
        {{ok, ToBall}, {ok, ToFloor}} when ToFloor < ToBall -> {floor, ToFloor};
        {{ok, ToBall}, _} -> {ball, ToBall};
        {none, {ok, ToFloor}} -> {floor, ToFloor};
        {none, none} -> none
    end.

hit_sphere(Ray) ->
    Offset = subtract(Ray#ray.origin, ?CENTER),
    Half = dot(Offset, Ray#ray.direction),
    Square = Half * Half - dot(Offset, Offset) + ?RADIUS * ?RADIUS,
    if
        Square < 0.0 ->
            none;
        true ->
            Root = math:sqrt(Square),
            if
                Root < -Half -> {ok, -Half - Root};
                true -> none
            end
    end.

hit_floor(Ray) ->
    Direction = Ray#ray.direction,
    if
        Direction#vector.y < 0.0 -> {ok, -(Ray#ray.origin)#vector.y / Direction#vector.y};
        true -> none
    end.

shade(Point, Normal, Direction, Surface) ->
    case reached(Point, Normal) of
        true ->
            ToLight = normalized(subtract(?LIGHT, Point)),
            Shine = max(0.0, dot(reflected(Direction, Normal), ToLight)),
            color_add(color_times(Surface, gray(?AMBIENT + ?DIFFUSE * dot(Normal, ToLight))),
                      gray(glint(Shine)));
        false ->
            color_times(Surface, gray(?AMBIENT))
    end.

reached(Point, Normal) ->
    ToLight = subtract(?LIGHT, Point),
    dot(Normal, ToLight) > 0.0
        andalso case hit_sphere(#ray{origin = Point, direction = normalized(ToLight)}) of
                    {ok, Distance} -> Distance > vector_length(ToLight);
                    none -> true
                end.

glint(Shine) ->
    ?HIGHLIGHT * math:pow(Shine, ?SHININESS).

check(Normal) ->
    Flat = #vector{x = Normal#vector.x, y = 0.0, z = Normal#vector.z},
    Latitude = math:atan2(vector_length(Flat), Normal#vector.y),
    Longitude = math:atan2(Normal#vector.z, Normal#vector.x),
    Bands = band_of(Latitude, math:pi(), ?LATITUDE_BANDS)
        + band_of(Longitude + math:pi(), 2.0 * math:pi(), ?LONGITUDE_BANDS),
    case Bands rem 2 of
        0 -> ?BALL_RED;
        _ -> ?BALL_WHITE
    end.

band_of(Angle, Span, Count) ->
    floor(Angle / Span * float(Count)).
