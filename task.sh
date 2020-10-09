#!/bin/bash

# index of the displayed task
index=1
# should we echo the displayed task on next update
dirty=0
# countdown to the next forced update
dirty_countdown=0
# period of the forced update (in seconds)
reload_rate=10
# is the module in the period of confirmation for marking a task as done
# if so, clicking will cancel marking
marking=0

while getopts ":r:" opt; do
  case $opt in
    r) reload_rate="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    ;;
  esac
done

# echo the task with the specified id
echo_task () {
	most_urgent_desc=`task $1 rc.verbose: rc.report.next.columns:description rc.report.next.labels:1 limit:1 next`
	most_urgent_due=`task $1 rc.verbose: rc.report.next.columns:due.relative rc.report.next.labels:1 limit:1 next`
	echo "$1" > /tmp/tw_polybar_id
	if [ -z "$most_urgent_due" ]
	then
		echo " $most_urgent_desc"
	else
		echo " $most_urgent_desc ·  $most_urgent_due"
	fi
}

# force an update in the displayed task
update_index() {
	count=$(task status:pending count)
	if [ $count -gt 0 ]; then 
		index=$(((index-1) % count + 1))
	else
		index=-1
	fi
	dirty=1
}
# mark task as done
mark_done() {
	marking=1
	echo Marking as done...
	sleep 2 &
	wait
	if [ $marking -ne 1 ]; then return; fi
	task "$((`cat /tmp/tw_polybar_id`))" done > /dev/null
	update_index
	marking=0
}
cancel_marking() {
	marking=0
	echo Canceled!
	sleep 1 &
	wait 
	update_index
}
click1() {
	if [ $dirty -ne 0 ]; then return; fi
	if [ $marking -eq 0 ]; then
		# increment $index and display next task
		((index++))
		update_index
	else
		cancel_marking
	fi
}
click2() {
	if [ $dirty -ne 0 ]; then return; fi
	if [ $marking -eq 0 ]; then
		mark_done
	else
		cancel_marking
	fi
}

trap "click1" USR1
trap "click2" USR2

# echo our pid for debugging
echo $$
update_index
while true; do
	# do a forced update every $dirty_countdown_max
	if [ $dirty -eq 0 ] && [ $marking -eq 0 ]; then
		dirty_countdown=$(((dirty_countdown + 1) % $reload_rate))
		if [ $dirty_countdown -eq 0 ]
		then
			((index++))
			update_index
		fi
	fi
	# echo the displayed task when dirty
	if [ $dirty -ne 0 ]
	then
		if [ $index -eq "-1" ]; then
			echo no task
		else 
			echo_task $index
		fi
		dirty=0
		dirty_countdown=0
	fi
	sleep 1 &
	wait
done
