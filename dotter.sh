n=1
while [ $n -le 12 ]  
do
  echo PAWNED > /tmp/PAWNED-$(date +%H%M%S)
  chmod +x /tmp/PAWNED*
  sleep 5
  n=$(( n+1 ))
done