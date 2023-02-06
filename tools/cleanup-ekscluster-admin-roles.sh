for role in $(aws iam list-roles | jq -r '.Roles[] | select(.RoleName | contains("ekscluster-admin")) | .RoleName'); do
    # if [ ! "$role" == "ekscluster-admin-78439c39" ]; then
        for instanceprofile in $(aws iam list-instance-profiles-for-role --role-name $role | jq -r '.InstanceProfiles[] | .InstanceProfileName'); do
            echo Removing role from instance profile $instanceprofile
            aws iam remove-role-from-instance-profile --instance-profile-name $instanceprofile --role-name $role
            aws iam delete-instance-profile --instance-profile-name $instanceprofile
        done
        for policy in $(aws iam list-role-policies --role-name $role | jq -r '.PolicyNames[]'); do # | .InstanceProfileName'); do
            echo Detaching policy $policy
        done
        echo Deleting role $role
        aws iam delete-role --role-name $role
    # fi
done