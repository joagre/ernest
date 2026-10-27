{module, ack_caller}.
{exports, [{ack,2}]}.
{attributes, []}.
{labels, 6}.

%% Caller saves: every x register is dead across a call, so the caller
%% keeps M - 1 in its own frame, {y,0}, and restores it after the call.
%% Every operand is a typed register asserting a small integer, so the
%% JIT emits no type or overflow test.
{function, ack, 2, 2}.
  {label,1}.
    {func_info,{atom,ack_caller},{atom,ack},2}.
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
    {gc_bif,'-',{f,0},2,[{tr,{x,0},{t_integer,{1,3}}},{integer,1}],{x,2}}.
    {gc_bif,'-',{f,0},3,[{tr,{x,1},{t_integer,{1,134217727}}},{integer,1}],{x,1}}.
    {allocate,1,3}.
    {move,{x,2},{y,0}}.
    {call,2,{f,2}}.
    {move,{x,0},{x,1}}.
    {move,{y,0},{x,0}}.
    {call_last,2,{f,2},1}.
