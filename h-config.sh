# Check Flightsheet param
if [[ $CUSTOM_USER_CONFIG == *'"accessToken"'* || $CUSTOM_USER_CONFIG == *'"payoutId"'* ]]; then

    echo "\"qubic\"" > /tmp/miner_option
    echo "MINER_DIR=$MINER_DIR" >> /tmp/miner_option
    echo "MINER_NAME=$MINER_NAME" >> /tmp/miner_option
    echo "MINER_LATEST_VER=$MINER_LATEST_VER" >> /tmp/miner_option    
    
	conf=`cat /hive/miners/custom/$CUSTOM_NAME/appsettings_global.json | envsubst`

	Settings=$(jq -r .Settings <<< "$conf")

	if [[ ! -z $CUSTOM_TEMPLATE ]]; then
	  if [[ ${#CUSTOM_TEMPLATE} -lt 60 ]]; then
		# %WORKER_NAME%
		  Settings=`jq --null-input --argjson Settings "$Settings" --arg alias "$CUSTOM_TEMPLATE" '$Settings + {$alias}'`
	  elif [[ ${#CUSTOM_TEMPLATE} -eq 60 ]]; then
		# %WAL% with Address Id
		  Settings=`jq --null-input --argjson Settings "$Settings" --arg payoutId "$CUSTOM_TEMPLATE" '$Settings + {$payoutId}'`
	  else
		# %WAL%.%WORKER_NAME%
		wallet=${CUSTOM_TEMPLATE%.*}
		len=${#wallet}
		alias=${CUSTOM_TEMPLATE:len}
		alias=${alias#*.}
		  Settings=`jq --null-input --argjson Settings "$Settings" --arg alias "$alias" '$Settings + {$alias}'`
		if [[ ${#wallet} -eq 60 ]]; then
			Settings=`jq --null-input --argjson Settings "$Settings" --arg payoutId "$wallet" '$Settings + {$payoutId}'`
		else
			Settings=`jq --null-input --argjson Settings "$Settings" --arg accessToken "$wallet" '$Settings + {$accessToken}'`
		fi
	  fi
	fi

	[[ ! -z $CUSTOM_URL ]] &&
		Settings=`jq --null-input --argjson Settings "$Settings" --arg baseUrl "$CUSTOM_URL" '$Settings + {$baseUrl}'`

	#merge user config options into main config
	if [[ ! -z $CUSTOM_USER_CONFIG ]]; then
		while read -r line; do
			[[ -z $line ]] && continue
		if [[ ${line:0:7} = "nvtool " ]]; then
		  eval $line
		else
			Settings=$(jq -s '.[0] * .[1]' <<< "$Settings {$line}")
		fi
		done <<< "$CUSTOM_USER_CONFIG"
	fi

	conf=`jq --null-input --argjson Settings "$Settings" '{$Settings}'`
	#echo $conf | jq . > $CUSTOM_CONFIG_FILENAME

	# CPU & GPU
	CPU_DIR="/hive/miners/custom/$CUSTOM_NAME/cpu"
	GPU_DIR="/hive/miners/custom/$CUSTOM_NAME/gpu"

	# option cpuOnly
	cpuOnly=$(jq -r '.Settings.cpuOnly // "no"' <<< "$conf")

	# if "amountOfThreads" >0
	amountOfThreads=$(echo $conf | jq -r '.Settings.amountOfThreads')
	if [[ -n $amountOfThreads ]] && [[ $amountOfThreads -gt 0 ]]; then
		# delete "allowHwInfoCollect" & "overwrites" for CPU
		cpu_conf=$(echo $conf | jq 'del(.Settings.allowHwInfoCollect) | .Settings.overwrites |= with_entries(select(.key == "SKYLAKE" or .key == "AVX512"))')

		# "-cpu" alias for CPU
		cpu_conf=$(echo $cpu_conf | jq '.Settings.alias += "cpu"')

		# CPU appsettings.json
		echo $cpu_conf | jq . > "$CPU_DIR/appsettings.json"
	else
		# delete appsettings.json CPU if exists
		[[ -f "$CPU_DIR/appsettings.json" ]] && rm "$CPU_DIR/appsettings.json"
	fi

	# delete "amountOfThreads" for GPU
	gpu_conf=$(echo $conf | jq 'del(.Settings.amountOfThreads)')
	# GPU appsettings.json
	echo $gpu_conf | jq . > "$GPU_DIR/appsettings.json"

	if [[ $cpuOnly == "yes" ]]; then
	   # delete appsettings.json GPU if exists
	   [[ -f "$GPU_DIR/appsettings.json" ]] && rm "$GPU_DIR/appsettings.json"
	   :
	fi

# end
fi
