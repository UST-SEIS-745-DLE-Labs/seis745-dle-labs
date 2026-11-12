############################################
# INITIALIZE LAB PARAMETERS AND VARIABLES  #
############################################
INFRA_DIR=/home/codespace/seis745-dle-labs/infra-ec2
source ${INFRA_DIR}/lab-params.sh

############################################
# COPY FILES, CONNECT TO EC2 INSTANCE      #
############################################
EC2_DNS=`aws ec2 describe-instances --filters "Name=tag:Name,Values=${LAB_EC2_NAME}" "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].PublicDnsName | [0] | [0]' --output text`

ssh -i "${LAB_KEY_FILE}" "ec2-user@${EC2_DNS}"

############################################
# LAB COMMANDS ON EMR                      #
############################################
sudo yum install docker -y # Install docker using the yum package manager
sudo service docker start # Start docker on the host VM

mkdir ~/lab-files
mkdir -p ~/neo4j/data
mkdir -p ~/neo4j/backups

curl -o ~/lab-files/movies.dump https://raw.githubusercontent.com/neo4j-graph-examples/recommendations/refs/heads/main/data/recommendations-50.dump

sudo docker run -d --rm \
  --name neo4j_lab \
  -p=7474:7474 \
  -p=7687:7687  \
  -v ~/lab-files:/home/docker/docker-share \
  -v ~/neo4j/data:/data \
  -v ~/neo4j/backups:/backups \
  neo4j:latest
  
sudo docker exec -it neo4j_lab sh -c "/var/lib/neo4j/bin/neo4j-admin database load --from-path=/home/docker/docker-share movies --overwrite-destination"

sudo docker stop neo4j_lab

sudo docker run -d --rm \
  --name neo4j_lab \
  -p=7474:7474 \
  -p=7687:7687  \
  -v ~/lab-files:/home/docker/docker-share \
  -v ~/neo4j/data:/data \
  -v ~/neo4j/backups:/backups \
  --env NEO4J_PLUGINS='["graph-data-science", "apoc", "bloom"]' \
  --env NEO4J_initial_dbms_default__database=movies \
  neo4j:latest # ctrl-c to exit

TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
EC2_DNS=`curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-hostname`

echo "Neo4j URL: http://$EC2_DNS:7474"