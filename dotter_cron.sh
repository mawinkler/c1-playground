n=1
while [ $n -le 12 ]  
do
  echo "# PAWNED $(date +%H-%M-%S)" >> /etc/cron.weekly/mdadm
  sleep 5
  n=$(( n+1 ))
done