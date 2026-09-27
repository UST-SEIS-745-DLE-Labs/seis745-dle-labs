############################################
# INITIALIZE LAB PARAMS AND AWS CLI        #
############################################
CLIENT_IP="10.10.10.10" # Change this line
LAB_ENV_NAME="lab-emr-cluster"
LAB_STACK_NAME="${LAB_ENV_NAME}-stack"
LAB_KEY_NAME="${LAB_ENV_NAME}-keypair"
LAB_KEY_FILE="/home/codespace/${LAB_KEY_NAME}.pem"
CODESPACE_IP=`curl ifconfig.me`