.386
.model	flat,stdcall
option	casemap:none

;include
include		windows.inc
include		kernel32.inc
include		user32.inc
include		comctl32.inc
include		msvcrt.inc
includelib	kernel32.lib
includelib	user32.lib
includelib	comctl32.lib
includelib	msvcrt.lib

;resources definition
IDD_FILTER              equ 1000
IDC_CBO1                equ 1004
IDC_EDT1                equ 1005
IDC_BTN1                equ 1006
IDC_CBO2                equ 1008

.data
szCPU					db		'CPU',0
szTime					db		'Time',0
szThread				db		'Thread ID',0
szProcess				db		'Process ID',0
szModule				db		'Module',0
szSrc					db		'Src',0
szLine					db		'Line',0
szFunction				db		'Function',0
szLevel					db		'Level',0
szClass					db		'Class',0
szMessage				db		'Message',0

szActionDel				db		'Delete Items Which Match Patten',0
szActionPre				db		'Preserve Items Which Match Patten',0

;CDF indentity
szCDFClassName			db		'WINGUIObj',0
szCDFCaption			db		'CDFControl',0
szSys					db		'SysListView32',0

;UI Data
szContains				db		512	dup	(?)


;error message
szErrCap				db		'Error',0
szFmt					db		'%d',0
szFmtSysListViewHandle	db		'SysListView Handle is %d.',0
szFmtItemCount			db		'SysListView ItemCount = %d',0
szFmtGetItemText		db		'GetItemText: Item = %d , SubItem = %d , Text = %s',0
szFmtGetUIData			db		'GetUIData: Filter Index = %d , Contains = %s',0
szErrFindCDF			db		'Please start CDFControl first!',0
szErrOpenProcess		db		'Cannot open CDFControl Process to Alloc Memory!',0
szContainsNull			db		'Please input Contains String first!',0

;prompt message
szFiltered				db		'Filter Applyed',0
szSucc					db		'Successful!',0
szFiltering				db		'Please Wait...',0
szBtnStr				db		'Start Filter',0

szZero					db		512	dup	(0)

.data?
hInstance				dd			?
hCDFHandle				dd			?
szBuff					db		512	dup	(?)
hSysListView32			dd			?
szItemText				db		512	dup	(?)
pLvItem					dd			?
pItem					dd			?
pHandle					dd			?
ItemCount				dd			?
nItem					dd			?
nSubItem				dd			?
bDel					dd			?

.code

GetItemText	proc	Item:DWORD,SubItem:DWORD
	local	@lvItem:LVITEM
	mov		@lvItem.cchTextMax,512
	mov		eax,Item
	mov		@lvItem.iItem,eax
	mov		eax,SubItem
	mov		@lvItem.iSubItem,eax
	mov		@lvItem.imask,LVIF_TEXT
	mov		eax,pItem
	mov		@lvItem.pszText,eax
	
	;invoke	WriteProcessMemory,pHandle,pLvItem,addr szZero,512,NULL
	;invoke	WriteProcessMemory,pHandle,pItem,addr szZero,512,NULL
	invoke	WriteProcessMemory,pHandle,pLvItem,addr @lvItem,sizeof(LVITEM),NULL
	invoke	SendMessage,hSysListView32,LVM_GETITEM,0,pLvItem
	invoke	ReadProcessMemory,pHandle,pItem,addr szItemText,512,NULL
	
	;output Item Text
	invoke	wsprintf,addr szBuff,addr szFmtGetItemText,Item,SubItem,addr szItemText
	;invoke	wsprintf,addr szBuff,addr szFmtGetItemText,pLvItem,pItem,addr szItemText
	invoke	OutputDebugString,addr szBuff
	ret
GetItemText endp

GetItemCount	proc
	invoke	SendMessage,hSysListView32,LVM_GETITEMCOUNT,0,0
	mov		ItemCount,eax
	invoke	wsprintf,addr szBuff,addr szFmtItemCount,ItemCount
	invoke	OutputDebugString,addr szBuff
	ret
GetItemCount endp

AllocMemory	proc
	local	@pid:DWORD
	invoke	GetWindowThreadProcessId,hCDFHandle,addr @pid
	invoke	OpenProcess,PROCESS_ALL_ACCESS,NULL,@pid
	mov		pHandle,eax
	cmp		pHandle,0
	jnz		@F
	invoke	OutputDebugString,addr szErrOpenProcess
	ret
	@@:
	invoke	VirtualAllocEx,pHandle,NULL,512,MEM_COMMIT,PAGE_READWRITE
	mov		pLvItem,eax
	invoke	VirtualAllocEx,pHandle,NULL,512,MEM_COMMIT,PAGE_READWRITE
	mov		pItem,eax
	ret
AllocMemory endp

ReleaseMemory	proc
	invoke	VirtualFreeEx,pHandle,pLvItem,0,MEM_RELEASE
	invoke	VirtualFreeEx,pHandle,pItem,0,MEM_RELEASE
	invoke	CloseHandle,pHandle
	ret
ReleaseMemory endp

EnumChildProc	proc	hwnd:HWND,lParam:LPARAM
	invoke	GetClassName,hwnd,addr szBuff,255
	;check
	push	esi
	push	edi
	lea		esi,szBuff
	lea		edi,szSys
	mov		ecx,13
	repz	cmpsb
	jnz	@F
	.if		hSysListView32 == 1
			mov	eax,hwnd
			mov	hSysListView32, eax
			pop		edi
			pop		esi
			ret
	.elseif	hSysListView32 == 0
			mov	hSysListView32,1
	.endif
	@@:
	mov eax,1
	pop	edi
	pop	esi
	ret
EnumChildProc	endp

GetSysListviewHandle	proc
	;invoke	FindWindow,addr szCDFClassName,addr szCDFCaption
	;due CDFControl 2.6.0.5 modify the window title , so just using classname to search
	invoke	FindWindow,addr szCDFClassName,NULL
	mov		hCDFHandle,eax
	cmp		hCDFHandle,0
	jnz		@F
	invoke	OutputDebugString,addr szErrFindCDF
	ret
	@@:
	mov		hSysListView32,0
	invoke	EnumChildWindows,hCDFHandle,addr EnumChildProc,NULL
	ret
GetSysListviewHandle endp

Filtering	proc
	;delete items that match patten
	;get SysListView Control handle
	invoke	GetSysListviewHandle
	invoke	wsprintf,addr szBuff,addr szFmtSysListViewHandle,hSysListView32
	invoke	OutputDebugString,addr szBuff
	
	;Alloc Memory in CDF control process space
	invoke	AllocMemory
	;get Maxium Item Count
	invoke	GetItemCount
	
	;loop filter
	mov		ebx,ItemCount
	@@:
	dec		ebx
	cmp		ebx,0
	jl		@F
	invoke	GetItemText,ebx,nSubItem
	invoke	crt_strstr,addr szItemText,addr szContains
	cmp	eax,0
	jz		@B
	;delete item
	invoke	SendMessage,hSysListView32,LVM_DELETEITEM,ebx,0
	jmp		@B
	@@:
	
	;loop fitler over	
	;release Allocated Memory
	invoke	ReleaseMemory
	ret
Filtering endp
Filtering2	proc
	;Preserve Items that match patten
	;get SysListView Control handle
	invoke	GetSysListviewHandle
	invoke	wsprintf,addr szBuff,addr szFmtSysListViewHandle,hSysListView32
	invoke	OutputDebugString,addr szBuff
	
	;Alloc Memory in CDF control process space
	invoke	AllocMemory
	;get Maxium Item Count
	invoke	GetItemCount
	
	;loop filter
	mov		ebx,ItemCount
	@@:
	dec		ebx
	cmp		ebx,0
	jl		@F
	invoke	GetItemText,ebx,nSubItem
	invoke	crt_strstr,addr szItemText,addr szContains
	cmp	eax,0
	jnz		@B
	;delete item
	invoke	SendMessage,hSysListView32,LVM_DELETEITEM,ebx,0
	jmp		@B
	@@:
	
	;loop fitler over	
	;release Allocated Memory
	invoke	ReleaseMemory
	ret
Filtering2 endp

ThreadProc proc	hBtn:DWORD
	;disable button
	invoke	SetWindowText,hBtn,addr szFiltering
	invoke	EnableWindow,hBtn,FALSE
	.if		bDel == 1
		invoke	Filtering
	.else
		invoke	Filtering2
	.endif
	;reenable button
	invoke	SetWindowText,hBtn,addr szBtnStr
	invoke	EnableWindow,hBtn,TRUE
	ret
ThreadProc endp

DialogProc proc hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM

	mov		eax,uMsg
	.if eax==WM_INITDIALOG
		;init combobox
		invoke SendDlgItemMessage,hWin,IDC_CBO1,CB_ADDSTRING,0,addr szCPU
		invoke SendDlgItemMessage,hWin,IDC_CBO1,CB_ADDSTRING,0,addr szTime
		invoke SendDlgItemMessage,hWin,IDC_CBO1,CB_ADDSTRING,0,addr szThread
		invoke SendDlgItemMessage,hWin,IDC_CBO1,CB_ADDSTRING,0,addr szProcess
		invoke SendDlgItemMessage,hWin,IDC_CBO1,CB_ADDSTRING,0,addr szModule
		invoke SendDlgItemMessage,hWin,IDC_CBO1,CB_ADDSTRING,0,addr szSrc
		invoke SendDlgItemMessage,hWin,IDC_CBO1,CB_ADDSTRING,0,addr szLine
		invoke SendDlgItemMessage,hWin,IDC_CBO1,CB_ADDSTRING,0,addr szFunction
		invoke SendDlgItemMessage,hWin,IDC_CBO1,CB_ADDSTRING,0,addr szLevel
		invoke SendDlgItemMessage,hWin,IDC_CBO1,CB_ADDSTRING,0,addr szClass
		invoke SendDlgItemMessage,hWin,IDC_CBO1,CB_ADDSTRING,0,addr szMessage
		invoke	SendDlgItemMessage,hWin,IDC_CBO2,CB_ADDSTRING,0,addr szActionPre
		invoke	SendDlgItemMessage,hWin,IDC_CBO2,CB_ADDSTRING,0,addr szActionDel
		
		;check the last item
		invoke SendDlgItemMessage,hWin,IDC_CBO1,CB_SETCURSEL,10,0
		invoke	SendDlgItemMessage,hWin,IDC_CBO2,CB_SETCURSEL,1,0
	.elseif eax==WM_COMMAND
		mov		edx,wParam
		movzx	eax,dx
		shr		edx,16
		.if edx==BN_CLICKED
			.if eax==IDC_BTN1
				;Get UI data
				;get Filter Index
				invoke	GetDlgItem,hWin,IDC_CBO1
				invoke	SendMessage,eax,CB_GETCURSEL,0,0
				inc		eax
				mov		nSubItem,eax
				;get contains string
				invoke	GetDlgItemText,hWin,IDC_EDT1,addr szContains,512
				invoke	wsprintf,addr szBuff,addr szFmtGetUIData,nSubItem,addr szContains
				invoke	OutputDebugString,addr szBuff
				invoke	crt_strlen,addr szContains
				cmp		eax,0
				jnz		@F
				invoke	MessageBox,hWin,addr szContainsNull,addr szErrCap,MB_OK
				ret
				@@:
				;get action
				invoke GetDlgItem,hWin,IDC_CBO2
				invoke	SendMessage,eax,CB_GETCURSEL,0,0
				mov		bDel,eax
								
				;start filtering the item
				invoke	GetDlgItem,hWin,IDC_BTN1
				invoke CreateThread,NULL,0,addr ThreadProc,eax,0,NULL
				
				;show messagebox
				;invoke	MessageBox,hWin,addr szFiltered,addr szSucc,MB_OK
			.endif
		.endif
	.elseif eax==WM_CLOSE
		invoke EndDialog,hWin,NULL
	.else
		mov		eax,FALSE
		ret
	.endif
	mov		eax,TRUE
	ret

DialogProc	endp

_WinMain	proc
	invoke 	GetModuleHandle,NULL
	mov		hInstance,eax
	invoke	DialogBoxParam,hInstance,IDD_FILTER,NULL,addr DialogProc,NULL
	invoke 	ExitProcess,0
_WinMain	endp

end _WinMain