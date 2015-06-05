%% ------------------------------------------------------------------%%
%%  3GPP IMS CDR File Interface Module                               %%
%%  This module has helpers to retrive cdr header fields             %%
%%  and cdr from 3gpp IMS cdr file                                   %%
%% ------------------------------------------------------------------%% 
-module(cdrfi). 
-include_lib("kernel/include/file.hrl").
-author('Anish Parameswaran <anishparameswaran@gmail.com>').


-export([test/0]). 
-define(HDR_LEN_START,4).
-define(CDR_COUNT_START,18).

-export([ load/1, fileHeader/1, cdrCount/1, unload/1,
          headerLen/1,seekToFirstCdr/1,getNextCdr/1]). 

test() -> 
 {ok,Handle} = cdrfi:load("./SampleCDRFile.dat"),
 FHPropList = cdrfi:fileHeader(Handle),
 io:format("~n File Header   : ~p~n", [FHPropList]),
 io:format("~n Header Length : ~p~n", [ cdrfi:headerLen(Handle)]),
 io:format("~n No of CDRs    : ~p~n", [ cdrfi:cdrCount(Handle)]),
 printAllCdrs(Handle),
 io:format("~n Header Length : ~p~n", [ cdrfi:headerLen(Handle)]),
 io:format("~n No of CDRs    : ~p~n", [ cdrfi:cdrCount(Handle)]).
 
printAllCdrs(Handle) ->
  NumCdrs = cdrfi:cdrCount(Handle),
  cdrfi:seekToFirstCdr(Handle),
  printCDR(Handle,0).

printCDR(Handle,Count) ->
  case cdrfi:getNextCdr(Handle) of 
    eof ->
      ok;
    {error,Reason} ->
      erlang:error(Reason);
    {ok,CDR} -> 
      io:format("~nCount: ~p ,CDR : ~p",[Count,CDR]),
      printCDR(Handle,Count+1)
  end.

cdrCount(Handle) ->
  {handle, { IoD, FileName, Size }} = Handle, 
  {ok, _ }  = file:position(IoD, { bof, ?CDR_COUNT_START }),  % position to begining of file 
  {ok,CdrCount} = file:read(IoD,4),
  binary:decode_unsigned(CdrCount,big). 

headerLen(Handle) ->
  {handle, { IoD, FileName, Size }} = Handle, 
  {ok, _ }  = file:position(IoD, { bof, ?HDR_LEN_START }),  % position to begining of file 
  {ok,HdrLen} = file:read(IoD,4),
  binary:decode_unsigned(HdrLen,big). 

unload(Handle) ->
  {handle, { IoD, FileName, Size }} = Handle, 
  ok = file:close(IoD).

load(FileName) ->
  % not handling file opening error, instead expose any failure
  {ok,FileInfo} = file:read_file_info(FileName),
  {ok, IoD }    = file:open(FileName,[read,binary]), 
  Handle = { handle, {IoD, FileName, FileInfo#file_info.size } },
  {ok, Handle}. 

fileHeader(Handle) ->
  {handle, { IoD, FileName, Size }} = Handle, 
  {ok, _ }  = file:position(IoD, { bof, 0 }),  % position to begining of file 
  {ok,Data}     =  file:read(IoD,50),
  << FileLen:4/big-unsigned-integer-unit:8,
     HdrLen:4/big-unsigned-integer-unit:8,
     HRI:3,HVI:5,LRI:3,LVI:5,
     FOTS:4/big-unsigned-integer-unit:8,
     LCDRTS:4/big-unsigned-integer-unit:8,
     NCDRS:4/big-unsigned-integer-unit:8,
     FSNO:4/big-unsigned-integer-unit:8,
     FCTR:8,NODEIP:20/binary-unit:8,LCI:8,
     RfLen:2/big-unsigned-integer-unit:8 >> = Data ,

  FHP = [ {file_len, FileLen}, {hdr_len,  HdrLen},
          {hri,      HRI},     {hvi,      HVI},
          {lri,      LRI},     {lvi,      LVI},    
          {fots,     FOTS},    {lcdrts,   LCDRTS},
          {ncdrs,    NCDRS},   {fsno,     FSNO},
          {fctr,     FCTR},    {nodeip,   NODEIP},
          {lci,      LCI},     {rf_len,   RfLen},
          {finfo_file_name, filename:basename(FileName)},
          {finfo_file_size, Size}
        ], 
  
  if 
   RfLen > 0  ->
      {ok,Rf}   =  file:read(IoD,RfLen),
      [ {rf,Rf} | FHP ] ;
   RfLen == 0 ->
      FHP  
  end.


seekToFirstCdr(Handle) -> 
  {handle, { IoD, FileName, Size }} = Handle, 
  Offset = headerLen(Handle),
  {ok, _Pos }  = file:position(IoD, { bof,  Offset}) , 
  io:format("~nOffset : ~p ; Pos : ~p~n",[Offset,_Pos]),
  {ok , {handle, { IoD, FileName, Size }}}.

getNextCdr(Handle) ->
  {handle, { IoD, FileName, Size }} = Handle, 
  %{ok, Pos }  = file:position(IoD, { cur,  0}) , 
  %io:format("~nPos :~p",[Pos]),
  case file:read(IoD,4) of 
   {ok,Data} ->
           <<CdrLen:2/big-unsigned-integer-unit:8,RI:3,VI:5,DRF:3,TS:5>> = Data ,
           case file:read(IoD,CdrLen) of 
              {ok,CDR} ->
                 { ok, [ {cdr_len, CdrLen} , 
                         {ri,      RI},
                         {vi,      VI},
                         {drf,     DRF},
                         {ts,      TS},
                         {cdr,     CDR }
                       ]
                 };
              {error,Reason} -> 
                  { error, Reason } ; 
              eof ->
                  eof 
           end ; 
   {error,Reason} -> 
        { error, Reason } ; 
   eof -> 
        eof 
  end .
 
