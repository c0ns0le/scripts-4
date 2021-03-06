;~ https://autohotkey.com/docs/KeyList.htm
;~ Copy/Paste
;~ F1::SingleKeyMultiCommandToggle()
F1::
;~ Send, {Home 2}+{Down}{Del}{Down 2}{F3}
;~ EditPipelineWithClipboard()
WriteTfsMaterial()
return

WriteTfsMaterial() {
	SendInput, http://zeusserver20:8080/tfs/ZeusFront{Tab}
	SendInput, ZEUSTECNOLOGIA{Tab}
	SendInput, BuildUser{Tab}
	SendInput, Integra$tfs2016{Tab}
	SendInput, $/Comun/BuildTemplates
}


EditPipelineWithClipboard() {
	Send, {End}{Home 2}
	Send, ^{Right 7}
	Send, +{End}
	Send, ^+{Left 3}

	OldClip := ClipboardAll
	ClipWait, 1						; wait for it to be copied

	Clipboard =					; Must start off blank for detection to work.
	SolutionDir =
	Send, ^c						; Copy text into Clipboard
	ClipWait						; wait for it to be copied
	SolutionDir := Clipboard	   	; Fetch the text into variable

	Send, {Home 2}{Up}+{Down 3}{Del}

	Clipboard := OldClip
	OldClip = 
	ClipWait						; wait for it to be copied

	SendInput, {Down}
	SendInput, ^v
	SendInput, {Up 2}{End}^{Left 2}{Left 2}%SolutionDir%{Esc}
}

;~ Cut
NumpadIns::^x ; 0 / Insert key
;~ Copy
NumpadEnd::^c ; 1 / End key
;~ Paste
NumpadDown::^v ; 2 / Down arrow key

$*|::
if GetKeyState("Ctrl", "P") 
{
	SendInput, |
}
else if GetKeyState("Alt", "P")
{
	SendInput, !|
}
else if GetKeyState("Shift", "P")
{
	SendInput, +|
}
else
{
	SendInput, %clipboard%
}
return
;
;~ NumpadPgDn:: ; 3 / Page Down key
;~ NumpadLeft:: ; 4 / Left arrow key
;~ NumpadClear:: ; 5 / typically does nothing
;~ NumpadRight:: ; 6 / Right arrow key
;~ NumpadHome:: ; 7 / Home key
;~ NumpadUp:: ; 8 / Up arrow key
;~ NumpadPgUp:: ; 9 / Page Up key
;~ NumpadDel:: ; Decimal separation / Delete key
;~ NumpadDiv:: ; Divide
;~ NumpadMult:: ; Multiply
;~ NumpadAdd:: ; Add
;~ NumpadSub:: ; Subtract
;~ NumpadEnter:: ; Enter key


gCopyPasteToggle = 1

SingleKeyMultiCommandToggle() {
	global gCopyPasteToggle
	if gCopyPasteToggle = 1
	{
		gCopyPasteToggle = 2
		Send ^c
		ToolTip, Copy
	} 
	else
	{
		gCopyPasteToggle = 1
		Send ^v
		ToolTip, Paste
	}

	;~ ; To have a ToolTip disappear after a certain amount of time
	;~ ; without having to use Sleep (which stops the current thread):
	;~ #Persistent
	SetTimer, RemoveToolTip, 1000
	return
}


; label
RemoveToolTip:
	SetTimer, RemoveToolTip, Off
	ToolTip
	return
