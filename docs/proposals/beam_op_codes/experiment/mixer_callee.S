{module, mixer_callee}.  %% version = 0

{exports, [{module_info,0},{module_info,1},{run,1}]}.

{attributes, []}.

{labels, 18}.


{function, run, 1, 2}.
  {label,1}.
        {func_info,{atom,mixer_callee},{atom,run},1}.
  {label,2}.
    {move,{integer,3},{x,3}}.
    {move,{integer,2},{x,2}}.
    {move,{integer,0},{x,4}}.
    {move,{integer,1},{x,1}}.
    {call_only,5,{f,4}}. % loop/5


{function, loop, 5, 4}.
  {label,3}.
    {func_info,{atom,mixer_callee},{atom,loop},5}.
  {label,4}.
    {test,is_eq_exact,{f,5},[{tr,{x,0},{t_integer,{0,100000000}}},{integer,0}]}.
    {move,{x,4},{x,0}}.
    return.
  {label,5}.
    {allocate,0,5}.
    {move,{x,0},{x,5}}.
    {move,{x,2},{x,6}}.
    {move,{x,1},{x,0}}.
    {call,1,{f,7}}.
    {move,{x,0},{x,7}}.
    {move,{x,7},{x,1}}.
    {move,{x,6},{x,0}}.
    {call,2,{f,9}}.
    {move,{x,0},{x,8}}.
    {move,{x,3},{x,0}}.
    {move,{x,5},{x,1}}.
    {call,2,{f,11}}.
    {move,{x,0},{x,3}}.
    {move,{x,7},{x,0}}.
    {move,{x,8},{x,1}}.
    {move,{x,3},{x,2}}.
    {call,3,{f,13}}.
    {gc_bif,'+',{f,0},5,[{tr,{x,4},{t_integer,{0,16777215}}},{tr,{x,0},{t_integer,{0,16777215}}}],{x,0}}.
    {gc_bif,'band',{f,0},5,[{tr,{x,0},{t_integer,{0,33554430}}},{integer,16777215}],{x,4}}.
    {gc_bif,'-',{f,0},5,[{tr,{x,5},{t_integer,{1,100000000}}},{integer,1}],{x,0}}.
    {move,{x,7},{x,1}}.
    {move,{x,8},{x,2}}.
    {call_last,5,{f,4},0}.


{function, lcg, 1, 7}.
  {label,6}.
        {func_info,{atom,mixer_callee},{atom,lcg},1}.
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
    {gc_bif,'band',
            {f,0},
            1,
            [{tr,{x,0},{t_integer,{12345,18513912521155020}}},
             {integer,16777215}],
            {x,0}}.
    return.


{function, mix, 2, 9}.
  {label,8}.
        {func_info,{atom,mixer_callee},{atom,mix},2}.
  {label,9}.
            {gc_bif,'bsl',
            {f,0},
            2,
            [{tr,{x,1},{t_integer,{0,16777215}}},{integer,3}],
            {x,1}}.
    {gc_bif,'bxor',
            {f,0},
            2,
            [{tr,{x,0},{t_integer,{0,16777215}}},
             {tr,{x,1},{t_integer,{0,134217720}}}],
            {x,0}}.
    {gc_bif,'band',
            {f,0},
            1,
            [{tr,{x,0},{t_integer,{0,134217727}}},{integer,16777215}],
            {x,0}}.
    return.


{function, rot, 2, 11}.
  {label,10}.
        {func_info,{atom,mixer_callee},{atom,rot},2}.
  {label,11}.
            {gc_bif,'band',{f,0},2,[{tr,{x,1},{t_integer,{1,100000000}}},{integer,7}],{x,1}}.
        {gc_bif,'bsl',
            {f,0},
            2,
            [{tr,{x,0},{t_integer,{0,16777215}}},{tr,{x,1},{t_integer,{0,7}}}],
            {x,2}}.
    {gc_bif,'-',{f,0},3,[{integer,24},{tr,{x,1},{t_integer,{0,7}}}],{x,1}}.
    {gc_bif,'bsr',
            {f,0},
            3,
            [{tr,{x,0},{t_integer,{0,16777215}}},
             {tr,{x,1},{t_integer,{17,24}}}],
            {x,0}}.
    {gc_bif,'bor',
            {f,0},
            3,
            [{tr,{x,2},{t_integer,{0,2147483520}}},
             {tr,{x,0},{t_integer,{0,127}}}],
            {x,0}}.
    {gc_bif,'band',
            {f,0},
            1,
            [{tr,{x,0},{t_integer,{0,2147483647}}},{integer,16777215}],
            {x,0}}.
    return.


{function, mix3, 3, 13}.
  {label,12}.
    {func_info,{atom,mixer_callee},{atom,mix3},3}.
  {label,13}.
    {allocate,0,3}.
    {call,2,{f,9}}.
    {move,{x,2},{x,1}}.
    {call,2,{f,9}}.
    {gc_bif,'*',{f,0},1,[{tr,{x,2},{t_integer,{0,16777215}}},{integer,7}],{x,1}}.
    {gc_bif,'+',{f,0},2,[{tr,{x,0},{t_integer,{0,16777215}}},{tr,{x,1},{t_integer,{0,117440505}}}],{x,0}}.
    {gc_bif,'band',{f,0},1,[{tr,{x,0},{t_integer,{0,134217720}}},{integer,16777215}],{x,0}}.
    {deallocate,0}.
    return.


{function, module_info, 0, 15}.
  {label,14}.
        {func_info,{atom,mixer_callee},{atom,module_info},0}.
  {label,15}.
    {move,{atom,mixer_callee},{x,0}}.
    {call_ext_only,1,{extfunc,erlang,get_module_info,1}}.


{function, module_info, 1, 17}.
  {label,16}.
        {func_info,{atom,mixer_callee},{atom,module_info},1}.
  {label,17}.
    {move,{x,0},{x,1}}.
    {move,{atom,mixer_callee},{x,0}}.
    {call_ext_only,2,{extfunc,erlang,get_module_info,2}}.
