; Layout file for the THMGRAD Backlash app. It defines the window, controls, saved bindings, and button actions.
;
title=Edit Gradient Flags
ui=LAYOUT
single_instance=1
resizable=0

[WINDOW]
X=260
Y=160
W=240
H=130
[LABEL]
TEXT=Toolbar
X=24
Y=22
[TEXTBOX]
NAME=VALUE1
X=104
Y=18
W=48
H=22
MAXLEN=1
TEXT=1
[LABEL]
TEXT=Title
X=24
Y=50
[TEXTBOX]
NAME=VALUE2
X=104
Y=46
W=48
H=22
MAXLEN=1
TEXT=1
[BUTTON]
TEXT=Close
X=84
Y=86
W=72
H=24
ACTION=SYS_ACTION APPS\THEME\THEME.SYS CLOSE_EDIT
