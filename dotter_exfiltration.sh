n=1
while [ $n -le 12 ]  
do
  curl -X POST https://y1of9z8y16.execute-api.eu-west-1.amazonaws.com/default/moadsd-ng-reporter?TableName=moadsd-ng-reporter \
  -H "Content-Type: application/json" \
  -H "x-api-key: kP8LCEmbtg8VBAblGh0nq5ENndRZCbvQ4Rgso1a6" \
  -d "{
    \"TableName\": \"moadsd-ng-reporter\",
    \"Item\": {
      \"datetime\": {\"S\": \"$(date +%Y-%m-%d-%H-%M-%S)\" },
      \"admin_email\": {\"S\": \"c1rs@tm.com\" },
      \"action\": {\"S\": \"exfiltration\" },
      \"type\": {\"S\": \"$(hostname -I)\" }
    }
  }"
  sleep 5
  n=$(( n+1 ))
done