
# ------------------------------------------------------------------ #
#                              Notice                                #
#                                                                    #
# This file, and the information contained herein are hereby         #
# released under the terms of the GNU General Public License (GPL)   #
# Version 2.  A copy of the license terms may be found at this URL:  #
#      http://www.gnu.org/licences/gpl.txt                           #
#                                                                    #
#                                                                    #
# ------------------------------------------------------------------ #

# ------------------- Begin Header -------------------------

# Add Serialization to PCB's
#
#	Does not currently handle mirrored steps.
#
#  
# 
#   Mike J. Hopkins
#       Solidigm Systems, Inc.
#

set TITLE    = "PCB Serialization"
set AUTHOR   = "Mike J. Hopkins"
set DATE     = "10/12/2002"
set REVISION = "1.0.1"

# ------------------- End Header ---------------------------
source $_genesis_root/sys/scripts/include_me
# Text specific options
setenv TEXT_POSTFIX	-
setenv TEXT_X_SIZE	0.055
setenv TEXT_Y_SIZE	0.065
setenv TEXT_WIDTH	8

if (`uname` == "WINDOWS_NT") then
	setenv AWK gawk
	setenv SORT /usr/local/bin/sort
else if (`uname` == "HP-UX") then
	setenv AWK awk
	setenv SORT sort
else
	echo "Unknown OS..."
	setenv AWK nawk
endif
# --------------------------------------

   o_tooling
   o FONT $NORM_FONT
   o BG $NORM_COL
   o BW 0
   o LABEL Text Size
   o TEXT TEXT_X_SIZE 10 Text x Size  :
   o DTEXT TEXT_X_SIZE  $TEXT_X_SIZE
   o TEXT TEXT_Y_SIZE 10 Text y Size :
   o DTEXT TEXT_Y_SIZE $TEXT_Y_SIZE
   o TEXT TEXT_WIDTH 10 Text Width :
   o DTEXT TEXT_WIDTH $TEXT_WIDTH
   o END
   do_gui

# --- Get coordinate of text location ---
MOUSE p Select location for serialization in one PCB
set coords = ($MOUSEANS)
set x = $coords[1]
set y = $coords[2]


# --- Get the panel step info ---
DO_INFO -t step -e ${JOB}/${STEP}
COM get_work_layer
set curr_layer = $COMANS
DO_INFO -t layer -e ${JOB}/${STEP}/$curr_layer -d SIDE



# --- Calculate offset of text in clicked PCB ---
@ i = 1
@ j = 0
foreach step ($gREPEATstep)
	set xmin = $gREPEATxmin[$i]
	set ymin = $gREPEATymin[$i]
	set xmax = $gREPEATxmax[$i]
	set ymax = $gREPEATymax[$i]
	if (`echo $x $xmin | $AWK '$1 > $2 {print "1"}'`) then
		if (`echo $y $ymin | $AWK '$1 > $2 {print "1"}'`) then
			if (`echo $x $xmax | $AWK '$1 < $2 {print "1"}'`) then
				if (`echo $y $ymax | $AWK '$1 < $2 {print "1"}'`) then
					@ j = $i
					break
				endif
			endif
		endif
	endif
	@ i ++
end
set refStep = $step
set refRot  = $gREPEATangle[$i]
set refMir  = $gREPEATmirror[$i]
set xoff = `echo "$x - $xmin" | bc -l`
set yoff = `echo "$y - $ymin" | bc -l`
set xsize = `echo "$xmax - $xmin" | bc -l`
set ysize = `echo "$ymax - $ymin" | bc -l`


if (-f $JOB_PATH/user/steplist) then
	rm $JOB_PATH/user/steplist
endif
# --- Loop through each stepped image and add text ---
@ i = 1
foreach st ($gREPEATstep)
	if ($st != $refStep) then
		@ i ++
		continue
	endif
	set xmin = $gREPEATxmin[$i]
	set ymin = $gREPEATymin[$i]
	echo "$i|$xmin|$ymin" >> $JOB_PATH/user/steplist
	@ i ++
end
perl  $_genesis_root/sys/scripts/stepOrder.pl  $JOB_PATH/user/steplist  $JOB_PATH/user/sortlist
PAUSE 1
source $JOB_PATH/user/sortlist
rm $JOB_PATH/user/sortlist
#+++++++++++++++++++++++++++++++++++++++++

@ i = 1
foreach step ($gREPEATstep)
	if ($step != $refStep) then
		@ i ++
		continue
	endif
	set angle = 0
	set rot = $gREPEATangle[$i]
	set mir = $gREPEATmirror[$i]
	set xmin = $gREPEATxmin[$i]
	set ymin = $gREPEATymin[$i]
	set xmax = $gREPEATxmax[$i]
	set ymax = $gREPEATymax[$i]
	
	# Deal with multiple rotations
	if ($rot != $refRot) then
		set angle = `echo "$rot - $refRot" | bc`
		if ($angle == 90 || $angle == -90) then
			set x = `echo "$xmin + $xoff" | bc -l`
			set y = `echo "$ymax - $yoff" | bc -l`
		else if ($angle == 180 || $angle == -180) then
			set x = `echo "$xmax - $xoff" | bc -l`
			set y = `echo "$ymax - $yoff" | bc -l`
		else if ($angle == 270 || $angle == -270) then
			set x = `echo "$xmax - $xoff" | bc -l`
			set y = `echo "$ymin + $yoff" | bc -l`
		else
			PAUSE There is a rotation problem...
			break
		endif
	else
		set x = `echo "$xmin + $xoff" | bc -l`
		set y = `echo "$ymin + $yoff" | bc -l`
	endif
	
	# Add the text
	@ k = 1
	foreach r ($step_table)
		if $r == $i break
		@ k ++
	end
	if ($gSIDE == "bottom") then 
		if ($mir == "no") then
		    set mir =  "yes"
		else
		    set mir =  "no"
		endif
	endif 
		 
	set text = `echo $k $TEXT_POSTFIX | $AWK '{printf ("%02d%s", $1, $2)}'`
#	set text = ${text}${TEXT_POSTFIX}
	COM add_text,attributes=no,type=string,x=${x},y=${y},text=${text},\
		x_size=${TEXT_X_SIZE},y_size=${TEXT_Y_SIZE},w_factor=${TEXT_WIDTH},\
		polarity=positive,angle=${angle},mirror=${mir},\
		fontname=standard

	@ i ++
end

exit 0
