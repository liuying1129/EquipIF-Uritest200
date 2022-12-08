# LYTray改为CoolTrayIcon，托盘效果如下
1、小蝴蝶启动：状态栏不显示，仅在托盘显示 

2、双击托盘图标：弹出小蝴蝶界面 

3、最小化：最小化到状态栏 

4、关闭：状态栏不显示，仅在托盘显示 

5、右键退出菜单：确认退出的对话框 

# 升级方法：
删除组件LYTray，增加组件Cooltrayicon并改名为LYTray1 

设置LYTray1的icon属性 

设置LYTray1的iconvisible属性为true 

设置LYTray1的popupmenu 

设置PopupMenu1.N1（配置菜单）的default属性为true，该菜单项单击事件代码改为： 

  LYTray1.ShowMainForm; 
  
删除action组件 

删除【退出】按钮组件 

删除application组件的事件 

删除application组件 

工程文件代码run前增加代码：Application.ShowMainForm:=false; 

删除方法WMSyscommand 

删除方法LoadInputPassDll 

事件ToolButton2Click中删除LoadInputPassDll的判断 

删除FormCreate事件中的初始化密码的代码 

FormClose事件代码改为： 

  action:=caNone; 
  
  LYTray1.HideMainForm; 
  
N3Click事件代码改为： 

  if (MessageDlg('退出后将不再接收设备数据,确定退出吗？', mtWarning, [mbYes, mbNo], 0) <> mrYes) then exit; 
  
  application.Terminate; 
  
删除单元引用LYTray、ActnList、AppEvnts、registry
