; Layout file for the THMIDX Backlash app. It defines the window, controls, saved bindings, and button actions.
;
title=Edit Palette Index
ui=LAYOUT
single_instance=1
resizable=0

[WINDOW]
X=280
Y=170
W=190
H=112
[LABEL]
TEXT=Index
X=24
Y=24
[TEXTBOX]
NAME=VALUE
X=80
Y=20
W=48
H=22
MAXLEN=2
TEXT=0
[BUTTON]
TEXT=Close
X=58
Y=66
W=72
H=24
ACTION=SYS_ACTION APPS\THEME\THEME.SYS CLOSE_EDIT
