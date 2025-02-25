unit UfrmMain;

interface

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms,
  Menus, StdCtrls, Buttons, ADODB,
  ComCtrls, ToolWin, ExtCtrls,
  inifiles,Dialogs,
  StrUtils, DB, ComObj,Variants,CPort, CoolTrayIcon;

type
  TfrmMain = class(TForm)
    PopupMenu1: TPopupMenu;
    N1: TMenuItem;
    N2: TMenuItem;
    N3: TMenuItem;
    ADOConnection1: TADOConnection;
    CoolBar1: TCoolBar;
    ToolBar1: TToolBar;
    ToolButton8: TToolButton;
    ToolButton2: TToolButton;
    Memo1: TMemo;
    BitBtn1: TBitBtn;
    BitBtn2: TBitBtn;
    Button1: TButton;
    ToolButton5: TToolButton;
    ToolButton9: TToolButton;
    OpenDialog1: TOpenDialog;
    ComPort1: TComPort;
    ComDataPacket1: TComDataPacket;
    ToolButton7: TToolButton;
    SaveDialog1: TSaveDialog;
    LYTray1: TCoolTrayIcon;
    procedure N3Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    //增加病人信息表中记录,返回该记录的唯一编号作为检验结果表的外键
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure N1Click(Sender: TObject);
    procedure ToolButton2Click(Sender: TObject);
    procedure BitBtn2Click(Sender: TObject);
    procedure BitBtn1Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure ToolButton5Click(Sender: TObject);
    procedure ComDataPacket1Packet(Sender: TObject; const Str: String);
    procedure ToolButton7Click(Sender: TObject);
    procedure ComPort1AfterOpen(Sender: TObject);
  private
    { Private declarations }
    procedure UpdateConfig;{配置文件生效}
    function MakeDBConn:boolean;
    function DIFF_decode(const Value:string):string;
    function GetSpecNo(const Value:string):string; //取得联机号
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

uses ucommfunction;

const
  CR=#$D+#$A;
  STX=#$2;ETX=#$3;ACK=#$6;NAK=#$15;
  sCryptSeed='lc';//加解密种子
  //SEPARATOR=#$1C;
  sCONNECTDEVELOP='错误!请与开发商联系!' ;
  IniSection='Setup';

var
  ConnectString:string;
  GroupName:string;//
  SpecType:string ;//
  SpecStatus:string ;//
  CombinID:string;//
  LisFormCaption:string;//
  QuaContSpecNoG:string;
  QuaContSpecNo:string;
  QuaContSpecNoD:string;
  EquipChar:string;
  H_DTR_RTS:boolean;//DTR/RTS高电位
  EquipUnid:integer;//设备唯一编号
  AnalyBarcode:boolean;

//  RFM:STRING;       //返回数据
  hnd:integer;
  bRegister:boolean;

{$R *.dfm}

function ifRegister:boolean;
var
  HDSn,RegisterNum,EnHDSn:string;
  configini:tinifile;
  pEnHDSn:Pchar;
begin
  result:=false;
  
  HDSn:=GetHDSn('C:\')+'-'+GetHDSn('D:\')+'-'+ChangeFileExt(ExtractFileName(Application.ExeName),'');

  CONFIGINI:=TINIFILE.Create(ChangeFileExt(Application.ExeName,'.ini'));
  RegisterNum:=CONFIGINI.ReadString(IniSection,'RegisterNum','');
  CONFIGINI.Free;
  pEnHDSn:=EnCryptStr(Pchar(HDSn),sCryptSeed);
  EnHDSn:=StrPas(pEnHDSn);

  if Uppercase(EnHDSn)=Uppercase(RegisterNum) then result:=true;

  if not result then messagedlg('对不起,您没有注册或注册码错误,请注册!',mtinformation,[mbok],0);
end;

function GetConnectString:string;
var
  Ini:tinifile;
  userid, password, datasource, initialcatalog: string;
  ifIntegrated:boolean;//是否集成登录模式

  pInStr,pDeStr:Pchar;
  i:integer;
begin
  result:='';
  
  Ini := tinifile.Create(ChangeFileExt(Application.ExeName,'.INI'));
  datasource := Ini.ReadString('连接数据库', '服务器', '');
  initialcatalog := Ini.ReadString('连接数据库', '数据库', '');
  ifIntegrated:=ini.ReadBool('连接数据库','集成登录模式',false);
  userid := Ini.ReadString('连接数据库', '用户', '');
  password := Ini.ReadString('连接数据库', '口令', '107DFC967CDCFAAF');
  Ini.Free;
  //======解密password
  pInStr:=pchar(password);
  pDeStr:=DeCryptStr(pInStr,sCryptSeed);
  setlength(password,length(pDeStr));
  for i :=1  to length(pDeStr) do password[i]:=pDeStr[i-1];
  //==========

  result := result + 'user id=' + UserID + ';';
  result := result + 'password=' + Password + ';';
  result := result + 'data source=' + datasource + ';';
  result := result + 'Initial Catalog=' + initialcatalog + ';';
  result := result + 'provider=' + 'SQLOLEDB.1' + ';';
  //Persist Security Info,表示ADO在数据库连接成功后是否保存密码信息
  //ADO缺省为True,ADO.net缺省为False
  //程序中会传ADOConnection信息给TADOLYQuery,故设置为True
  result := result + 'Persist Security Info=True;';
  if ifIntegrated then
    result := result + 'Integrated Security=SSPI;';
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  ComDataPacket1.StartString:=STX;
  ComDataPacket1.StopString:=ETX;

  ConnectString:=GetConnectString;
  UpdateConfig;
  if ifRegister then bRegister:=true else bRegister:=false;  

  Caption:='数据接收服务'+ExtractFileName(Application.ExeName);
  lytray1.Hint:='数据接收服务'+ExtractFileName(Application.ExeName);
end;

procedure TfrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  action:=caNone;
  LYTray1.HideMainForm;
end;

procedure TfrmMain.N3Click(Sender: TObject);
begin
  if (MessageDlg('退出后将不再接收设备数据,确定退出吗？', mtWarning, [mbYes, mbNo], 0) <> mrYes) then exit;
  application.Terminate;
end;

procedure TfrmMain.N1Click(Sender: TObject);
begin
  LYTray1.ShowMainForm;
end;

procedure TfrmMain.UpdateConfig;
var
  INI:tinifile;
  CommName,BaudRate,DataBit,StopBit,ParityBit:string;
  autorun:boolean;
begin
  ini:=TINIFILE.Create(ChangeFileExt(Application.ExeName,'.ini'));

  CommName:=ini.ReadString(IniSection,'串口选择','COM1');
  BaudRate:=ini.ReadString(IniSection,'波特率','9600');
  DataBit:=ini.ReadString(IniSection,'数据位','8');
  StopBit:=ini.ReadString(IniSection,'停止位','1');
  ParityBit:=ini.ReadString(IniSection,'校验位','None');
  H_DTR_RTS:=ini.readBool(IniSection,'DTR/RTS高电位',false);
  autorun:=ini.readBool(IniSection,'开机自动运行',false);
  AnalyBarcode:=ini.readBool(IniSection,'解析Mejer-700I条码',false);

  GroupName:=trim(ini.ReadString(IniSection,'工作组',''));
  EquipChar:=trim(uppercase(ini.ReadString(IniSection,'仪器字母','')));//读出来是大写就万无一失了
  SpecType:=ini.ReadString(IniSection,'默认样本类型','');
  SpecStatus:=ini.ReadString(IniSection,'默认样本状态','');
  CombinID:=ini.ReadString(IniSection,'组合项目代码','');

  LisFormCaption:=ini.ReadString(IniSection,'检验系统窗体标题','');
  EquipUnid:=ini.ReadInteger(IniSection,'设备唯一编号',-1);

  QuaContSpecNoG:=ini.ReadString(IniSection,'高值质控联机号','9999');
  QuaContSpecNo:=ini.ReadString(IniSection,'常值质控联机号','9998');
  QuaContSpecNoD:=ini.ReadString(IniSection,'低值质控联机号','9997');

  ini.Free;

  OperateLinkFile(application.ExeName,'\'+ChangeFileExt(ExtractFileName(Application.ExeName),'.lnk'),15,autorun);
  ComPort1.Close;
  ComPort1.Port:=CommName;
  if BaudRate='1200' then
    ComPort1.BaudRate:=br1200
    else if BaudRate='2400' then
      ComPort1.BaudRate:=br2400
    else if BaudRate='4800' then
      ComPort1.BaudRate:=br4800
      else if BaudRate='9600' then
        ComPort1.BaudRate:=br9600
        else if BaudRate='19200' then
          ComPort1.BaudRate:=br19200
          else ComPort1.BaudRate:=br9600;
  if DataBit='5' then
    ComPort1.DataBits:=dbFive
    else if DataBit='6' then
      ComPort1.DataBits:=dbSix
      else if DataBit='7' then
        ComPort1.DataBits:=dbSeven
        else if DataBit='8' then
          ComPort1.DataBits:=dbEight
          else ComPort1.DataBits:=dbEight;
  if StopBit='1' then
    ComPort1.StopBits:=sbOneStopBit
    else if StopBit='2' then
      ComPort1.StopBits:=sbTwoStopBits
      else if StopBit='1.5' then
        ComPort1.StopBits:=sbOne5StopBits
        else ComPort1.StopBits:=sbOneStopBit;
  if ParityBit='None' then
    ComPort1.Parity.Bits:=prNone
    else if ParityBit='Odd' then
      ComPort1.Parity.Bits:=prOdd
      else if ParityBit='Even' then
        ComPort1.Parity.Bits:=prEven
        else if ParityBit='Mark' then
          ComPort1.Parity.Bits:=prMark
          else if ParityBit='Space' then
            ComPort1.Parity.Bits:=prSpace
            else ComPort1.Parity.Bits:=prNone;
  try
    ComPort1.Open;
  except
    showmessage('串口'+ComPort1.Port+'打开失败!');
  end;
end;

function TfrmMain.GetSpecNo(const Value:string):string; //取得联机号
const
  spBs='NO.';
var
  s1Pos,SpacePos,spBsLen:integer;
  vValue:string;
  isGeb,isJuniorII,ifAM4290,isN600,isAve733:boolean;
  ls:TStrings;
begin
    spBsLen:=Length(spBs);
    s1Pos:=pos(spbs,uppercase(Value));
    if s1Pos<=0 then
    begin
      s1Pos:=pos('#',uppercase(Value));//Bayer CLINITEK 200+,CliniTek100,GEB600,MEJER600II,Mejer-600III
      spBsLen:=1;
      if s1Pos<=0 then
      begin
        s1Pos:=pos('NO',uppercase(Value));//北京华晟H-1、爱威AVE-733A用NO做样本号的标识.注意的是:Normal中也存在NO
        spBsLen:=2;
      end;
    end;

    isGeb:=pos('GEB-',Value)>0;
    isJuniorII:=pos('SEQ.NO.',uppercase(Value))>0;
    ifAM4290:=ManyStr(',',Pchar(Value))>20;//实际上AM4290的逗号不止这个数
    isN600:=pos('Date:',Value)>0;//长春迪瑞N-600
    isAve733:=pos('MachineSN',Value)>0;//爱威AVE-733A

    vValue:=Value;
    
    delete(vValue,1,s1Pos-1);
    
    SpacePos:=pos(' ',vValue);
    if isGeb THEN SpacePos:=pos(#$D,vValue);//Geb200
    if isJuniorII THEN SpacePos:=pos(#$D,vValue);//JuniorII
    if isN600 THEN SpacePos:=pos(#$D,vValue);//长春迪瑞N-600
    if isAve733 then SpacePos:=pos(#$D,vValue);//爱威AVE-733A

    result:=copy(vValue,spBsLen+1,SpacePos-spBsLen-1);
    
    if ifAM4290 then
    begin
      ls:=TStringList.Create;
      ExtractStrings([','],[],Pchar(Value),ls);
      if ls.Count>=3 then result:=ls[2];
      ls.Free;
    end;
    
    result:=stringreplace(result,'-','',[rfReplaceAll,rfIgnoreCase]);//Geb200
    result:='0000'+trim(result);//JuniorII需要trim
    result:=rightstr(result,4);
end;

function TfrmMain.DIFF_decode(const Value:string):string;
begin
  result:=stringreplace(Value,'#',' ',[rfReplaceAll,rfIgnoreCase]);
  result:=trim(result);
end;

function StrToList(const SourStr:string;const Separator:string):TStrings;
//根据指定的分隔字符串(Separator)将字符串(SourStr)导入到字符串列表中
var
  vSourStr,s:string;
  ll,lll:integer;
begin
  vSourStr:=SourStr;
  Result := TStringList.Create;
  lll:=length(Separator);

  while pos(Separator,vSourStr)<>0 do
  begin
    ll:=pos(Separator,vSourStr);
    Result.Add(copy(vSourStr,1,ll-1));
    delete(vSourStr,1,ll+lll-1);
  end;
  Result.Add(vSourStr);
  s:=vSourStr;
end;

function TListToVariant(AList:TList):OleVariant;
var
  P:Pointer;
begin
  Result:=VarArrayCreate([0,Sizeof(TList)],varByte);
  P:=VarArrayLock(Result);
  Move(AList,P^,Sizeof(TList));
  VarArrayUnLock(Result);
end;

function TfrmMain.MakeDBConn:boolean;
var
  newconnstr,ss: string;
  Label labReadIni;
begin
  result:=false;

  labReadIni:
  newconnstr := GetConnectString;
  try
    ADOConnection1.Connected := false;
    ADOConnection1.ConnectionString := newconnstr;
    ADOConnection1.Connected := true;
    result:=true;
  except
  end;
  if not result then
  begin
    ss:='服务器'+#2+'Edit'+#2+#2+'0'+#2+#2+#3+
        '数据库'+#2+'Edit'+#2+#2+'0'+#2+#2+#3+
        '集成登录模式'+#2+'CheckListBox'+#2+#2+'0'+#2+#2+#3+
        '用户'+#2+'Edit'+#2+#2+'0'+#2+#2+#3+
        '口令'+#2+'Edit'+#2+#2+'0'+#2+#2+'1';
    if ShowOptionForm('连接数据库','连接数据库',Pchar(ss),Pchar(ChangeFileExt(Application.ExeName,'.ini'))) then
      goto labReadIni else application.Terminate;
  end;
end;

procedure TfrmMain.ToolButton2Click(Sender: TObject);
var
  ss:string;
  lsComPort:TStrings;
  sComPort:String;
begin
  //获取串口列表 begin
  lsComPort := TStringList.Create;
  EnumComPorts(lsComPort);
  sComPort:=lsComPort.Text;
  lsComPort.Free;
  //获取串口列表 end

  ss:='串口选择'+#2+'Combobox'+#2+sComPort+#2+'0'+#2+#2+#3+
      '波特率'+#2+'Combobox'+#2+'19200'+#13+'9600'+#13+'4800'+#13+'2400'+#13+'1200'+#2+'0'+#2+#2+#3+
      '数据位'+#2+'Combobox'+#2+'8'+#13+'7'+#13+'6'+#13+'5'+#2+'0'+#2+#2+#3+
      '停止位'+#2+'Combobox'+#2+'1'+#13+'1.5'+#13+'2'+#2+'0'+#2+#2+#3+
      '校验位'+#2+'Combobox'+#2+'None'+#13+'Even'+#13+'Odd'+#13+'Mark'+#13+'Space'+#2+'0'+#2+#2+#3+
      'DTR/RTS高电位'+#2+'CheckListBox'+#2+#2+'0'+#2+#2+#3+
      '工作组'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      '仪器字母'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      '检验系统窗体标题'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      '默认样本类型'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      '默认样本状态'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      '组合项目代码'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      '开机自动运行'+#2+'CheckListBox'+#2+#2+'1'+#2+#2+#3+
      '解析Mejer-700I条码'+#2+'CheckListBox'+#2+#2+'1'+#2+#2+#3+
      '设备唯一编号'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      '高值质控联机号'+#2+'Edit'+#2+#2+'2'+#2+#2+#3+
      '常值质控联机号'+#2+'Edit'+#2+#2+'2'+#2+#2+#3+
      '低值质控联机号'+#2+'Edit'+#2+#2+'2'+#2+#2;

  if ShowOptionForm('',Pchar(IniSection),Pchar(ss),Pchar(ChangeFileExt(Application.ExeName,'.ini'))) then
	  UpdateConfig;
end;

procedure TfrmMain.BitBtn2Click(Sender: TObject);
begin
  Memo1.Lines.Clear;
end;

procedure TfrmMain.BitBtn1Click(Sender: TObject);
begin
  SaveDialog1.DefaultExt := '.txt';
  SaveDialog1.Filter := 'txt (*.txt)|*.txt';
  if not SaveDialog1.Execute then exit;
  memo1.Lines.SaveToFile(SaveDialog1.FileName);
  showmessage('保存成功!');
end;

procedure TfrmMain.Button1Click(Sender: TObject);
var
  ls:Tstrings;
begin
  OpenDialog1.DefaultExt := '.txt';
  OpenDialog1.Filter := 'txt (*.txt)|*.txt';
  if not OpenDialog1.Execute then exit;
  ls:=Tstringlist.Create;
  ls.LoadFromFile(OpenDialog1.FileName);
  ComDataPacket1Packet(nil,ls.Text);
  ls.Free;
end;

procedure TfrmMain.ToolButton5Click(Sender: TObject);
var
  ss:string;
begin
  ss:='RegisterNum'+#2+'Edit'+#2+#2+'0'+#2+'将该窗体标题栏上的字符串发给开发者,以获取注册码'+#2;
  if bRegister then exit;
  if ShowOptionForm(Pchar('注册:'+GetHDSn('C:\')+'-'+GetHDSn('D:\')+'-'+ChangeFileExt(ExtractFileName(Application.ExeName),'')),Pchar(IniSection),Pchar(ss),Pchar(ChangeFileExt(Application.ExeName,'.ini'))) then
    if ifRegister then bRegister:=true else bRegister:=false;
end;

procedure TfrmMain.ComDataPacket1Packet(Sender: TObject;
  const Str: String);
VAR
  SpecNo:string;
  ls,ls5:TStrings;
  i:integer;
  dlttype:string;
  sValue:string;
  //FInts:IData2Lis;
  FInts:OleVariant;
  ReceiveItemInfo:OleVariant;
  isJuniorII,ifAM4290,isAve733:BOOLEAN;
  Barcode:String;
begin
  if length(memo1.Lines.Text)>=60000 then memo1.Lines.Clear;//memo只能接受64K个字符
  memo1.Lines.Add(Str);

  SpecNo:=GetSpecNo(Str);

  isJuniorII:=pos('SEQ.NO.',uppercase(Str))>0;
  ifAM4290:=ManyStr(',',Pchar(Str))>20;//实际上AM4290的逗号不止这个数
  isAve733:=pos('MachineSN',Str)>0;//爱威AVE-733A

  ls:=TStringList.Create;
  ExtractStrings([#$D,#$A],[],Pchar(Str),ls);//将每行导入到字符串列表中

  ReceiveItemInfo:=VarArrayCreate([0,ls.Count-1],varVariant);

  for i :=0 to ls.Count-1 do
  begin
    if AnalyBarcode then//解析Mejer-700I条码.南沙街道要求将条码写入【门诊/住院号】
    begin
      if i=3 then
      begin
        ls5:=TStringList.Create;
        ExtractStrings([' '],[],Pchar(ls[i]),ls5);
        if ls5.Count>1 then Barcode:=ls5[1];
        ls5.Free;
      end;
    end;
    
    dlttype:=trim(copy(ls[i],1,4));
    IF isJuniorII THEN dlttype:=trim(copy(ls[i],3,3));
    if ifAM4290 then dlttype:=trim(copy(ls[i],1,pos(',',ls[i])-1));
    if isAve733 then dlttype:=trim(copy(ls[i],1,3));
    dlttype:=stringreplace(dlttype,'*','',[]);//CliniTek
    sValue:=trim(copy(ls[i],5,MaxInt));
    IF isJuniorII THEN sValue:=trim(copy(ls[i],7,MaxInt));
    if ifAM4290 then
    begin
      sValue:=copy(ls[i],pos(',',ls[i])+1,PosExt(',',Pchar(ls[i]),3)-pos(',',ls[i])-1);
      sValue:=StringReplace(sValue,',','',[rfReplaceAll,rfIgnoreCase]);
    end;
    if isAve733 then sValue:=trim(copy(ls[i],4,MaxInt));
    if isAve733 and not SameText(dlttype,'PH') and not SameText(dlttype,'SG') and (sValue='1') then sValue:='±';
    sValue:=StringReplace(sValue,'mmol/L','',[rfReplaceAll,rfIgnoreCase]);
    sValue:=StringReplace(sValue,'Leu/uL','',[rfReplaceAll,rfIgnoreCase]);//HT-150
    sValue:=StringReplace(sValue,'Cells/uL','',[rfReplaceAll,rfIgnoreCase]);//Geb200
    sValue:=StringReplace(sValue,'Cell/uL','',[rfReplaceAll,rfIgnoreCase]);
    sValue:=StringReplace(sValue,'mg/L','',[rfReplaceAll,rfIgnoreCase]);//HT-150
    sValue:=StringReplace(sValue,'g/L','',[rfReplaceAll,rfIgnoreCase]);
    sValue:=StringReplace(sValue,'umol/L','',[rfReplaceAll,rfIgnoreCase]);
    sValue:=StringReplace(sValue,'mg/dl','',[rfReplaceAll,rfIgnoreCase]);//JuniorII
    sValue:=StringReplace(sValue,'ery/uL','',[rfReplaceAll,rfIgnoreCase]);//GEB-600
    sValue:=StringReplace(sValue,'EU/dL','',[rfReplaceAll,rfIgnoreCase]);//CliniTek100
    sValue:=StringReplace(sValue,'/ul','',[rfReplaceAll,rfIgnoreCase]);//JuniorII
    //sValue:=StringReplace(sValue,'neg','阴性(-)',[rfReplaceAll,rfIgnoreCase]);//JuniorII
    //sValue:=StringReplace(sValue,'norm','正常',[rfReplaceAll,rfIgnoreCase]);//JuniorII
    sValue:=trim(sValue);

    ReceiveItemInfo[i]:=VarArrayof([dlttype,sValue,'','']);
  end;
  ls.Free;
  
  if bRegister then
  begin
    //FInts :=CoData2Lis.CreateRemote('');//暂时仅支持本机
    FInts :=CreateOleObject('Data2LisSvr.Data2Lis');
    FInts.fData2Lis(ReceiveItemInfo,(SpecNo),'',
      (GroupName),(SpecType),(SpecStatus),(EquipChar),
      (CombinID),'{!@#}{!@#}{!@#}{!@#}'+Barcode,(LisFormCaption),(ConnectString),
      (QuaContSpecNoG),(QuaContSpecNo),(QuaContSpecNoD),'',
      false,true,'常规',
      '',
      EquipUnid,
      '','','','',
      -1,-1,-1,-1,
      -1,-1,-1,-1,
      false,false,false,false);
    //if FInts<>nil then FInts:=nil;
    if not VarIsEmpty(FInts) then FInts:= unAssigned;
  end;
end;

procedure TfrmMain.ToolButton7Click(Sender: TObject);
begin
  if MakeDBConn then ConnectString:=GetConnectString;
end;

procedure TfrmMain.ComPort1AfterOpen(Sender: TObject);
begin
  if H_DTR_RTS then
  begin
    ComPort1.SetDTR(true);
    ComPort1.SetRTS(true);
  end;
end;

initialization
    hnd := CreateMutex(nil, True, Pchar(ExtractFileName(Application.ExeName)));
    if GetLastError = ERROR_ALREADY_EXISTS then
    begin
        MessageBox(application.Handle,pchar('该程序已在运行中！'),
                    '系统提示',MB_OK+MB_ICONinformation);   
        Halt;
    end;

finalization
    if hnd <> 0 then CloseHandle(hnd);

end.
