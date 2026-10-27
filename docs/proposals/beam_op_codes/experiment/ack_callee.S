{module, ack_callee}.
{exports, [{ack,2}]}.
{attributes, []}.
{labels, 6}.

%% Callee saves: a function preserves every x register but x0 and its
%% arguments, saving in its own frame what it overwrites and restoring it
%% before it returns or tail-calls. So the caller keeps M - 1 in {x,2}
%% across the inner call. The leaf and the second clause touch no x2 and
%% save nothing. Sound only because every value held so is a small
%% integer, which no garbage collection moves; beam_validator refuses it.
{function, ack, 2, 2}.
  {label,1}.
    {func_info,{atom,ack_callee},{atom,ack},2}.
  {label,2}.
    {test,is_eq_exact,{f,3},[{tr,{x,0},{t_integer,{0,3}}},{integer,0}]}.
    {gc_bif,'+',{f,0},2,[{tr,{x,1},{t_integer,{0,134217727}}},{integer,1}],{x,0}}.
    return.
  {label,3}.
    {test,is_eq_exact,{f,4},[{tr,{x,1},{t_integer,{0,134217727}}},{integer,0}]}.
    {gc_bif,'-',{f,0},1,[{tr,{x,0},{t_integer,{1,3}}},{integer,1}],{x,0}}.
    {move,{integer,1},{x,1}}.
    {call_only,2,{f,2}}.
  {label,4}.
    {allocate,1,3}.
    {move,{x,2},{y,0}}.
    {gc_bif,'-',{f,0},2,[{tr,{x,0},{t_integer,{1,3}}},{integer,1}],{x,2}}.
    {gc_bif,'-',{f,0},2,[{tr,{x,1},{t_integer,{1,134217727}}},{integer,1}],{x,1}}.
    {call,2,{f,2}}.
    {move,{x,0},{x,1}}.
    {move,{x,2},{x,0}}.
    {move,{y,0},{x,2}}.
    {call_last,2,{f,2},1}.
