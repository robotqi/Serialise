#!/bin/csh
#
#NAME
#	serialize_pcb.csh
#	
#DESCRIPTION
#	Adds a serial number for each PCB "edit Step" in the panel.
#	Supports Arrays in panel (i.e. adds the number to PCBs within Arrays).
#	Allows the user to define the starting serial number in each panel.
#	
#
#CALLING SCRIPT[S]
#	N/A
#
#CALLED SCRIPT[S]
#	$GENESIS_DIR/.ceirc			[main resources file]
#	
#
#RELATED FILES
#	N/A
#
#AUTHOR
#	Salah Elezaby, Automation Consultant
#
#HISTORY
#	02/14/08	: Version 1.00	: SE
#			
#	02/18/08	: Version 1.01	: SE
#			CHANGES:
#			Check for existing old serial numbers, and deleted before adding the new ones.
#
#####################################################################################

if ($1 != "") then
	COM undo
endif

set ver_num = "[Version 1.01]"

if (! $?SCR_DIR) then
	set SCR_DIR = $GENESIS_DIR/sys/scripts
endif

source $SCR_DIR/.ceirc

set pcb_name = $PCB_WRK
set pnl_name = $PNL_WRK

if (-e $TMP_DIR/${pcb_name}_loc.$JOB) rm $TMP_DIR/${pcb_name}_loc.$JOB

#
# If we have array, break it down.
#

COM open_entity,job=$JOB,type=step,name=$pnl_name,iconic=yes
set pnl_group = $COMANS
AUX set_group,group=$pnl_group
DO_INFO -t step -e $JOB/$pnl_name -d REPEAT

if ($gREPEATstep[1] == array) then
	COM do_on_abort,script=$PROG,user_data="123"
	COM sredit_reduce_nesting
	set redo_nesting
endif

#
# Get S+R Information
#

DO_INFO -t step -e $JOB/$pnl_name -d REPEAT
@ i = 1
while ($i <= $#gREPEATstep)
	if ($gREPEATstep[$i] == ${pcb_name}) then
		echo "$i $gREPEATxa[$i] $gREPEATya[$i] $gREPEATangle[$i]" >> $TMP_DIR/${pcb_name}_loc.$JOB
	endif
	@ i++
end

#aaa
echo "${pcb_name}_loc.$JOB File:"
cat $TMP_DIR/${pcb_name}_loc.$JOB

# dscheuer 06/22/09:
# This line did not port to the linux environment. It has been changed to the
# line below.
#sort +2nr +1n -o $TMP_DIR/${pcb_name}_loc.$JOB $TMP_DIR/${pcb_name}_loc.$JOB
sort -k 3rn -k 2n -o $TMP_DIR/${pcb_name}_loc.$JOB $TMP_DIR/${pcb_name}_loc.$JOB


set PID = `date +%H%M%S`
COM open_entity,job=$JOB,type=step,name=$pcb_name,iconic=no
set pcb_group = $COMANS
AUX set_group,group=$pcb_group
COM clear_layers
COM affected_layer,mode=all,affected=no

AGAIN:
COM get_work_layer
set w_lay = $COMANS
if ("$w_lay" == "") then
	PAUSE PLEASE DISPLAY A WORKING LAYER AND ZOOM TO REQUIRED LOCATION THEN CONTINUE
	goto AGAIN
endif

COM display_layer,name=$w_lay,display=yes,number=1
COM work_layer,name=$w_lay

set start_num = 1
set x_size = 55
set y_size = 65
set t_size = 10

echo "WIN 100 100\
Font hbr18\
BG 444444\
LABEL SERIAL NUMBER PARAMETERS $ver_num\
BG 888888\
FONT hbr14\
TEXT start_num 5 Starting Serial Number: \
DTEXT start_num $start_num\
TEXT x_size 5 Text X Size [Mils.]: \
DTEXT x_size $x_size\
TEXT y_size 5 Text Y Size [Mils.]: \
DTEXT y_size $y_size\
TEXT t_size 5 Text Width [Mils.]: \
DTEXT t_size $t_size\
RADIO t_rot 'Text Rotation: ' H 1 990000\
0\
90\
180\
270\
END\
RADIO t_pol 'Text Polarity: ' H 1 990000\
Positive\
Negative\
END" > /tmp/ser_num$PID

$GENESIS_EDIR/all/gui /tmp/ser_num$PID > /tmp/ser_num.gui$PID
source /tmp/ser_num.gui$PID
rm /tmp/ser_num$PID /tmp/ser_num.gui$PID

# dscheuer 05/11/09:
# Change awk95 to awk.
set x_size = `echo $x_size | awk '{printf("%0.3f"), $1/1000}'`
set y_size = `echo $y_size | awk '{printf("%0.3f"), $1/1000}'`

switch ($t_rot)
	case 1:
		set t_rot = 0
		breaksw
	case 2:
		set t_rot = 90
		breaksw
	case 3:
		set t_rot = 180
		breaksw
	case 4:
		set t_rot = 270
		breaksw
endsw

switch ($t_pol)
	case 1:
		set t_pol = positive
		breaksw
	case 2:
		set t_pol = negative
		breaksw
endsw

MOUSE p Select Serialization Location
set ser_loc = ($MOUSEANS)
set ser_locx = $ser_loc[1]
set ser_locy = $ser_loc[2]

COM editor_page_close

COM open_entity,job=$JOB,type=step,name=$pnl_name,iconic=no
set pnl_group = $COMANS
AUX set_group,group=$pnl_group
COM display_layer,name=$w_lay,display=yes,number=1
COM work_layer,name=$w_lay

#
# Check for existing serial numbers
#

COM filter_set,filter_name=popup,update_popup=no,feat_types=text
COM filter_atr_set,filter_name=popup,condition=yes,attribute=.string,text=sernum
COM filter_area_strt
COM filter_area_end,layer=,filter_name=popup,operation=select,\
area_type=none,inside_area=no,intersect_area=no,lines_only=no,\
ovals_only=no,min_len=0,max_len=0,min_angle=0,max_angle=0
COM get_select_count
set sernum_cnt = $COMANS
if ($sernum_cnt > 0) then
	PAUSE OLD SERIAL NUMBERS EXIST. CONTINUE TO DELET IT.
	COM sel_delete
endif
COM filter_reset,filter_name=popup

#
# Undo break array
#

if ($?redo_nesting) then
	COM undo
	unset redo_nesting
endif

DO_INFO -t layer -e $JOB/$pnl_name/$w_lay -d SIDE
if ($gSIDE == top) then
	set t_mir = no
else
	set t_mir = yes
endif

set pcb_ordr = (`cut -d" " -f1 $TMP_DIR/${pcb_name}_loc.$JOB`)
set pcb_orgx = (`cut -d" " -f2 $TMP_DIR/${pcb_name}_loc.$JOB`)
set pcb_orgy = (`cut -d" " -f3 $TMP_DIR/${pcb_name}_loc.$JOB`)
set pcb_angl = (`cut -d" " -f4 $TMP_DIR/${pcb_name}_loc.$JOB`)

rm $TMP_DIR/${pcb_name}_loc.$JOB

COM cur_atr_set,attribute=.string,text=sernum
@ i = 1
while ($i <= $#pcb_ordr)
	switch ($pcb_angl[$i])
		case 0:
			set locx = `echo "scale=6;$pcb_orgx[$i] + $ser_locx" | bc`
			set locy = `echo "scale=6;$pcb_orgy[$i] + $ser_locy" | bc`
			breaksw
		case 90:
			set locx = `echo "scale=6;$pcb_orgx[$i] + $ser_locy" | bc`
			set locy = `echo "scale=6;$pcb_orgy[$i] - $ser_locx" | bc`
			breaksw
		case 180:
			set locx = `echo "scale=6;$pcb_orgx[$i] - $ser_locx" | bc`
			set locy = `echo "scale=6;$pcb_orgy[$i] - $ser_locy" | bc`
			breaksw
		case 270:
			set locx = `echo "scale=6;$pcb_orgx[$i] - $ser_locy" | bc`
			set locy = `echo "scale=6;$pcb_orgy[$i] + $ser_locx" | bc`
			breaksw
	endsw
	set ser_num = `printf "%02d-" $start_num`
	set w_fact = `echo "$t_size * 0.083333" | bc`
	set angle = `expr \( $t_rot + $pcb_angl[$i] \) % 360`
	if ($t_mir == yes && ($pcb_angl[$i] == 90 || $pcb_angl[$i] == 270)) then
		set angle = `expr \( $angle + 180 \) % 360`
	endif
	COM add_text,attributes=yes,type=string,x=$locx,y=$locy,text=$ser_num,x_size=$x_size,y_size=$y_size,\
	w_factor=$w_fact,polarity=$t_pol,angle=$angle,mirror=$t_mir,fontname=standard
	@ i++
	@ start_num++
end
COM cur_atr_reset


exit (0)
