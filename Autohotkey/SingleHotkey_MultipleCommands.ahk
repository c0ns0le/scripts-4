;~ https://autohotkey.com/docs/KeyList.htm
;~ Copy/Paste
F1::SingleKeyMultiCommandToggle()

;~ Cut
NumpadIns::^x ; 0 / Insert key
;~ Copy
NumpadEnd::^c ; 1 / End key
;~ Paste
NumpadDown::^v ; 2 / Down arrow key
^|::Send |
|::^v
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
