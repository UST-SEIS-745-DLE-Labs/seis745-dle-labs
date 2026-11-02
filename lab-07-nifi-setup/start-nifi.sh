############################################
# INITIALIZE LAB PARAMETERS AND VARIABLES  #
############################################
INFRA_DIR=/home/codespace/seis745-dle-labs/infra-ec2
source ${INFRA_DIR}/lab-params.sh

############################################
# COPY FILES, CONNECT TO EC2 INSTANCE      #
############################################
EC2_DNS=`aws ec2 describe-instances --filters "Name=tag:Name,Values=${LAB_EC2_NAME}" "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].PublicDnsName | [0] | [0]' --output text`
echo $EC2_DNS > ec2-dns.txt
echo https://$EC2_DNS:9443/nifi > nifi-url.txt

ssh -i "${LAB_KEY_FILE}" "ec2-user@${EC2_DNS}"

############################################
# LAB COMMANDS ON EMR                      #
############################################
sudo yum install docker -y # Install docker using the yum package manager
sudo service docker start # Start docker on the host VM

mkdir /home/ec2-user/lab-files
chmod 777 /home/ec2-user/lab-files

TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
EC2_DNS=`curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-hostname`

sudo docker run -d -p 9443:9443 \
    --name nifi_lab \
    -e NIFI_WEB_HTTPS_PORT='9443' \
    -e NIFI_WEB_HTTPS_HOST='0.0.0.0' \
    -e NIFI_WEB_PROXY_HOST=${EC2_DNS}:9443 \
    -v /home/ec2-user/lab-files:/tmp/nifi-output \
    apache/nifi:2.8.0

sudo docker logs nifi_lab | grep Generated

echo https://$EC2_DNS:9443/nifi