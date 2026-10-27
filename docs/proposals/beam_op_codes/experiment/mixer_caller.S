{module, mixer_caller}.  %% version = 0

{exports, [{module_info,0},{module_info,1},{run,1}]}.

{attributes, []}.

{labels, 18}.


{function, run, 1, 2}.
  {label,1}.
    {func_info,{atom,mixer_caller},{atom,run},1}.
  {label,2}.
    {move,{integer,3},{x,3}}.
    {move,{integer,2},{x,2}}.
    {move,{integer,0},{x,4}}.
    {move,{integer,1},{x,1}}.
    {call_only,5,{f,4}}. % loop/5


{function, loop, 5, 4}.
  {label,3}.
    {func_info,{atom,mixer_caller},{atom,loop},5}.
  {label,4}.
    {test,is_eq_exact,{f,5},[{tr,{x,0},{t_integer,{0,100000000}}},{integer,0}]}.
    {move,{x,4},{x,0}}.
    return.
  {label,5}.
    {allocate,5,5}.
    {init_yregs,{list,[{y,0}]}}.
    {move,{x,4},{y,1}}.
    {move,{x,3},{y,2}}.
    {move,{x,2},{y,3}}.
    {move,{x,0},{y,4}}.
    {move,{x,1},{x,0}}.
    {call,1,{f,7}}. % lcg/1
    {move,{y,3},{x,1}}.
    {move,{x,0},{y,3}}.
    {swap,{x,0},{x,1}}.
    {call,2,{f,9}}. % mix/2
    {swap,{y,2},{x,0}}.
    {move,{y,4},{x,1}}.
    {call,2,{f,11}}. % rot/2
    {move,{y,3},{x,2}}.
    {move,{x,0},{y,0}}.
    {move,{y,2},{x,1}}.
    {swap,{x,0},{x,2}}.
    {call,3,{f,13}}. % mix3/3
    {gc_bif,'-',{f,0},1,[{tr,{y,4},{t_integer,{1,100000000}}},{integer,1}],{x,1}}.
    {gc_bif,'+',
            {f,0},
            2,
            [{tr,{y,1},{t_integer,{-16777215,16777215}}},
             {tr,{x,0},{t_integer,{-16777215,16777215}}}],
            {x,0}}.
    {gc_bif,'rem',
            {f,0},
            2,
            [{tr,{x,0},{t_integer,{-33554430,33554430}}},{integer,16777216}],
            {x,4}}.
    {move,{y,0},{x,3}}.
    {move,{y,2},{x,2}}.
    {move,{x,1},{x,0}}.
    {move,{y,3},{x,1}}.
    {call_last,5,{f,4},5}. % loop/5


{function, lcg, 1, 7}.
  {label,6}.
    {func_info,{atom,mixer_caller},{atom,lcg},1}.
  {label,7}.
    {gc_bif,'*',
            {f,0},
            1,
            [{tr,{x,0},{t_integer,{0,16777215}}},{integer,1103515245}],
            {x,0}}.
    {gc_bif,'+',
            {f,0},
            1,
            [{tr,{x,0},{t_integer,{0,18513912521142675}}},{integer,12345}],
            {x,0}}.
    {gc_bif,'rem',
            {f,0},
            1,
            [{tr,{x,0},{t_integer,{12345,18513912521155020}}},
             {integer,16777216}],
            {x,0}}.
    return.


{function, mix, 2, 9}.
  {label,8}.
    {func_info,{atom,mixer_caller},{atom,mix},2}.
  {label,9}.
    {gc_bif,'*',
            {f,0},
            2,
            [{tr,{x,1},{t_integer,{-16777215,16777215}}},{integer,8}],
            {x,1}}.
    {gc_bif,'+',
            {f,0},
            2,
            [{tr,{x,0},{t_integer,{-16777215,16777215}}},
             {tr,{x,1},{t_integer,{-134217720,134217720}}}],
            {x,0}}.
    {gc_bif,'rem',
            {f,0},
            1,
            [{tr,{x,0},{t_integer,{-150994935,150994935}}},{integer,16777216}],
            {x,0}}.
    return.


{function, rot, 2, 11}.
  {label,10}.
    {func_info,{atom,mixer_caller},{atom,rot},2}.
  {label,11}.
    {gc_bif,'rem',{f,0},2,[{tr,{x,1},{t_integer,{1,100000000}}},{integer,8}],{x,1}}.
    {gc_bif,'+',{f,0},2,[{tr,{x,1},{t_integer,{-7,7}}},{integer,1}],{x,2}}.
    {gc_bif,'*',
            {f,0},
            3,
            [{tr,{x,0},{t_integer,{-16777215,16777215}}},
             {tr,{x,2},{t_integer,{-6,8}}}],
            {x,0}}.
    {gc_bif,'-',{f,0},2,[{integer,24},{tr,{x,1},{t_integer,{-7,7}}}],{x,1}}.
    {gc_bif,'+',
            {f,0},
            2,
            [{tr,{x,0},{t_integer,{-134217720,134217720}}},
             {tr,{x,1},{t_integer,{17,31}}}],
            {x,0}}.
    {gc_bif,'rem',
            {f,0},
            1,
            [{tr,{x,0},{t_integer,{-134217703,134217751}}},{integer,16777216}],
            {x,0}}.
    return.


{function, mix3, 3, 13}.
  {label,12}.
    {func_info,{atom,mixer_caller},{atom,mix3},3}.
  {label,13}.
    {allocate,1,3}.
    {move,{x,2},{y,0}}.
    {call,2,{f,9}}. % mix/2
    {move,{y,0},{x,1}}.
    {call,2,{f,9}}. % mix/2
    {gc_bif,'*',
            {f,0},
            1,
            [{tr,{y,0},{t_integer,{-16777215,16777215}}},{integer,7}],
            {x,1}}.
    {gc_bif,'+',
            {f,0},
            2,
            [{tr,{x,0},{t_integer,{-16777215,16777215}}},
             {tr,{x,1},{t_integer,{-117440505,117440505}}}],
            {x,0}}.
    {gc_bif,'rem',
            {f,0},
            1,
            [{tr,{x,0},{t_integer,{-134217720,134217720}}},{integer,16777216}],
            {x,0}}.
    {deallocate,1}.
    return.


{function, module_info, 0, 15}.
  {label,14}.
    {func_info,{atom,mixer_caller},{atom,module_info},0}.
  {label,15}.
    {move,{atom,mixer_caller},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 17}.
  {label,16}.
    {func_info,{atom,mixer_caller},{atom,module_info},1}.
  {label,17}.
    {move,{x,0},{x,1}}.
    {move,{atom,mixer_caller},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
