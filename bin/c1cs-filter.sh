#!/bin/bash

# Execute the scan
# SCANRESULT=$(c1cs scan docker:ubuntu:latest --apiKey=1wZuaZZZZ6nLZflnAe8IwF2jXV9:9wMvzrNTPgVNvDzC2L9b9nmzG8XeB2FopifJWpANiMQh7JQ47bjThAss1hr3qeLmyq --endpoint=artifactscan.trend-us-1.cloudone.trendmicro.com)
SCANRESULT=$(cat astrolive-result.json)

# SCANRESULT=$(c1cs scan docker:astrolive:latest --apiKey=1wZuaZZZZ6nLZflnAe8IwF2jXV9:9wMvzrNTPgVNvDzC2L9b9nmzG8XeB2FopifJWpANiMQh7JQ47bjThAss1hr3qeLmyq --endpoint=artifactscan.trend-us-1.cloudone.trendmicro.com)

[[ "$(jq -r '.totalVulnCount' <<< $SCANRESULT)" -gt 0 ]] && \
    printf '%s\n' "Fail: image contains vulnerabilities"

[[ "$(jq -r '.criticalCount+.highCount' <<< $SCANRESULT)" -gt 0 ]] && \
    printf '%s\n' "Fail: image contains critical and/or high vulnerabilities"

critical_nw=$(jq 'if .criticalCount > 0 then
        .findings.Critical[] | select(.attackvector == "network")
    else
        0 end' <<< $SCANRESULT)
high_nw=$(jq 'if .highCount > 0 then 
        .findings.High[] | select(.attackvector == "network")
    else 
        0 end' <<< $SCANRESULT)
echo "$critical_nw$high_nw"
# let "sum=$critical_nw + $high_nw"
# echo $sum
# [ ! "$critical_nw$high_nw" ] || \
# [ ($critical_nw + $high_nw) -gt 0 ] || \
#     printf '%s\n' "Fail: image contains critical and/or high vulnerabilities with attack vector network"

critical_fix=$(jq 'if .criticalCount > 0 then 
        .findings.Critical[] | select(.fix != "unknown" and .fix != "wont-fix")
    else 
        "" end' <<< $SCANRESULT)
high_fix=$(jq 'if .highCount > 0 then
        .findings.High[] | select(.fix != "unknown" and .fix != "wont-fix")
    else
        "" end' <<< $SCANRESULT)
[ ! "$critical_fix$high_fix" ] || \
    printf '%s\n' "Fail: image contains critical and/or high vulnerabilities which could be fixed"


# if (vul_severity==critical || vul_severity==high) && fix!="not-fixed" && fix!="wont-fix"

# cat <<< $SCANRESULT | jq . > artifact.json


        # select(.fix != "unknown" and .fix != "wont-fix")' <<< $SCANRESULT)
        # select(.fix != "unknown" and .fix != "wont-fix" and .attackvector == "network")' <<< $SCANRESULT)

    # HIGH_NW=$(jq -r '.findings.High[] | select(.fix != "unknown" and .fix != "wont-fix")' <<< $SCANRESULT)
    # HIGH_NW=$(jq -r '.findings.High[] | select(.fix != "unknown" and .fix != "wont-fix" and .attackvector == "network")' <<< $SCANRESULT)
