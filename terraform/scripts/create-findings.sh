#!/bin/bash

cat <<EOF >.findings.sh
#!/bin/bash

curl --silent --location -O https://secure.eicar.org/eicar.com
curl --silent --location -O https://secure.eicar.org/eicarcom2.zip
sudo mv eicarcom2.zip /usr/local/bin
sudo chmod 666 /etc/passwd
sudo chmod 666 /etc/shadow
sudo chown root:ubuntu -R /etc/cron.hourly
echo "huhu" > /tmp/huhu.txt
sudo mv /tmp/huhu.txt /etc
EOF

scp -i $(terraform output -raw private_key_path) -o StrictHostKeyChecking=no .findings.sh ubuntu@$(terraform output -raw public_instance_ip):

ssh -i $(terraform output -raw private_key_path) -o StrictHostKeyChecking=no ubuntu@$(terraform output -raw public_instance_ip) \
  'chmod +x ./.findings.sh && ./.findings.sh'

rm .findings.sh