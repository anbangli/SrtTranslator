; SrtTranslator v2025.10
; 使用网络翻译引擎自动翻译 Srt 字幕文件。
; 作者：anbangli@foxmail.com

;引入翻译引擎：下面四行代码分别代表四个翻译引擎（百度，搜狗，有道，DeepL），
;只能选择其中一个为有效语句（行首 不 写 分号），其它的设为注释（行首写英文分号）。
#Include <BaiduTranslator>		;百度
;#Include <SogouTranslator>   	;搜狗
;#Include <YoudaoTranslator>	;有道
;#Include <DeepLTranslator>   	;DeepL

; 全局代码（启动时执行）：构建程序用户界面
  Gui, Add, Text, x10 y10 w250 h20, 待翻译的 SRT 字幕文件：
  Gui, Add, Edit, x10 y30 w300 h20 vSourceFile
  Gui, Add, Button, x320 y30 w70 h25 gSelectFile vOpenBtn, 打开文件
  
  Gui, Add, Text, x10 y60 w250 h20, 翻译后的 SRT 字幕文件：
  Gui, Add, Edit, x10 y80 w300 h20 vTargetFile
  Gui, Add, Button, x320 y80 w70 h25 gTranslate vTransBtn +Disabled, 开始翻译
  Gui, Add, CheckBox, x10 y105 w150 h20 vBilingual +checked, 保存双语字幕

  Gui, Add, Edit, x10 y140 w40  h20 vSrtNumber +Disabled, 序号 
  Gui, Add, Edit, x60 y140 w250 h20 vTimeScope +Disabled, 时间轴
  
  Gui Add, Edit, x10 y170 w380 h50 vOriginal +Disabled, 原字幕文本
  Gui Add, Edit, x10 y230 w380 h50 vTranslation +Disabled, 翻译后的字幕文本
  Gui Add, Text, x10 y290 w250 h20 vHelpText, 请打开 SRT 字幕文件，然后开始翻译
  Gui Show, w400 h310, SrtTranslator
  GuiControl Focus, OpenBtn  ; 通过变量名设置焦点
  
  ;以上构建了程序用户界面，用户可以点击界面上的按钮以执行相应功能
return


; 选择文件并处理路径和扩展名
SelectFile:  ;选择一个指定扩展名的文件，并自动设定目标文件名
  FileSelectFile, SelectedFile, 3, , 请选择一个文件, SRT 字幕文件 (*.srt)
  if (SelectedFile = "")  ; 如果用户取消选择
    return
    
  ; 更新第一个文本框（完整路径）
  GuiControl,, SourceFile, %SelectedFile%
  ; 拆分路径各部分（驱动器、文件夹、主名、扩展名）
  SplitPath, SelectedFile, , dir, ext, name_no_ext, drive
  ; 组合处理后的完整路径
  if (ext = "")  ; 无扩展名时直接在主名后加 .chs
    modifiedPath := dir "\" name_no_ext ".chs"
  else  ; 有扩展名时在主名和扩展名间加 .chs
    modifiedPath := dir "\" name_no_ext ".chs." ext
  ; 第二个文本框显示处理后的完整路径
  GuiControl,, TargetFile, %modifiedPath%
    
  ; 检查扩展名是否为.srt，控制开始按钮状态
  if (ext = "srt") {  ; 不区分大小写可改为 if (InStr(ext, "srt", true))
    GuiControl, Enable, TransBtn  ; 启用"开始翻译"按钮
    GuiControl Focus, TransBtn  ; 通过变量名设置按钮焦点
  } else
    GuiControl, Disable, TransBtn  ; 禁用按钮
Return


Translate:  ;翻译
  GuiControlGet, InputFile,, SourceFile
  GuiControlGet, OutputFile,, TargetFile

  if !FileExist(InputFile) {
    MsgBox, 错误：未找到源文件！`n路径：%InputFile%
    return  ; 源文件不存在时终止程序
  }

  ;计算文件总行数
  FileRead, content, %InputFile%  ; 一次性读取全部内容
  ; 按换行符拆分（兼容 \n 和 \r\n）
  lines := StrSplit(content, ["`n", "`r`n"])
  ; 处理空文件或最后一行无换行符的情况
  linetotal := (content = "") ? 0 : lines.MaxIndex()
  content := ""  ;清空此变量

  GuiControl, , HelpText, 初始化网络翻译引擎...
  if (Translator.init("Chrome\chrome.exe")=Translator.multiLanguage.5) {
    GuiControl, , HelpText, 网络翻译引擎初始化失败。请重试一次，或阅读使用说明。
    return
  } else
    GuiControl, , HelpText, 网络翻译引擎初始化成功
    
  ;初始化成功, 继续执行
  GuiControl, Disable, OpenBtn   ;禁用按钮
  GuiControl, Disable, TransBtn  ;禁用按钮
  GuiControl, Enable, SrtNumber  ;启用文本框
  GuiControl, Enable, TimeScope  ;启用文本框
  GuiControl, Enable, Original   ;启用文本框
  GuiControl, Enable, Translation  ;启用文本框

  FileDelete, %OutputFile%  ; 先删除旧的输出文件（避免残留历史内容）
  linenum := 1
  while (linenum < lines.MaxIndex())    ; 循环处理文件的每一行
  {
      line := lines[linenum]  ; 存储当前行的内容
      num := 1
      if (RegExMatch(line, "^-?\d+$")) {  ;整数
        FileAppend, %line%`n, %OutputFile%
        GuiControl, , SrtNumber, %line%
      } else if trim(line) = "" { ;空行
        FileAppend, %line%`n, %OutputFile%
      } else if InStr(line, "-->") {
        GuiControl, , TimeScope, %line%
        FileAppend, %line%`n, %OutputFile%
      } else {
        ;一条字幕中的多行文字拼接成一行
        linenext := lines[linenum + num]
        while(trim(linenext) != "") {
          line := line " " linenext 
          num++
          linenext := lines[linenum + num]
        }
        
        GuiControl, , Original, %line%
        GuiControl, , HelpText, 正在翻译： %lineNum% / %linetotal%

        Gui, Submit, NoHide
        GuiControl, , Translation, 翻译中...

        ret := Translator.translate(Original)  ;翻译
  
        GuiControl, , Translation, %ret%
        FileAppend, %ret%`n, %OutputFile%
        if (Bilingual)
          FileAppend, %line%`n, %OutputFile%
        
        Sleep 100  ;暂停100ms
      }
      linenum := linenum + num
      if (Mod(linenum, 100) = 0)  ;多暂停100ms
        Sleep 100
  }
  GuiControl, Enable, OpenBtn   ;启用按钮
  GuiControl, Enable, TransBtn  ;启用按钮
  GuiControlGet, lineNum,, SrtNumber
  GuiControl, , HelpText, 翻译已结束。共处理 %lineNum% 条字幕。
Return


GuiEscape:
GuiClose:
  Translator.free()
  ExitApp
return
