#####
##
##	GPUtemp for lm-sensors by EndlessEden
##
###
###
##
##	Description: This script detects the type of dgpu in use, then reads the corresponding utility/sensor for its temperature. Outputting it to the absolute path "/tmp/gputemp1_input".
##	See https://github.com/endlesseden/gputemp-lmsensors for more info.
##
####

if [ ! "$(id -u)" -eq 0 ]; then
  echo "This script cannot be run as anyone but root right now."
  exit 1
fi

if [ "$1" == "stop" ]; then
        touch /tmp/gputemplm_shutdown && exit 0
fi

if [ -e /tmp/gputemp1_input ]; then
	echo "Check if already running and remove /tmp/gputemp1_input"
	exit 1
fi

echo "Checking GPU type..."
if [ $(lspci -k -d ::03xx | grep 'Kernel driver in use' | sed 's|: |\n|g' | tail -1 | grep -c "nvidia") == "1" ]; then
        GPUT="nvidia"
	echo "$(lspci -k -d ::03xx | grep VGA | sed -e "s|NVIDIA Corporation ..[0-9][0-9][0-9]|\n|g" | tail -1 ) Detected"
elif [ $(lspci -k -d ::03xx | grep 'Kernel driver in use' | sed 's|: |\n|g' | tail -1 | grep -c "AMD") -gt "0" ]; then
       	GPUT="amd"
	echo "$(lspci -k -d ::03xx | grep VGA | sed -e "s| VGA compatible controller:|\n|g" | tail -1) detected" ## ill clean this up later. 
else
	GPUT="other"
	if [ -e /tmp/gputemplm_shutdown ]; then
        	rm /tmp/gputemplm_shutdown
	fi
	echo "Only AMD and NVIDIA GPU's are supported for now, please contact the gputemp-fancontrol author if this is in error" && exit 1
fi


if [ "$GPUT" == "nvidia" ]; then

gputemplm_shutdown=0
while : ; do
  NVTEMP=0
  NVTEMP=$(echo "$(nvidia-smi -q -d TEMPERATURE | grep 'GPU Current Temp' | sed 's| |\n|g' | grep [0-9][0-9])"000)
  if [ ! "$NVTEMP" == 0 ]; then
  	echo $NVTEMP > /tmp/gputemp1_input
  else
	echo "nvidia-smi not reporting temp correctly!" 
	echo "99900" > /tmp/gputemp1_input # Spin fans up to max speed, to prevent damage.
  fi
  if [ -e /tmp/gputemplm_shutdown ]; then
  	export gputemplm_shutdown=1
	rm /tmp/gputemplm_shutdown
  fi
  if [ "$gputemplm_shutdown" -gt 0 ]; then
      break
  fi
  sleep 1.1
done

elif ["$GPUT" == "amd" ]; then

	if [ -e "/sys/class/drm/card0" ]; then
		gpu_card_id=0
	elif [ -e "/sys/class/drm/card1" ]; then
		gpu_card_id=1
	else
		gpu_card_id=999
	fi
	if [ "$gpu_card_id" == "999" ]; then
		echo "cannot detect AMDGPU" && exit 1 
	elif [ "$gpu_card_id" == "0" ]; then

		gputemplm_shutdown=0
		while : ; do
  			cat /sys/class/drm/card1/device/hwmon/hwmon*/temp1_input > /tmp/gputemp1_input
			if [ -e /tmp/gputemplm_shutdown ]; then
				export gputemplm_shutdown=1
				rm /tmp/gputemplm_shutdown 
			fi
  			if [ "$gputemplm_shutdown" -gt 0 ]; then
				break
			fi
			sleep 1.1
		done
	
	elif [ "$gpu_card_id" == "1" ]; then

                gputemplm_shutdown=0
                while : ; do
                        cat /sys/class/drm/card1/device/hwmon/hwmon*/temp1_input > /tmp/gputemp1_input
                        if [ -e /tmp/gputemplm_shutdown ]; then
                                export gputemplm_shutdown=1
                                rm /tmp/gputemplm_shutdown
                        fi
                        if [ "$gputemplm_shutdown" -gt 0 ]; then
                                break
                        fi
			sleep 1.1
                done

	else

		echo "something weird is happening, please contact the gputemp-fancontrol author" && exit 1	

	fi
else 

	echo "Only AMD and NVIDIA GPU's are supported for now, please contact the gputemp-fancontrol author if this is in error" && exit 1

fi
if [ -e /tmp/gputemplm_shutdown ]; then
	rm /tmp/gputemplm_shutdown
fi

if [ -e /tmp/gputemp1_input ]; then
	rm /tmp/gputemp1_input
fi
