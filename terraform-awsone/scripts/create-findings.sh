#!/bin/bash

cat <<EOF >.findings.sh
#!/bin/bash

# drop some eicars
curl --silent --location -O https://secure.eicar.org/eicar.com
sudo mv eicar.com /usr/sbin
curl --silent --location -O https://secure.eicar.org/eicarcom2.zip
sudo mv eicarcom2.zip /usr/local/bin

# chmod & chown
sudo chmod 666 /etc/passwd
sudo chmod 666 /etc/shadow
sudo chown root:ubuntu -R /etc/cron.hourly

# make me root
sudo sed -i 's/root:x:0:/root:x:0:ubuntu/g' /etc/group

# drop something to /etc
echo "huhu" > /tmp/huhu.txt
sudo mv /tmp/huhu.txt /etc
EOF

identity=$(terraform output -raw private_key_path)
# identity=cnctraining-key-pair
host_ip=$(terraform output -raw public_instance_ip_web1)
# host_ip=3.70.227.113

scp -i ${identity} -o StrictHostKeyChecking=no .findings.sh ubuntu@${host_ip}:

ssh -i ${identity} -o StrictHostKeyChecking=no ubuntu@${host_ip} \
  'chmod +x ./.findings.sh && ./.findings.sh'

rm .findings.sh