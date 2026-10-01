############################################
# INITIALIZE LAB PARAMETERS AND VARIABLES  #
############################################
LAB_INFRA_FOLDER="infra-emr-cluster"
LAB_FOLDER="lab-04-online-retail-analysis-with-spark"
LAB_HOME="/home/codespace"

cd "${LAB_HOME}/seis745-dle-labs/${LAB_FOLDER}"
source ../${LAB_INFRA_FOLDER}/lab-params.sh

S3_BUCKET_NAME=`aws s3api list-buckets --query "Buckets[0].Name" --output text`

############################################
# COPY FILES, CONNECT TO EMR MASTER NODE   #
############################################
LAB_CLUSTER_ID=`aws emr list-clusters --query "Clusters[?Name=='${LAB_ENV_NAME}'].Id | [0]" --output text`
aws emr wait cluster-running --cluster-id ${LAB_CLUSTER_ID}
LAB_EMR_MASTER_PUBLIC_HOST=`aws emr describe-cluster --cluster-id ${LAB_CLUSTER_ID} --query Cluster.MasterPublicDnsName --output text`

echo "Access HUE console here: http://${LAB_EMR_MASTER_PUBLIC_HOST}:8888"

# Copy lab files to Hadoop master node
scp -i "${LAB_KEY_FILE}" retail_db.sql "hadoop@${LAB_EMR_MASTER_PUBLIC_HOST}:/home/hadoop"

ssh -i "${LAB_KEY_FILE}" "hadoop@${LAB_EMR_MASTER_PUBLIC_HOST}"

############################################
# LAB COMMANDS ON EMR                      #
############################################

# Retrieve default username, password, and host name for mysql
MYSQL_PASSWORD=`sudo mysql --print-defaults | grep port=3306 | sed -r 's/(.+)--password=([^ ]+) --(.+)/\2/'`
MYSQL_USER=`sudo mysql --print-defaults | grep port=3306 | sed -r 's/(.+)--user=([^ ]+) --(.+)/\2/'`
MASTER_NODE_PRIVATE_HOST=`hostname -i`

# Connect to local mysql server and create a sqoop user.
mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}"
CREATE USER 'spark'@'%' IDENTIFIED BY 'changeme1';
GRANT ALL PRIVILEGES ON *.* TO 'spark';
source /home/hadoop/retail_db.sql
exit;

# Set environment variables in spark configurations
sudo su root
MASTER_NODE_PRIVATE_HOST=`hostname -i`
SPARK_USER=spark
SPARK_PASSWORD=changeme1
printf "\n\nexport SPARK_PASSWORD=${SPARK_PASSWORD}" >> /usr/lib/spark/conf/spark-env.sh
printf "\nexport SPARK_USER=${SPARK_USER}" >> /usr/lib/spark/conf/spark-env.sh
printf "\nexport MASTER_NODE_PRIVATE_HOST=${MASTER_NODE_PRIVATE_HOST}" >> /usr/lib/spark/conf/spark-env.sh
exit

pyspark

import os

df_mariadb_databases = spark.read.format("jdbc") \
  .options(
    driver = "org.mariadb.jdbc.Driver",
    url = f"jdbc:mariadb://{os.environ['MASTER_NODE_PRIVATE_HOST']}",
    user = os.environ['SPARK_USER'],
    password = os.environ['SPARK_PASSWORD'],
    dbtable = "information_schema.schemata"
  ).load()

df_mariadb_databases.select("schema_name").show()

df_mariadb_tables = spark.read.format("jdbc") \
  .options(
    driver = "org.mariadb.jdbc.Driver",
    url = f"jdbc:mariadb://{os.environ['MASTER_NODE_PRIVATE_HOST']}/retail_db",
    user = os.environ['SPARK_USER'],
    password = os.environ['SPARK_PASSWORD'],
    dbtable = "information_schema.tables"
  ).load()

df_mariadb_tables \
  .where("table_schema == 'retail_db'") \
  .select("table_name") \
  .show()

exit()

hadoop credential create mysql.password \
    -value changeme1 \
    -provider \
    jceks://hdfs/user/root/keystores/database.passwords.jceks # Create a keystore file to store database credentials
    
hdfs dfs -ls /user/root/keystores # List keystores, make sure keystore exists

S3_BUCKET_NAME=`aws s3api list-buckets --query "Buckets[0].Name" --output text`
pyspark --conf spark.driver.args="$S3_BUCKET_NAME"

s3_bucket = sc.getConf().get("spark.driver.args")

keystore = "jceks://hdfs/user/root/keystores/database.passwords.jceks"
alias = "mysql.password"

config = spark.sparkContext._jsc.hadoopConfiguration()
config.set("hadoop.security.credential.provider.path", keystore)
pw_bytes = config.getPassword(alias)
db_password = ''.join(pw_bytes)

def import_jdbc_to_s3(driver, jdbc_url, user, password, source_table, s3_bucket, target_directory):
    source_df = spark.read.format("jdbc") \
    .options(
        driver = "org.mariadb.jdbc.Driver",
        url = jdbc_url,
        user = user,
        password = password,
        dbtable = source_table
    ).load()
    
    source_df.write.parquet(f"s3://{s3_bucket}/{target_directory}")

jdbc_driver = "org.mariadb.jdbc.Driver"
jdbc_url = f"jdbc:mariadb://{os.environ['MASTER_NODE_PRIVATE_HOST']}/retail_db"
db_user = os.environ['SPARK_USER']

import_jdbc_to_s3(jdbc_driver, jdbc_url, db_user, db_password, "categories", s3_bucket, "online_retail_dataset/categories")
import_jdbc_to_s3(jdbc_driver, jdbc_url, db_user, db_password, "customers", s3_bucket, "online_retail_dataset/customers")
import_jdbc_to_s3(jdbc_driver, jdbc_url, db_user, db_password, "departments", s3_bucket, "online_retail_dataset/departments")
import_jdbc_to_s3(jdbc_driver, jdbc_url, db_user, db_password, "order_items", s3_bucket, "online_retail_dataset/order_items")
import_jdbc_to_s3(jdbc_driver, jdbc_url, db_user, db_password, "orders", s3_bucket, "online_retail_dataset/orders")
import_jdbc_to_s3(jdbc_driver, jdbc_url, db_user, db_password, "products", s3_bucket, "online_retail_dataset/products")

exit()

exit
