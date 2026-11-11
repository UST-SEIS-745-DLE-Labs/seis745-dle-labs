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
echo https://$EC2_DNS:7474 > neo4j-url.txt

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

sudo docker run -d -p 7474:7474 -p 7687:7687 \
    --name neo4j_lab \
    -v /home/ec2-user/lab-files:/home/docker/docker-share \
    neo4j:5.6.0

echo "Neo4j URL: http://$EC2_DNS:7474"