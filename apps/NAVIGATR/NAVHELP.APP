; Navigator Help for Backlash Navigator.
; Uses actual TAB controls and page labels.
; Built from NAVIGATR.APP and NAVIGATR.SYS behavior.
title=Navigator Help
ui=LAYOUT
single_instance=1
resizable=1
no_scrollbars=1
PAGE_1=Start
PAGE_2=Views
PAGE_3=Browsing
PAGE_4=Selection
PAGE_5=FileOps
PAGE_6=Mouse
PAGE_7=Keys
PAGE_8=Menus
PAGE_9=Dialogs
KEY_ACTION=APP_KEY_ACTION
KEY_ACTION_TOKEN_MODE=GENERIC
KEY_ESC_ACTION=CLOSE_WINDOW

[WINDOW]
X=0
Y=0
W=640
H=430

[TAB]
TEXT=Start
X=8
Y=12
W=54
H=24

[TAB]
TEXT=Views
X=66
Y=12
W=54
H=24

[TAB]
TEXT=Browsing
X=124
Y=12
W=76
H=24

[TAB]
TEXT=Selection
X=204
Y=12
W=82
H=24

[TAB]
TEXT=FileOps
X=290
Y=12
W=68
H=24

[TAB]
TEXT=Mouse
X=362
Y=12
W=54
H=24

[TAB]
TEXT=Keys
X=420
Y=12
W=48
H=24

[TAB]
TEXT=Menus
X=472
Y=12
W=54
H=24

[TAB]
TEXT=Dialogs
X=530
Y=12
W=68
H=24

[LABEL]
TEXT=NAVIGATOR HELP
X=18
Y=52
W=600
H=16
PAGE=Start

[LABEL]
TEXT=Navigator browses drives, directories, and files from inside Backlash.
X=18
Y=70
W=600
H=16
PAGE=Start

[LABEL]
TEXT=Use single-click to select. Use double-click to open or enter.
X=18
Y=88
W=600
H=16
PAGE=Start

[LABEL]
TEXT=Files open through Backlash file associations by extension.
X=18
Y=106
W=600
H=16
PAGE=Start

[LABEL]
TEXT=If no association exists, the status box reports NO ASSOCIATION.
X=18
Y=124
W=600
H=16
PAGE=Start

[LABEL]
TEXT=The status box also reports selections, errors, and operation results.
X=18
Y=142
W=600
H=16
PAGE=Start

[LABEL]
TEXT=The file stats line shows file count and total size for the current pane.
X=18
Y=160
W=600
H=16
PAGE=Start

[LABEL]
TEXT=Type a directory in a Path box and press Enter to jump there.
X=18
Y=178
W=600
H=16
PAGE=Start

[LABEL]
TEXT=Use the UP item with the arrow to go to the parent directory.
X=18
Y=196
W=600
H=16
PAGE=Start

[LABEL]
TEXT=Open New Window opens another Navigator window offset from the current one.
X=18
Y=214
W=600
H=16
PAGE=Start

[LABEL]
TEXT=Navigator saves view, paths, active pane, colors, sort, and mask state.
X=18
Y=232
W=600
H=16
PAGE=Start

[LABEL]
TEXT=Open help from the Help button, Help menu, or F1.
X=18
Y=250
W=600
H=16
PAGE=Start

[LABEL]
TEXT=VIEW MODES
X=18
Y=52
W=600
H=16
PAGE=Views

[LABEL]
TEXT=Split view has Directories on the left and Files on the right.
X=18
Y=70
W=600
H=16
PAGE=Views

[LABEL]
TEXT=In Split view, selecting a directory refreshes the file list.
X=18
Y=88
W=600
H=16
PAGE=Views

[LABEL]
TEXT=Double-click a file, or press Enter on a file, to open it.
X=18
Y=106
W=600
H=16
PAGE=Views

[LABEL]
TEXT=The Split divider between Directories and Files can be dragged sideways.
X=18
Y=124
W=600
H=16
PAGE=Views

[LABEL]
TEXT=Combined view shows directories and files together in one list.
X=18
Y=142
W=600
H=16
PAGE=Views

[LABEL]
TEXT=In Combined view, double-click or Enter on a directory enters it.
X=18
Y=160
W=600
H=16
PAGE=Views

[LABEL]
TEXT=In Combined view, double-click or Enter on a file opens it.
X=18
Y=178
W=600
H=16
PAGE=Views

[LABEL]
TEXT=Dual Pane view has independent left and right directory panes.
X=18
Y=196
W=600
H=16
PAGE=Views

[LABEL]
TEXT=In Dual Pane view, click a pane to make it the active pane.
X=18
Y=214
W=600
H=16
PAGE=Views

[LABEL]
TEXT=The active pane is the source for keyboard file actions.
X=18
Y=232
W=600
H=16
PAGE=Views

[LABEL]
TEXT=F5 and F6 use the opposite pane as the destination in Dual Pane view.
X=18
Y=250
W=600
H=16
PAGE=Views

[LABEL]
TEXT=View menu switches Split, Combined, and Dual Pane modes.
X=18
Y=268
W=600
H=16
PAGE=Views

[LABEL]
TEXT=View menu Toggle Colors turns extension colors on or off.
X=18
Y=286
W=600
H=16
PAGE=Views

[LABEL]
TEXT=View menu Refresh reloads all Navigator panes.
X=18
Y=304
W=600
H=16
PAGE=Views

[LABEL]
TEXT=BROWSING
X=18
Y=52
W=600
H=16
PAGE=Browsing

[LABEL]
TEXT=Path boxes show the current directory for each view or pane.
X=18
Y=70
W=600
H=16
PAGE=Browsing

[LABEL]
TEXT=Press Enter in a Path box to load the typed directory.
X=18
Y=88
W=600
H=16
PAGE=Browsing

[LABEL]
TEXT=Drive roots appear in the drive selector, not in directory lists.
X=18
Y=106
W=600
H=16
PAGE=Browsing

[LABEL]
TEXT=The UP entry moves to the parent directory.
X=18
Y=124
W=600
H=16
PAGE=Browsing

[LABEL]
TEXT=Opening a directory changes the active path and refreshes the displayed list.
X=18
Y=142
W=600
H=16
PAGE=Browsing

[LABEL]
TEXT=Opening a file runs the app associated with that file extension.
X=18
Y=160
W=600
H=16
PAGE=Browsing

[LABEL]
TEXT=Text files can be opened by the Text Editor when the association exists.
X=18
Y=178
W=600
H=16
PAGE=Browsing

[LABEL]
TEXT=No association means Navigator will not guess what app to use.
X=18
Y=196
W=600
H=16
PAGE=Browsing

[LABEL]
TEXT=Sort affects how files are listed in the active browser view.
X=18
Y=214
W=600
H=16
PAGE=Browsing

[LABEL]
TEXT=Mask filtering limits displayed files by file pattern.
X=18
Y=232
W=600
H=16
PAGE=Browsing

[LABEL]
TEXT=Examples for masks include *.BAS, *.APP;*.SYS, and *.*.
X=18
Y=250
W=600
H=16
PAGE=Browsing

[LABEL]
TEXT=Directory entries are not opened by single-click. Single-click selects only.
X=18
Y=268
W=600
H=16
PAGE=Browsing

[LABEL]
TEXT=SELECTION
X=18
Y=52
W=600
H=16
PAGE=Selection

[LABEL]
TEXT=Click an item to select it and make that list active.
X=18
Y=70
W=600
H=16
PAGE=Selection

[LABEL]
TEXT=Up and Down move the selection in the focused list.
X=18
Y=88
W=600
H=16
PAGE=Selection

[LABEL]
TEXT=Ctrl-click toggles an item in a multi-selection list.
X=18
Y=106
W=600
H=16
PAGE=Selection

[LABEL]
TEXT=Shift-click selects a range from the anchor item to the clicked item.
X=18
Y=124
W=600
H=16
PAGE=Selection

[LABEL]
TEXT=Ctrl+A selects all selectable items in the focused list.
X=18
Y=142
W=600
H=16
PAGE=Selection

[LABEL]
TEXT=Navigator is configured so Select All selects files only where required.
X=18
Y=160
W=600
H=16
PAGE=Selection

[LABEL]
TEXT=The status box reports multi-selection counts and total file size.
X=18
Y=178
W=600
H=16
PAGE=Selection

[LABEL]
TEXT=Cut, Copy, Delete, drag-drop, and Paste use the current selection.
X=18
Y=196
W=600
H=16
PAGE=Selection

[LABEL]
TEXT=Dragging an unselected item carries only that one item.
X=18
Y=214
W=600
H=16
PAGE=Selection

[LABEL]
TEXT=Dragging a selected item carries the whole current selection.
X=18
Y=232
W=600
H=16
PAGE=Selection

[LABEL]
TEXT=Directories can be selected in browser lists, but some actions are file-only.
X=18
Y=250
W=600
H=16
PAGE=Selection

[LABEL]
TEXT=Clicking another pane changes which pane later keyboard actions use.
X=18
Y=268
W=600
H=16
PAGE=Selection

[LABEL]
TEXT=FILE AND DIRECTORY OPERATIONS
X=18
Y=52
W=600
H=16
PAGE=FileOps

[LABEL]
TEXT=Open opens the selected file or enters the selected directory.
X=18
Y=70
W=600
H=16
PAGE=FileOps

[LABEL]
TEXT=Open New Window opens a selected directory in another Navigator window.
X=18
Y=88
W=600
H=16
PAGE=FileOps

[LABEL]
TEXT=New Directory creates a directory in the active directory.
X=18
Y=106
W=600
H=16
PAGE=FileOps

[LABEL]
TEXT=Cut marks selected files or directories to move on Paste.
X=18
Y=124
W=600
H=16
PAGE=FileOps

[LABEL]
TEXT=Copy marks selected files or directories to copy on Paste.
X=18
Y=142
W=600
H=16
PAGE=FileOps

[LABEL]
TEXT=Paste copies or moves the clipboard items into the destination directory.
X=18
Y=160
W=600
H=16
PAGE=FileOps

[LABEL]
TEXT=Duplicate is for files and asks for a new filename.
X=18
Y=178
W=600
H=16
PAGE=FileOps

[LABEL]
TEXT=Rename works on files and directories and asks for the new name.
X=18
Y=196
W=600
H=16
PAGE=FileOps

[LABEL]
TEXT=Delete opens the Waste Basket confirmation dialog.
X=18
Y=214
W=600
H=16
PAGE=FileOps

[LABEL]
TEXT=Files can be moved to trash or permanently deleted.
X=18
Y=232
W=600
H=16
PAGE=FileOps

[LABEL]
TEXT=Directories show Include files and subdirectories instead of permanent delete.
X=18
Y=250
W=600
H=16
PAGE=FileOps

[LABEL]
TEXT=Copy Directory copies a whole selected directory with options.
X=18
Y=268
W=600
H=16
PAGE=FileOps

[LABEL]
TEXT=Copy Directory options include files, subdirs, empty dirs, hidden/system.
X=18
Y=286
W=600
H=16
PAGE=FileOps

[LABEL]
TEXT=Copy Directory can overwrite existing files when that option is checked.
X=18
Y=304
W=600
H=16
PAGE=FileOps

[LABEL]
TEXT=Properties shows name, path, size, association info, and attributes.
X=18
Y=322
W=600
H=16
PAGE=FileOps

[LABEL]
TEXT=File attributes shown are R, A, S, and H.
X=18
Y=340
W=600
H=16
PAGE=FileOps

[LABEL]
TEXT=MOUSE AND DRAG-DROP
X=18
Y=52
W=600
H=16
PAGE=Mouse

[LABEL]
TEXT=Single-click selects items, controls, menus, and path boxes.
X=18
Y=70
W=600
H=16
PAGE=Mouse

[LABEL]
TEXT=Double-click opens files and enters directories.
X=18
Y=88
W=600
H=16
PAGE=Mouse

[LABEL]
TEXT=Right-click a file for Open, Edit, Cut, Copy, Duplicate, Rename, Delete.
X=18
Y=106
W=600
H=16
PAGE=Mouse

[LABEL]
TEXT=Right-click a file also offers Properties.
X=18
Y=124
W=600
H=16
PAGE=Mouse

[LABEL]
TEXT=Right-click a directory for Open New, Cut, Copy, Rename, Delete, Properties.
X=18
Y=142
W=600
H=16
PAGE=Mouse

[LABEL]
TEXT=Right-click empty paste target area for Paste when clipboard contents exist.
X=18
Y=160
W=600
H=16
PAGE=Mouse

[LABEL]
TEXT=Drag selected files or directories onto a directory target to copy or move them.
X=18
Y=178
W=600
H=16
PAGE=Mouse

[LABEL]
TEXT=A highlighted directory target shows where the drop will go.
X=18
Y=196
W=600
H=16
PAGE=Mouse

[LABEL]
TEXT=Releasing over a directory opens the Drag and Drop dialog.
X=18
Y=214
W=600
H=16
PAGE=Mouse

[LABEL]
TEXT=The Drag and Drop dialog has Copy, Move, and Cancel.
X=18
Y=232
W=600
H=16
PAGE=Mouse

[LABEL]
TEXT=Drag-drop never performs a file operation until Copy or Move is chosen.
X=18
Y=250
W=600
H=16
PAGE=Mouse

[LABEL]
TEXT=Dropping somewhere that is not a directory reports Drop items on a directory.
X=18
Y=268
W=600
H=16
PAGE=Mouse

[LABEL]
TEXT=The mouse wheel scrolls scrollable Navigator lists.
X=18
Y=286
W=600
H=16
PAGE=Mouse

[LABEL]
TEXT=KEYBOARD SHORTCUTS
X=18
Y=52
W=600
H=16
PAGE=Keys

[LABEL]
TEXT=F1 opens Navigator Help.
X=18
Y=70
W=600
H=16
PAGE=Keys

[LABEL]
TEXT=F2 opens Rename for the active selection.
X=18
Y=88
W=600
H=16
PAGE=Keys

[LABEL]
TEXT=F3 opens Properties for the active selection.
X=18
Y=106
W=600
H=16
PAGE=Keys

[LABEL]
TEXT=F5 copies the active selection to the opposite pane.
X=18
Y=124
W=600
H=16
PAGE=Keys

[LABEL]
TEXT=F6 moves the active selection to the opposite pane.
X=18
Y=142
W=600
H=16
PAGE=Keys

[LABEL]
TEXT=F7 opens New Directory for the active directory.
X=18
Y=160
W=600
H=16
PAGE=Keys

[LABEL]
TEXT=F8 opens Delete for the active selection. Delete does the same.
X=18
Y=178
W=600
H=16
PAGE=Keys

[LABEL]
TEXT=Enter opens the selected file or enters the selected directory.
X=18
Y=196
W=600
H=16
PAGE=Keys

[LABEL]
TEXT=Enter in a Path box loads the typed path.
X=18
Y=214
W=600
H=16
PAGE=Keys

[LABEL]
TEXT=Up and Down move through the focused list.
X=18
Y=232
W=600
H=16
PAGE=Keys

[LABEL]
TEXT=Ctrl+A selects all selectable files in the focused list.
X=18
Y=250
W=600
H=16
PAGE=Keys

[LABEL]
TEXT=Ctrl+C copies, Ctrl+X cuts, and Ctrl+V pastes.
X=18
Y=268
W=600
H=16
PAGE=Keys

[LABEL]
TEXT=Ctrl+D duplicates the active selection.
X=18
Y=286
W=600
H=16
PAGE=Keys

[LABEL]
TEXT=Ctrl+F opens Filter. Ctrl+N opens New Directory. Ctrl+R refreshes.
X=18
Y=304
W=600
H=16
PAGE=Keys

[LABEL]
TEXT=Keyboard shortcuts do not run while typing in an editable Path box.
X=18
Y=322
W=600
H=16
PAGE=Keys

[LABEL]
TEXT=MENUS
X=18
Y=52
W=600
H=16
PAGE=Menus

[LABEL]
TEXT=File, Open opens or enters the active selection.
X=18
Y=70
W=600
H=16
PAGE=Menus

[LABEL]
TEXT=File, Open New Window opens a selected directory in a new Navigator window.
X=18
Y=88
W=600
H=16
PAGE=Menus

[LABEL]
TEXT=File, New Directory creates a directory in the current directory.
X=18
Y=106
W=600
H=16
PAGE=Menus

[LABEL]
TEXT=File, Copy Directory opens the whole-directory copy dialog.
X=18
Y=124
W=600
H=16
PAGE=Menus

[LABEL]
TEXT=File, Properties opens properties for the active selection.
X=18
Y=142
W=600
H=16
PAGE=Menus

[LABEL]
TEXT=File, Close closes Navigator.
X=18
Y=160
W=600
H=16
PAGE=Menus

[LABEL]
TEXT=Edit has Cut, Copy, Paste, Duplicate, Rename, and Delete.
X=18
Y=178
W=600
H=16
PAGE=Menus

[LABEL]
TEXT=View switches Split, Combined, Dual Pane, Toggle Colors, and Refresh.
X=18
Y=196
W=600
H=16
PAGE=Menus

[LABEL]
TEXT=Sort can order by Name, Extension, Size, or Date.
X=18
Y=214
W=600
H=16
PAGE=Menus

[LABEL]
TEXT=Filter, Set Mask opens the mask dialog.
X=18
Y=232
W=600
H=16
PAGE=Menus

[LABEL]
TEXT=Filter, Clear Mask removes the active file mask.
X=18
Y=250
W=600
H=16
PAGE=Menus

[LABEL]
TEXT=Help, Navigator Help opens this help app.
X=18
Y=268
W=600
H=16
PAGE=Menus

[LABEL]
TEXT=The top Help button opens this help app directly.
X=18
Y=286
W=600
H=16
PAGE=Menus

[LABEL]
TEXT=DIALOGS AND SAVED SETTINGS
X=18
Y=52
W=600
H=16
PAGE=Dialogs

[LABEL]
TEXT=Properties shows file details, directory details, associations, and attributes.
X=18
Y=70
W=600
H=16
PAGE=Dialogs

[LABEL]
TEXT=Rename shows current path, old name, and new name.
X=18
Y=88
W=600
H=16
PAGE=Dialogs

[LABEL]
TEXT=New Directory uses the Rename dialog in Create mode.
X=18
Y=106
W=600
H=16
PAGE=Dialogs

[LABEL]
TEXT=Delete uses the Waste Basket dialog and confirms before deleting.
X=18
Y=124
W=600
H=16
PAGE=Dialogs

[LABEL]
TEXT=Duplicate asks for the duplicate filename in the same directory.
X=18
Y=142
W=600
H=16
PAGE=Dialogs

[LABEL]
TEXT=Copy Directory asks for a destination and copy options.
X=18
Y=160
W=600
H=16
PAGE=Dialogs

[LABEL]
TEXT=Browse in Copy Directory opens the system directory picker.
X=18
Y=178
W=600
H=16
PAGE=Dialogs

[LABEL]
TEXT=Drag and Drop shows source summary and target directory before Copy or Move.
X=18
Y=196
W=600
H=16
PAGE=Dialogs

[LABEL]
TEXT=Filter asks for a file mask and selects the mask text for quick replacement.
X=18
Y=214
W=600
H=16
PAGE=Dialogs

[LABEL]
TEXT=Conflict handling asks before overwriting existing files or directories.
X=18
Y=232
W=600
H=16
PAGE=Dialogs

[LABEL]
TEXT=Conflict choices include Overwrite, Skip, Overwrite All, Skip All, Cancel.
X=18
Y=250
W=600
H=16
PAGE=Dialogs

[LABEL]
TEXT=Progress windows show Copy, Move, and Delete progress when operations run.
X=18
Y=268
W=600
H=16
PAGE=Dialogs

[LABEL]
TEXT=COLORS.CFG controls extension colors when colors are enabled.
X=18
Y=286
W=600
H=16
PAGE=Dialogs

[LABEL]
TEXT=Navigator state is saved using generic session state, not shell hardcoding.
X=18
Y=304
W=600
H=16
PAGE=Dialogs

[LABEL]
TEXT=Click a tab to change sections. ESC or Close exits help.
X=16
Y=390
W=500
H=16
MOVE_Y=1

[BUTTON]
TEXT=Close
X=552
Y=386
W=72
H=24
GROW_W=0
MOVE_X=1
MOVE_Y=1
ACTION=CLOSE_WINDOW

