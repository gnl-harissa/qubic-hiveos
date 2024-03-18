start_time=$(date +%s)

get_cpu_temps () {
  local t_core=`cpu-temp`
  local i=0
  local l_num_cores=$1
  local l_temp=
  for (( i=0; i < ${l_num_cores}; i++ )); do
    l_temp+="$t_core "
  done
  echo ${l_temp[@]} | tr " " "\n" | jq -cs '.'
}

get_cpu_fans () {
  local t_fan=0
  local i=0
  local l_num_cores=$1
  local l_fan=
  for (( i=0; i < ${l_num_cores}; i++ )); do
    l_fan+="$t_fan "
  done
  echo ${l_fan[@]} | tr " " "\n" | jq -cs '.'
}

get_cpu_bus_numbers () {
  local i=0
  local l_num_cores=$1
  local l_numbers=
  for (( i=0; i < ${l_num_cores}; i++ )); do
    l_numbers+="null "
  done
  echo ${l_numbers[@]} | tr " " "\n" | jq -cs '.'
}

get_miner_uptime(){
    local start_time=$(cat "/tmp/miner_start_time")
    local current_time=$(date +%s)
    let uptime=current_time-start_time
    echo $uptime
}

get_log_time_diff(){
  local a=0
  let a=`date +%s`-`stat --format='%Y' $log_name`
  echo $a
}

custom_name="couscoubic"
custom_version=$(grep "^CUSTOM_VERSION=" "$custom_name/h-manifest.conf" | cut -d'=' -f2)
log_basename=$(grep "^CUSTOM_LOG_BASENAME=" "$custom_name/h-manifest.conf" | cut -d'=' -f2)
log_name="$log_basename"
log_name_cpu="${log_basename}_cpu.log"
log_name_gpu="${log_basename}_gpu.log"
log_head_name="${log_basename}_head.log"
cpu_indexes_array=$(cat $GPU_DETECT_JSON | jq -c '[ . | to_entries[] | select(.value.brand == "cpu" or .value.brand == "intel") | .key ]')
conf_cpu="/hive/miners/custom/$custom_name/cpu/appsettings.json"
conf_gpu="/hive/miners/custom/$custom_name/gpu/appsettings.json"

diffTime=$(get_log_time_diff)
maxDelay=250


ver="$custom_version"
hs_units="khs"
algo="qubic"

uptime=$(get_miner_uptime)
[[ $uptime -lt 60 ]] && head -n 50 $log_name > $log_head_name

cpu_temp=`cpu-temp`
[[ $cpu_temp = "" ]] && cpu_temp=null

cpu_is_working=$( [[ -f "$conf_cpu" ]] && echo "yes" || echo "no" )
gpu_is_working=$( [[ -f "$conf_gpu" ]] && echo "yes" || echo "no" )

# Extraction du hashrate moyen pour le CPU
if [[ $cpu_is_working == "yes" ]] && [[ $gpu_is_working == "yes" ]]; then
khs=$(tail -n 50 "$log_name_gpu" | grep "Try" | awk -F '|' '{print $5}' | awk '{print $1/1000}' | tail -n 1)
khscpu=$(tail -n 50 "$log_name_cpu" | grep "Try" | awk -F '|' '{print $5}' | awk '{print $1/1000}' | tail -n 1)
elif  [[ $gpu_is_working == "yes" ]]; then
khs=$(tail -n 50 "$log_name_gpu" | grep "Try" | awk -F '|' '{print $5}' | awk '{print $1/1000}' | tail -n 1)
khscpu="0"
else
khscpu=$(tail -n 50 "$log_name_cpu" | grep "Try" | awk -F '|' '{print $5}' | awk '{print $1/1000}' | tail -n 1)
khs="0"
fi

if [[ $cpu_is_working == "yes" && $gpu_is_working == "yes" ]]; then
# Extraction des solutions acceptées et rejetées pour GPU et CPU
gpu_ac=$(tail -n 10 "$log_name_gpu"  | grep "Try" | awk -F 'SOL: ' '{print $2}' | awk -F '/' '{print $1}' | tail -n 1)
gpu_rj=$(tail -n 10 "$log_name_gpu"  | grep "Try" | awk -F 'SOL: ' '{print $2}' | awk -F '/' '{if ($2>$1) print $2-$1; else print 0}' | tail -n 1)
cpu_ac=$(tail -n 10 "$log_name_cpu"  | grep "Try" | awk -F 'SOL: ' '{print $2}' | awk -F '/' '{print $1}' | tail -n 1)
cpu_rj=$(tail -n 10 "$log_name_cpu"  | grep "Try" | awk -F 'SOL: ' '{print $2}' | awk -F '/' '{if ($2>$1) print $2-$1; else print 0}' | tail -n 1)

# Mise à jour des valeurs uniquement si elles sont supérieures ou égales
[[ -n $gpu_ac && $gpu_ac -ge $previous_gpu_ac ]] && previous_gpu_ac=$gpu_ac
[[ -n $gpu_rj && $gpu_rj -ge $previous_gpu_rj ]] && previous_gpu_rj=$gpu_rj
[[ -n $cpu_ac && $cpu_ac -ge $previous_cpu_ac ]] && previous_cpu_ac=$cpu_ac
[[ -n $cpu_rj && $cpu_rj -ge $previous_cpu_rj ]] && previous_cpu_rj=$cpu_rj

ac=$((previous_gpu_ac + previous_cpu_ac))
rj=$((previous_gpu_rj + previous_cpu_rj))
else
ac=$(tail -n 10 "$log_name_gpu" | grep "Try" | awk -F 'SOL: ' '{print $2}' | awk -F '/' '{print $1}' | tail -n 1)
rj=$(tail -n 10 "$log_name_gpu" | grep "Try" | awk -F 'SOL: ' '{print $2}' | awk -F '/' '{if ($2>$1) print $2-$1; else print 0}' | tail -n 1)
fi

#GPUs nb
cpu_count=`cat $log_head_name | tail -n 50 | grep "threads are used" | tail -n 1 | cut -d " " -f3`
[[ $cpu_count = "" ]] && cpu_count=0
gpu_count=`lspci | grep ' VGA ' | wc -l` # Pourquoi se bouffer les couilles le miner ne gère même pas l''exclusion de gpus ... `cat $log_head_name | tail -n 50 | grep "CUDA devices are used" | tail -n 1 | cut -d " " -f3`
[[ $gpu_count = "" ]] && gpu_count=0


if [[ $cpu_is_working == "yes" ]] ; then
# CPU
hs[$gpu_count]=$khscpu
temp[$gpu_count]=$cpu_temp
fan[$gpu_count]=""
bus_numbers[$gpu_count]="null"
total_khs=$(bc <<< "$khs + $khscpu")
else
total_khs=$khs
fi
# GPUs
gpu_temp=$(jq '.temp' <<< $gpu_stats)
gpu_fan=$(jq '.fan' <<< $gpu_stats)
gpu_bus=$(jq '.busids' <<< $gpu_stats)
if [[ $cpu_indexes_array != '[]' ]]; then
gpu_temp=$(jq -c "del(.$cpu_indexes_array)" <<< $gpu_temp) &&
gpu_fan=$(jq -c "del(.$cpu_indexes_array)" <<< $gpu_fan) &&
gpu_bus=$(jq -c "del(.$cpu_indexes_array)" <<< $gpu_bus)
fi

total_hs=0
for (( i=0; i < ${gpu_count}; i++ )); do
hs[$i]=$(cat $log_name_gpu | tail -n 100 | grep "Trainer: GPU#$i" | awk '{print $(NF-1)}' | awk '{print $1/1000}' | sort -nr | head -n 1)
if [[ -z ${hs[$i]} ]] || (( $(echo "${hs[$i]} == 0" | bc -l) )); then
hs[$i]=$(cat $log_name_gpu | tail -n 100 | grep -oP "GPU #$i: \K\d+(?= it/s)" | sort -nr | head -n 1)
[[ -z ${hs[$i]} ]] && hs[$i]=0
fi
total_hs=$(echo "$total_hs + ${hs[$i]}" | bc -l)
temp[$i]=$(jq .[$i] <<< $gpu_temp)
fan[$i]=$(jq .[$i] <<< $gpu_fan)
busid=$(jq .[$i] <<< $gpu_bus)
bus_numbers[$i]=$(echo $busid | cut -d ":" -f1 | cut -c2- | awk -F: '{ printf "%d\n",("0x"$1) }')
done

if (( $(echo "$total_hs == 0" | bc -l) )); then
for (( i=0; i < ${gpu_count}; i++ )); do
hs[$i]=$(echo "scale=2; $khs / $gpu_count" | bc)
done
fi

stats=$(jq -nc \
	--arg total_khs "$total_khs" \
	--arg khs "$khs" \
	--arg hs_units "$hs_units" \
	--argjson hs "`echo ${hs[@]} | tr " " "\n" | jq -cs '.'`" \
	--argjson temp "`echo ${temp[@]} | tr " " "\n" | jq -cs '.'`" \
	--argjson fan "`echo ${fan[@]} | tr " " "\n" | jq -cs '.'`" \
	--arg uptime "$uptime" \
	--arg ver "$ver" \
	--arg ac "$ac" --arg rj "$rj" \
	--arg algo "$algo" \
	--argjson bus_numbers "`echo ${bus_numbers[@]} | tr " " "\n" | jq -cs '.'`" \
	'{$total_khs, $hs, $hs_units, $temp, $fan, $uptime, $ver, ar: [$ac, $rj], $algo, $bus_numbers}')

# debug output

 echo khs:   $khs
 echo stats: $stats 
 echo ----------
