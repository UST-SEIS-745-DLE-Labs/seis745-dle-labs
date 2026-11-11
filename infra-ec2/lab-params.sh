############################################
# INITIALIZE LAB PARAMS                    #
############################################
CLIENT_IP="10.10.10.10" # Change this line
LAB_EC2_NAME="lab-ec2-base"
LAB_KEY_NAME="${LAB_EC2_NAME}-keypair"
LAB_KEY_FILE="/home/codespace/${LAB_KEY_NAME}.pem"
CODESPACE_IP=`curl ifconfig.me`