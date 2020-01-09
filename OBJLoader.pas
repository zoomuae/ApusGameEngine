// Import module for InterQuakeModel format (IQM/IQE)
// Copyright (C) 2019 Apus Software (www.apus-software.com)
// Author: Ivan Polyacov (cooler@tut.by, ivan@apus-software.com)
{$R+}
unit OBJLoader;
interface
uses MyServis,Model3D;

 function Load3DModelOBJ(fname:string):TModel3D; overload;
 function Load3DModelOBJ(data:ByteArray):TModel3D; overload;


implementation
 uses SysUtils,Geom3d,Geom2d,Structs;

 function FetchLine(var pb:PByte;var size:integer;out st:AnsiString):boolean;
  var
   l:integer;
  begin
   if size<=0 then exit(false);
   result:=true;
   SetLength(st,250);
   l:=0;
   while (pb^<>10) and (size>0) do begin
    if (pb^>=32) and (l<249) then begin
     inc(l);
     st[l]:=AnsiChar(pb^);
    end;
    inc(pb); dec(size);
   end;
   if size>0 then inc(pb);
   SetLength(st,l);
  end;

 function ParseVector3(sa:AStringArr):TPoint3s;
  begin
   ASSERT(length(sa)>=4);
   result.x:=-ParseFloat(sa[1]);
   result.y:=-ParseFloat(sa[3]);
   result.z:=ParseFloat(sa[2]);
  end;

 function ParseVector2(sa:AStringArr):TPoint2s;
  begin
   ASSERT(length(sa)>=3);
   result.x:=ParseFloat(sa[1]);
   result.y:=1-ParseFloat(sa[2]);
  end;

 function LoadOBJInternal(data:ByteArray):TModel3D;
  var
   line:AnsiString;
   m:TModel3D;
   pb:PByte;
   size:integer;
   sa:AStringArr;
   points,normals:array of TPoint3s;
   uv:array of TPoint2s;
   pCnt,pSize:integer;
   nCnt,nSize:integer;
   tCnt,tSize:integer;
   vCnt,vSize:integer;
   iCnt,iSize:integer;
   pnt:TPoint3s;
   vHash:TSimpleHashAS;

  function GetVertexIdx(st:AnsiString):integer;
   var
    sa:AStringArr;
    idx:integer;
   begin
    result:=vHash.Get(st);
    if result>=0 then exit;
    sa:=SplitA('/',st);
    result:=vCnt;
    vHash.Put(st,result);
    // Get data
    idx:=StrToIntDef(sa[0],1)-1;
    m.vp[vCnt].x:=points[idx].x;
    m.vp[vCnt].y:=points[idx].y;
    m.vp[vCnt].z:=points[idx].z;
    if high(sa)>=1 then begin
     idx:=StrToIntDef(sa[1],1)-1;
     m.vt[vCnt].x:=uv[idx].x;
     m.vt[vCnt].y:=uv[idx].y;
    end;
    if high(sa)>=2 then begin
     idx:=StrToIntDef(sa[2],1)-1;
     m.vn[vCnt].x:=normals[idx].x;
     m.vn[vCnt].y:=normals[idx].y;
     m.vn[vCnt].z:=normals[idx].z;
    end;
    inc(vCnt);
    if vCnt>=vSize then begin
     inc(vSize,vSize div 2);
     SetLength(m.vp,vSize);
     SetLength(m.vn,vSize);
     SetLength(m.vt,vSize);
    end;
   end;

  procedure AddFace(sa:AStringArr);
   var
    v3:integer;
   begin
    if high(sa)<3 then exit;
    if iCnt+3>=iSize then begin
     inc(iSize,iSize div 2);
     SetLength(m.trgList,iSize);
    end;
    m.trgList[iCnt]:=GetVertexIdx(sa[1]); inc(icnt);
    m.trgList[iCnt]:=GetVertexIdx(sa[2]); inc(icnt);
    m.trgList[iCnt]:=GetVertexIdx(sa[3]); inc(icnt);
   end;

  begin
   m:=TModel3D.Create;
   vHash.Init(500);

    pb:=@data[0];
    size:=length(data);
    // Points
    pCnt:=0; pSize:=10+size div 80;
    SetLength(points,pSize);
    // Normals
    nCnt:=0; nSize:=10+size div 80;
    SetLength(normals,nSize);
    // UV
    tCnt:=0; tSize:=10+size div 80;
    SetLength(uv,tSize);
    // Indices
    iCnt:=0; iSize:=10+size div 25;
    SetLength(m.trgList,iSize);
    // Vertices
    vCnt:=0; vSize:=10+size div 60;
    SetLength(m.vp,vSize);
    SetLength(m.vn,vSize);
    SetLength(m.vt,vSize);


    while FetchLine(pb,size,line) do begin
     if line='' then continue;
     if line[1]='#' then continue;
     sa:=SplitA(' ',line);
     if length(sa)<2 then continue;
     if sa[0]='v' then begin
      // Vertex definition
      points[pCnt]:=ParseVector3(sa);
      inc(pCnt);
      if pCnt>=pSize then begin
       inc(pSize,pSize div 2);
       SetLength(points,pSize);
      end;
     end else
     if sa[0]='vn' then begin
      // Normal definition
      normals[nCnt]:=ParseVector3(sa);
      inc(nCnt);
      if nCnt>=nSize then begin
       inc(nSize,nSize div 2);
       SetLength(normals,nSize);
      end;
     end else
     if sa[0]='vt' then begin
      // Texture UV definition
      uv[tCnt]:=ParseVector2(sa);
      inc(tCnt);
      if tCnt>=tSize then begin
       inc(tSize,tSize div 2);
       SetLength(uv,tSize);
      end;
     end else
     if sa[0]='f' then begin
      // Face definition
      AddFace(sa);
     end;
    end;

    // Final size
    SetLength(m.vp,vCnt);
    SetLength(m.vn,vCnt);
    SetLength(m.vt,vCnt);
    SetLength(m.trgList,iCnt);

    result:=m;
  end;


 function Load3DModelOBJ(fname:string):TModel3D;
  begin
   try
    result:=LoadOBJInternal(LoadFileAsBytes(fname));
   except
    on e:Exception do raise EError.Create('Error in LoadOBJ('+fname+'): '+ExceptionMsg(e));
   end;
  end;

 function Load3DModelOBJ(data:ByteArray):TModel3D;
  begin
   try
    result:=LoadOBJInternal(data);
   except
    on e:Exception do raise EError.Create('Error in LoadOBJ: '+ExceptionMsg(e));
   end;
  end;

end.