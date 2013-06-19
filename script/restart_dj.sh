#!/bin/bash

ls_out=`lsof -t ./log/delayed_job.log`

for i in ${ls_out}
	do
		echo "Killing $i"
		kill -9 $i
	done

