; Minimal OLE drag source used by MaterialBar.ahk.
; It exposes either CF_HDROP (files/folders) or Unicode/ANSI text so that
; browsers, upload dialogs and prompt editors receive a native Windows drag.

global MBDragDropVTable := 0
global MBDragDropCallbacks := []
global MBDragDataVTable := 0
global MBDragDataCallbacks := []
global MBDragDataObjects := Map()

MBDrag_Init() {
    global MBDragDropVTable, MBDragDropCallbacks
    global MBDragDataVTable, MBDragDataCallbacks

    if MBDragDropVTable
        return

    MBDragDropCallbacks := [
        CallbackCreate(MBDrag_DropQueryInterface, "Fast", 3),
        CallbackCreate(MBDrag_DropAddRef, "Fast", 1),
        CallbackCreate(MBDrag_DropRelease, "Fast", 1),
        CallbackCreate(MBDrag_DropQueryContinue, "Fast", 3),
        CallbackCreate(MBDrag_DropGiveFeedback, "Fast", 2)
    ]
    MBDragDropVTable := Buffer(5 * A_PtrSize, 0)
    for index, callbackPtr in MBDragDropCallbacks
        NumPut("ptr", callbackPtr, MBDragDropVTable,
            (index - 1) * A_PtrSize)

    MBDragDataCallbacks := [
        CallbackCreate(MBDrag_DataQueryInterface, "Fast", 3),
        CallbackCreate(MBDrag_DataAddRef, "Fast", 1),
        CallbackCreate(MBDrag_DataRelease, "Fast", 1),
        CallbackCreate(MBDrag_DataGetData, "Fast", 3),
        CallbackCreate(MBDrag_DataGetDataHere, "Fast", 3),
        CallbackCreate(MBDrag_DataQueryGetData, "Fast", 2),
        CallbackCreate(MBDrag_DataGetCanonicalFormatEtc, "Fast", 3),
        CallbackCreate(MBDrag_DataSetData, "Fast", 4),
        CallbackCreate(MBDrag_DataEnumFormatEtc, "Fast", 3),
        CallbackCreate(MBDrag_DataDAdvise, "Fast", 5),
        CallbackCreate(MBDrag_DataDUnadvise, "Fast", 2),
        CallbackCreate(MBDrag_DataEnumDAdvise, "Fast", 2)
    ]
    MBDragDataVTable := Buffer(12 * A_PtrSize, 0)
    for index, callbackPtr in MBDragDataCallbacks
        NumPut("ptr", callbackPtr, MBDragDataVTable,
            (index - 1) * A_PtrSize)
}

MBDrag_BeginFiles(paths) {
    if !IsObject(paths) || !paths.Length
        return 0
    return MBDrag_Begin({Kind: "Files", Paths: paths.Clone()}, 0x7)
}

MBDrag_BeginText(text) {
    if text = ""
        return 0
    return MBDrag_Begin({Kind: "Text", Text: text}, 0x1)
}

MBDrag_Begin(state, allowedEffects) {
    global MBDragDropVTable, MBDragDataVTable, MBDragDataObjects

    dataObject := Buffer(A_PtrSize + 8, 0)
    NumPut("ptr", MBDragDataVTable.Ptr, dataObject, 0)
    NumPut("uint", 1, dataObject, A_PtrSize)
    state.Memory := dataObject
    MBDragDataObjects[dataObject.Ptr] := state

    dropSource := Buffer(A_PtrSize + 8, 0)
    NumPut("ptr", MBDragDropVTable.Ptr, dropSource, 0)
    NumPut("uint", 1, dropSource, A_PtrSize)
    effect := 0
    try {
        return DllCall("ole32\DoDragDrop", "ptr", dataObject.Ptr,
            "ptr", dropSource.Ptr, "uint", allowedEffects,
            "uint*", &effect, "int")
    } finally {
        MBDrag_DataRelease(dataObject.Ptr)
    }
}

MBDrag_DataQueryInterface(this, iid, objectOut) {
    static iidUnknown := MBDrag_GuidBuffer(
        "{00000000-0000-0000-C000-000000000046}")
    static iidDataObject := MBDrag_GuidBuffer(
        "{0000010E-0000-0000-C000-000000000046}")
    if !MBDrag_GuidEqual(iid, iidUnknown.Ptr)
        && !MBDrag_GuidEqual(iid, iidDataObject.Ptr) {
        NumPut("ptr", 0, objectOut)
        return 0x80004002 ; E_NOINTERFACE
    }
    NumPut("ptr", this, objectOut)
    MBDrag_DataAddRef(this)
    return 0
}

MBDrag_DataAddRef(this) {
    count := NumGet(this + A_PtrSize, "uint") + 1
    NumPut("uint", count, this + A_PtrSize)
    return count
}

MBDrag_DataRelease(this) {
    global MBDragDataObjects
    count := NumGet(this + A_PtrSize, "uint")
    if count
        count -= 1
    NumPut("uint", count, this + A_PtrSize)
    if !count && MBDragDataObjects.Has(this)
        MBDragDataObjects.Delete(this)
    return count
}

MBDrag_DataGetData(this, formatEtc, medium) {
    global MBDragDataObjects
    if !MBDragDataObjects.Has(this)
        return 0x80040064 ; DV_E_FORMATETC

    state := MBDragDataObjects[this]
    payload := 0
    if state.Kind = "Files" {
        if !MBDrag_IsHDropFormat(formatEtc)
            return 0x80040064
        payload := MBDrag_CreateHDrop(state.Paths)
    } else if MBDrag_IsUnicodeTextFormat(formatEtc) {
        payload := MBDrag_CreateUnicodeText(state.Text)
    } else if MBDrag_IsAnsiTextFormat(formatEtc) {
        payload := MBDrag_CreateAnsiText(state.Text)
    } else {
        return 0x80040064
    }

    if !payload
        return 0x8007000E ; E_OUTOFMEMORY
    NumPut("uint", 1, medium, 0) ; TYMED_HGLOBAL
    unionOffset := A_PtrSize = 8 ? 8 : 4
    releaseOffset := A_PtrSize = 8 ? 16 : 8
    NumPut("ptr", payload, medium, unionOffset)
    NumPut("ptr", 0, medium, releaseOffset)
    return 0
}

MBDrag_DataGetDataHere(this, formatEtc, medium) {
    return 0x80004001 ; E_NOTIMPL
}

MBDrag_DataQueryGetData(this, formatEtc) {
    global MBDragDataObjects
    if !MBDragDataObjects.Has(this)
        return 0x80040064
    state := MBDragDataObjects[this]
    supported := state.Kind = "Files"
        ? MBDrag_IsHDropFormat(formatEtc)
        : (MBDrag_IsUnicodeTextFormat(formatEtc)
            || MBDrag_IsAnsiTextFormat(formatEtc))
    return supported ? 0 : 0x80040064
}

MBDrag_DataGetCanonicalFormatEtc(this, formatIn, formatOut) {
    ptdOffset := A_PtrSize = 8 ? 8 : 4
    NumPut("ptr", 0, formatOut, ptdOffset)
    return 0x00040130 ; DATA_S_SAMEFORMATETC
}

MBDrag_DataSetData(this, formatEtc, medium, release) {
    return 0x80004001
}

MBDrag_DataEnumFormatEtc(this, direction, enumOut) {
    global MBDragDataObjects
    if direction != 1 || !MBDragDataObjects.Has(this) {
        NumPut("ptr", 0, enumOut)
        return direction = 1 ? 0x80040064 : 0x80004001
    }

    state := MBDragDataObjects[this]
    formatSize := A_PtrSize = 8 ? 32 : 20
    formatCount := state.Kind = "Text" ? 2 : 1
    formats := Buffer(formatSize * formatCount, 0)
    if state.Kind = "Text" {
        MBDrag_FillTextFormat(formats.Ptr, 13)
        MBDrag_FillTextFormat(formats.Ptr + formatSize, 1)
    } else {
        MBDrag_FillHDropFormat(formats.Ptr)
    }
    enumerator := 0
    hr := DllCall("shell32\SHCreateStdEnumFmtEtc", "uint", formatCount,
        "ptr", formats.Ptr, "ptr*", &enumerator, "int")
    NumPut("ptr", enumerator, enumOut)
    return hr
}

MBDrag_DataDAdvise(this, formatEtc, flags, adviseSink, connectionOut) {
    if connectionOut
        NumPut("uint", 0, connectionOut)
    return 0x80040003 ; OLE_E_ADVISENOTSUPPORTED
}

MBDrag_DataDUnadvise(this, connection) {
    return 0x80040003
}

MBDrag_DataEnumDAdvise(this, enumOut) {
    NumPut("ptr", 0, enumOut)
    return 0x80040003
}

MBDrag_IsHDropFormat(formatEtc) {
    if !formatEtc
        return false
    aspectOffset := A_PtrSize = 8 ? 16 : 8
    indexOffset := A_PtrSize = 8 ? 20 : 12
    tymedOffset := A_PtrSize = 8 ? 24 : 16
    return NumGet(formatEtc, "ushort") = 15
        && NumGet(formatEtc + aspectOffset, "uint") = 1
        && NumGet(formatEtc + indexOffset, "int") = -1
        && (NumGet(formatEtc + tymedOffset, "uint") & 1)
}

MBDrag_IsUnicodeTextFormat(formatEtc) {
    return MBDrag_IsTextFormat(formatEtc, 13)
}

MBDrag_IsAnsiTextFormat(formatEtc) {
    return MBDrag_IsTextFormat(formatEtc, 1)
}

MBDrag_IsTextFormat(formatEtc, formatId) {
    if !formatEtc
        return false
    aspectOffset := A_PtrSize = 8 ? 16 : 8
    indexOffset := A_PtrSize = 8 ? 20 : 12
    tymedOffset := A_PtrSize = 8 ? 24 : 16
    return NumGet(formatEtc, "ushort") = formatId
        && NumGet(formatEtc + aspectOffset, "uint") = 1
        && NumGet(formatEtc + indexOffset, "int") = -1
        && (NumGet(formatEtc + tymedOffset, "uint") & 1)
}

MBDrag_FillHDropFormat(formatEtc) {
    MBDrag_FillFormat(formatEtc, 15)
}

MBDrag_FillTextFormat(formatEtc, formatId) {
    MBDrag_FillFormat(formatEtc, formatId)
}

MBDrag_FillFormat(formatEtc, formatId) {
    aspectOffset := A_PtrSize = 8 ? 16 : 8
    indexOffset := A_PtrSize = 8 ? 20 : 12
    tymedOffset := A_PtrSize = 8 ? 24 : 16
    NumPut("ushort", formatId, formatEtc, 0)
    NumPut("uint", 1, formatEtc, aspectOffset)
    NumPut("int", -1, formatEtc, indexOffset)
    NumPut("uint", 1, formatEtc, tymedOffset)
}

MBDrag_CreateHDrop(paths) {
    characterCount := 1
    for path in paths
        characterCount += StrLen(path) + 1
    byteCount := 20 + characterCount * 2
    handle := DllCall("kernel32\GlobalAlloc", "uint", 0x42,
        "uptr", byteCount, "ptr")
    if !handle
        return 0
    memory := DllCall("kernel32\GlobalLock", "ptr", handle, "ptr")
    if !memory {
        DllCall("kernel32\GlobalFree", "ptr", handle)
        return 0
    }
    NumPut("uint", 20, memory, 0)
    NumPut("int", 1, memory, 16)
    cursor := memory + 20
    for path in paths {
        DllCall("kernel32\lstrcpyW", "ptr", cursor, "wstr", path)
        cursor += (StrLen(path) + 1) * 2
    }
    DllCall("kernel32\GlobalUnlock", "ptr", handle)
    return handle
}

MBDrag_CreateUnicodeText(text) {
    bytes := (StrLen(text) + 1) * 2
    handle := DllCall("kernel32\GlobalAlloc", "uint", 0x42,
        "uptr", bytes, "ptr")
    if !handle
        return 0
    memory := DllCall("kernel32\GlobalLock", "ptr", handle, "ptr")
    if !memory {
        DllCall("kernel32\GlobalFree", "ptr", handle)
        return 0
    }
    StrPut(text, memory, StrLen(text) + 1, "UTF-16")
    DllCall("kernel32\GlobalUnlock", "ptr", handle)
    return handle
}

MBDrag_CreateAnsiText(text) {
    bytes := StrPut(text, "CP0")
    handle := DllCall("kernel32\GlobalAlloc", "uint", 0x42,
        "uptr", bytes, "ptr")
    if !handle
        return 0
    memory := DllCall("kernel32\GlobalLock", "ptr", handle, "ptr")
    if !memory {
        DllCall("kernel32\GlobalFree", "ptr", handle)
        return 0
    }
    StrPut(text, memory, bytes, "CP0")
    DllCall("kernel32\GlobalUnlock", "ptr", handle)
    return handle
}

MBDrag_DropQueryInterface(this, iid, objectOut) {
    static iidUnknown := MBDrag_GuidBuffer(
        "{00000000-0000-0000-C000-000000000046}")
    static iidDropSource := MBDrag_GuidBuffer(
        "{00000121-0000-0000-C000-000000000046}")
    if !MBDrag_GuidEqual(iid, iidUnknown.Ptr)
        && !MBDrag_GuidEqual(iid, iidDropSource.Ptr) {
        NumPut("ptr", 0, objectOut)
        return 0x80004002
    }
    NumPut("ptr", this, objectOut)
    MBDrag_DropAddRef(this)
    return 0
}

MBDrag_DropAddRef(this) {
    count := NumGet(this + A_PtrSize, "uint") + 1
    NumPut("uint", count, this + A_PtrSize)
    return count
}

MBDrag_DropRelease(this) {
    count := Max(0, NumGet(this + A_PtrSize, "uint") - 1)
    NumPut("uint", count, this + A_PtrSize)
    return count
}

MBDrag_DropQueryContinue(this, escapePressed, keyState) {
    if escapePressed
        return 0x00040101 ; DRAGDROP_S_CANCEL
    if !(keyState & 0x0001)
        return 0x00040100 ; DRAGDROP_S_DROP
    return 0
}

MBDrag_DropGiveFeedback(this, effect) {
    return 0x00040102 ; DRAGDROP_S_USEDEFAULTCURSORS
}

MBDrag_GuidBuffer(text) {
    guid := Buffer(16, 0)
    if DllCall("ole32\CLSIDFromString", "wstr", text,
        "ptr", guid.Ptr) != 0
        throw Error("GUID 解析失败：" text)
    return guid
}

MBDrag_GuidEqual(left, right) {
    Loop 4 {
        offset := (A_Index - 1) * 4
        if NumGet(left + offset, "uint") != NumGet(right + offset, "uint")
            return false
    }
    return true
}
