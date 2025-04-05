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
    //���Ӳ�����Ϣ���м�¼,���ظü�¼��Ψһ�����Ϊ������������
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
    procedure UpdateConfig;{�����ļ���Ч}
    function MakeDBConn:boolean;
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

uses ucommfunction, PerlRegEx;

const
  CR=#$D+#$A;
  STX=#$2;ETX=#$3;ACK=#$6;NAK=#$15;
  sCryptSeed='lc';//�ӽ�������
  //SEPARATOR=#$1C;
  sCONNECTDEVELOP='����!���뿪������ϵ!' ;
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
  H_DTR_RTS:boolean;//DTR/RTS�ߵ�λ
  EquipUnid:integer;//�豸Ψһ���
  AnalyBarcode:boolean;
  RegExSpecNo:String;//ƥ�������ŵ�����
  RegExDlttype:String;//ƥ��������ʶ������
  RegExValue:String;//ƥ�������������
  StartString:String;
  StopString:String;

//  RFM:STRING;       //��������
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

  if not result then messagedlg('�Բ���,��û��ע���ע�������,��ע��!',mtinformation,[mbok],0);
end;

function GetConnectString:string;
var
  Ini:tinifile;
  userid, password, datasource, initialcatalog: string;
  ifIntegrated:boolean;//�Ƿ񼯳ɵ�¼ģʽ

  pInStr,pDeStr:Pchar;
  i:integer;
begin
  result:='';
  
  Ini := tinifile.Create(ChangeFileExt(Application.ExeName,'.INI'));
  datasource := Ini.ReadString('�������ݿ�', '������', '');
  initialcatalog := Ini.ReadString('�������ݿ�', '���ݿ�', '');
  ifIntegrated:=ini.ReadBool('�������ݿ�','���ɵ�¼ģʽ',false);
  userid := Ini.ReadString('�������ݿ�', '�û�', '');
  password := Ini.ReadString('�������ݿ�', '����', '107DFC967CDCFAAF');
  Ini.Free;
  //======����password
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
  //Persist Security Info,��ʾADO�����ݿ����ӳɹ����Ƿ񱣴�������Ϣ
  //ADOȱʡΪTrue,ADO.netȱʡΪFalse
  //�����лᴫADOConnection��Ϣ��TADOLYQuery,������ΪTrue
  result := result + 'Persist Security Info=True;';
  if ifIntegrated then
    result := result + 'Integrated Security=SSPI;';
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  ConnectString:=GetConnectString;
  UpdateConfig;

  //�������滻.todo:ͨ���滻����
  StartString:=StringReplace(StartString, '$02', #$02, [rfReplaceAll]);
  StartString:=StringReplace(StartString, '$7F', #$7F, [rfReplaceAll]);//HT-150��HT-MA4280KB
  StartString:=StringReplace(StartString, '$1B', #$1B, [rfReplaceAll]);//��̫-BIOT-YG-II��������II��
  StartString:=StringReplace(StartString, '$01', #$01, [rfReplaceAll]);//��̫-BIOT-YG-II��������II��
  StartString:=StringReplace(StartString, '$1C', #$1C, [rfReplaceAll]);//��̫-BIOT-YG-II��������II��
  StopString:=StringReplace(StopString, '$03', #$03, [rfReplaceAll]);
  StopString:=StringReplace(StopString, '$7F', #$7F, [rfReplaceAll]);//HT-150��HT-MA4280KB
  StopString:=StringReplace(StopString, '$0D', #$0D, [rfReplaceAll]);//��̫-BIOT-YG-II��������II��
  StopString:=StringReplace(StopString, '$0A', #$0A, [rfReplaceAll]);//��̫-BIOT-YG-II��������II��
  StopString:=StringReplace(StopString, '$1B', #$1B, [rfReplaceAll]);//��̫-BIOT-YG-II��������II��
  
  ComDataPacket1.StartString:=StartString;//����StartString��UpdateConfig�и�ֵ,�ʸô�����UpdateConfig֮��
  ComDataPacket1.StopString:=StopString;//����StopString��UpdateConfig�и�ֵ,�ʸô�����UpdateConfig֮��
  
  if ifRegister then bRegister:=true else bRegister:=false;  

  Caption:='���ݽ��շ���'+ExtractFileName(Application.ExeName);
  lytray1.Hint:='���ݽ��շ���'+ExtractFileName(Application.ExeName);
end;

procedure TfrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  action:=caNone;
  LYTray1.HideMainForm;
end;

procedure TfrmMain.N3Click(Sender: TObject);
begin
  if (MessageDlg('�˳��󽫲��ٽ����豸����,ȷ���˳���', mtWarning, [mbYes, mbNo], 0) <> mrYes) then exit;
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

  CommName:=ini.ReadString(IniSection,'����ѡ��','COM1');
  BaudRate:=ini.ReadString(IniSection,'������','9600');
  DataBit:=ini.ReadString(IniSection,'����λ','8');
  StopBit:=ini.ReadString(IniSection,'ֹͣλ','1');
  ParityBit:=ini.ReadString(IniSection,'У��λ','None');
  H_DTR_RTS:=ini.readBool(IniSection,'DTR/RTS�ߵ�λ',false);
  autorun:=ini.readBool(IniSection,'�����Զ�����',false);
  AnalyBarcode:=ini.readBool(IniSection,'����Mejer-700I����',false);
  RegExSpecNo:=ini.ReadString(IniSection,'ƥ�������ŵ�����','');
  RegExDlttype:=ini.ReadString(IniSection,'ƥ��������ʶ������','');
  RegExValue:=ini.ReadString(IniSection,'ƥ�������������','');
  StartString:=ini.ReadString(IniSection,'StartString','');
  if StartString='' then StartString:='$02';
  StopString:=ini.ReadString(IniSection,'StopString','');
  if StopString='' then StopString:='$03';

  GroupName:=trim(ini.ReadString(IniSection,'������',''));
  EquipChar:=trim(uppercase(ini.ReadString(IniSection,'������ĸ','')));//�������Ǵ�д������һʧ��
  SpecType:=ini.ReadString(IniSection,'Ĭ����������','');
  SpecStatus:=ini.ReadString(IniSection,'Ĭ������״̬','');
  CombinID:=ini.ReadString(IniSection,'�����Ŀ����','');

  LisFormCaption:=ini.ReadString(IniSection,'����ϵͳ�������','');
  EquipUnid:=ini.ReadInteger(IniSection,'�豸Ψһ���',-1);

  QuaContSpecNoG:=ini.ReadString(IniSection,'��ֵ�ʿ�������','9999');
  QuaContSpecNo:=ini.ReadString(IniSection,'��ֵ�ʿ�������','9998');
  QuaContSpecNoD:=ini.ReadString(IniSection,'��ֵ�ʿ�������','9997');

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
    showmessage('����'+ComPort1.Port+'��ʧ��!');
  end;
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
    ss:='������'+#2+'Edit'+#2+#2+'0'+#2+#2+#3+
        '���ݿ�'+#2+'Edit'+#2+#2+'0'+#2+#2+#3+
        '���ɵ�¼ģʽ'+#2+'CheckListBox'+#2+#2+'0'+#2+#2+#3+
        '�û�'+#2+'Edit'+#2+#2+'0'+#2+#2+#3+
        '����'+#2+'Edit'+#2+#2+'0'+#2+#2+'1';
    if ShowOptionForm('�������ݿ�','�������ݿ�',Pchar(ss),Pchar(ChangeFileExt(Application.ExeName,'.ini'))) then
      goto labReadIni else application.Terminate;
  end;
end;

procedure TfrmMain.ToolButton2Click(Sender: TObject);
var
  ss:string;
  lsComPort:TStrings;
  sComPort:String;
begin
  //��ȡ�����б� begin
  lsComPort := TStringList.Create;
  EnumComPorts(lsComPort);
  sComPort:=lsComPort.Text;
  lsComPort.Free;
  //��ȡ�����б� end

  ss:='����ѡ��'+#2+'Combobox'+#2+sComPort+#2+'0'+#2+#2+#3+
      '������'+#2+'Combobox'+#2+'19200'+#13+'9600'+#13+'4800'+#13+'2400'+#13+'1200'+#2+'0'+#2+#2+#3+
      '����λ'+#2+'Combobox'+#2+'8'+#13+'7'+#13+'6'+#13+'5'+#2+'0'+#2+#2+#3+
      'ֹͣλ'+#2+'Combobox'+#2+'1'+#13+'1.5'+#13+'2'+#2+'0'+#2+#2+#3+
      'У��λ'+#2+'Combobox'+#2+'None'+#13+'Even'+#13+'Odd'+#13+'Mark'+#13+'Space'+#2+'0'+#2+#2+#3+
      'DTR/RTS�ߵ�λ'+#2+'CheckListBox'+#2+#2+'0'+#2+#2+#3+
      '������'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      '������ĸ'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      '����ϵͳ�������'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      'Ĭ����������'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      'Ĭ������״̬'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      '�����Ŀ����'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      '�����Զ�����'+#2+'CheckListBox'+#2+#2+'1'+#2+#2+#3+
      'StartString'+#2+'Edit'+#2+#2+'1'+#2+'16���Ʊ���2λ.��Begin $02'+#2+#3+
      'StopString'+#2+'Edit'+#2+#2+'1'+#2+'16���Ʊ���2λ.��End $03'+#2+#3+
      'ƥ�������ŵ�����'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      'ƥ��������ʶ������'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      'ƥ�������������'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      '����Mejer-700I����'+#2+'CheckListBox'+#2+#2+'1'+#2+#2+#3+
      '�豸Ψһ���'+#2+'Edit'+#2+#2+'1'+#2+#2+#3+
      '��ֵ�ʿ�������'+#2+'Edit'+#2+#2+'2'+#2+#2+#3+
      '��ֵ�ʿ�������'+#2+'Edit'+#2+#2+'2'+#2+#2+#3+
      '��ֵ�ʿ�������'+#2+'Edit'+#2+#2+'2'+#2+#2;

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
  showmessage('����ɹ�!');
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
  ss:='RegisterNum'+#2+'Edit'+#2+#2+'0'+#2+'���ô���������ϵ��ַ�������������,�Ի�ȡע����'+#2;
  if bRegister then exit;
  if ShowOptionForm(Pchar('ע��:'+GetHDSn('C:\')+'-'+GetHDSn('D:\')+'-'+ChangeFileExt(ExtractFileName(Application.ExeName),'')),Pchar(IniSection),Pchar(ss),Pchar(ChangeFileExt(Application.ExeName,'.ini'))) then
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
  ifAM4290,isAve733:BOOLEAN;
  Barcode:String;
  PerlRegEx:TPerlRegEx;
  ifMatch:Boolean;
begin
  if length(memo1.Lines.Text)>=60000 then memo1.Lines.Clear;//memoֻ�ܽ���64K���ַ�
  memo1.Lines.Add(Str);

  ifMatch:=False;//��ʼ��

  //��������� begin
  PerlRegEx:=TPerlRegEx.Create;
  PerlRegEx.RegEx:=RegExSpecNo;
  //PerlRegEx.Options:=PerlRegEx.Options+[preUnGreedy];//������ʽ�п���̰��ģʽ,�Ա���õ������
  PerlRegEx.Subject:=Str;
  Try
    ifMatch:=PerlRegEx.Match;//������ʽΪ�ա��﷨����ȷ��Match�������׳��쳣
  except
    on E:Exception do
    begin
      memo1.Lines.Add('ƥ�������ű���:'+E.Message);
    end;
  end;  
  if ifMatch then
  begin
    SpecNo:=PerlRegEx.MatchedText;
    SpecNo:=StringReplace(SpecNo,'ID:','',[rfReplaceAll,rfIgnoreCase]);
    SpecNo:=StringReplace(SpecNo,'(','',[rfReplaceAll,rfIgnoreCase]);
    SpecNo:=StringReplace(SpecNo,'Seq.no.','',[rfReplaceAll,rfIgnoreCase]);
    SpecNo:=StringReplace(SpecNo,'No.','',[rfReplaceAll,rfIgnoreCase]);
    SpecNo:=StringReplace(SpecNo,'NO','',[rfReplaceAll,rfIgnoreCase]);
    SpecNo:=StringReplace(SpecNo,'#','',[rfReplaceAll,rfIgnoreCase]);
    SpecNo:=StringReplace(SpecNo,',N','',[rfReplaceAll,rfIgnoreCase]);
    SpecNo:=StringReplace(SpecNo,',','',[rfReplaceAll,rfIgnoreCase]);
    SpecNo:=stringreplace(SpecNo,'-','',[rfReplaceAll,rfIgnoreCase]);//Geb200
    SpecNo:=stringreplace(SpecNo,'��ˮ�ţ�','',[rfReplaceAll,rfIgnoreCase]);//��̫-BIOT-YG-II��������II��
    SpecNo:=stringreplace(SpecNo,':','',[rfReplaceAll,rfIgnoreCase]);//����-AFT-500
    SpecNo:='0000'+trim(SpecNo);
  end;
  FreeAndNil(PerlRegEx);
  //��������� end

  ifAM4290:=ManyStr(',',Pchar(Str))>20;//ʵ����AM4290�Ķ��Ų�ֹ�����
  isAve733:=pos('MachineSN',Str)>0;//����AVE-733A

  ls:=TStringList.Create;
  ls.Text:=Str;//ʹ��#$D��#$A�ָ�ɶ��е��뵽�ַ����б�
  //#$D#$A��Ϊһ����������и�
  //����#$D�����и�����
  //����#$A�����и�����
  //#$A#$D�ᱻ�и��һ������
  //#$A#$A�ᱻ�и��һ������
  //#$D#$D�ᱻ�и��һ������

  ReceiveItemInfo:=VarArrayCreate([0,ls.Count-1],varVariant);

  for i :=0 to ls.Count-1 do
  begin
    if AnalyBarcode then//����Mejer-700I����.��ɳ�ֵ�Ҫ������д�롾����/סԺ�š�
    begin
      if i=3 then
      begin
        ls5:=TStringList.Create;
        ExtractStrings([' '],[],Pchar(ls[i]),ls5);
        if ls5.Count>1 then Barcode:=ls5[1];
        ls5.Free;
      end;
    end;

    dlttype:='';

    //���������ʶ begin
    PerlRegEx:=TPerlRegEx.Create;
    PerlRegEx.RegEx:=RegExDlttype;
    //PerlRegEx.Options:=PerlRegEx.Options+[preUnGreedy];//������ʽ�п���̰��ģʽ,�Ա���õ������
    PerlRegEx.Subject:=ls[i];
    Try
      ifMatch:=PerlRegEx.Match;//������ʽΪ�ա��﷨����ȷ��Match�������׳��쳣
    except
      on E:Exception do
      begin
        memo1.Lines.Add('ƥ��������ʶ����:'+E.Message);
      end;
    end;
    if ifMatch then
    begin
      dlttype:=PerlRegEx.MatchedText;
      dlttype:=stringreplace(dlttype,'*','',[]);//CliniTek
    end;
    FreeAndNil(PerlRegEx);
    //���������ʶ end

    sValue:='';
    
    //��ü����� begin
    PerlRegEx:=TPerlRegEx.Create;
    PerlRegEx.RegEx:=RegExValue;
    //PerlRegEx.Options:=PerlRegEx.Options+[preUnGreedy];//������ʽ�п���̰��ģʽ.��Ϊ��ȡ��������ʱ��Ҫ̰��ģʽ
    PerlRegEx.Subject:=ls[i];
    Try
      ifMatch:=PerlRegEx.Match;//������ʽΪ�ա��﷨����ȷ��Match�������׳��쳣
    except
      on E:Exception do
      begin
        memo1.Lines.Add('ƥ�����������:'+E.Message);
      end;
    end;
    if ifMatch then
    begin
      sValue:=PerlRegEx.MatchedText;
      if ifAM4290 then sValue:=StringReplace(sValue,',','',[rfReplaceAll,rfIgnoreCase]); 
      if isAve733 and not SameText(dlttype,'PH') and not SameText(dlttype,'SG') and (sValue='1') then sValue:='��';
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
      sValue:=StringReplace(sValue,'=','',[rfReplaceAll,rfIgnoreCase]);//����-AFT-500
      sValue:=trim(sValue);
    end;
    FreeAndNil(PerlRegEx);
    //��ü����� end

    ReceiveItemInfo[i]:=VarArrayof([dlttype,sValue,'','']);
  end;
  ls.Free;
  
  if bRegister then
  begin
    //FInts :=CoData2Lis.CreateRemote('');//��ʱ��֧�ֱ���
    FInts :=CreateOleObject('Data2LisSvr.Data2Lis');
    FInts.fData2Lis(ReceiveItemInfo,(SpecNo),'',
      (GroupName),(SpecType),(SpecStatus),(EquipChar),
      (CombinID),'{!@#}{!@#}{!@#}{!@#}'+Barcode,(LisFormCaption),(ConnectString),
      (QuaContSpecNoG),(QuaContSpecNo),(QuaContSpecNoD),'',
      false,true,'����',
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
        MessageBox(application.Handle,pchar('�ó������������У�'),
                    'ϵͳ��ʾ',MB_OK+MB_ICONinformation);   
        Halt;
    end;

finalization
    if hnd <> 0 then CloseHandle(hnd);

end.
