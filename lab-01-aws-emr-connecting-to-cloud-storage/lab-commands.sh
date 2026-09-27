############################################
# LOAD LAB PARAMETERS                      #
############################################
LAB_INFRA_FOLDER="infra-emr-cluster"
LAB_FOLDER="lab-01-aws-emr-connecting-to-cloud-storage"
LAB_HOME="/home/codespace"

cd "${LAB_HOME}/seis745-dle-labs/${LAB_FOLDER}"
source ../${LAB_INFRA_FOLDER}/lab-params.sh

############################################
# CONNECT TO EMR MASTER NODE               #
############################################
LAB_CLUSTER_ID=`aws emr list-clusters --query "Clusters[?Name=='${LAB_ENV_NAME}'].Id | [0]" --output text`
aws emr wait cluster-running --cluster-id ${LAB_CLUSTER_ID}
LAB_EMR_MASTER_PUBLIC_HOST=`aws emr describe-cluster --cluster-id ${LAB_CLUSTER_ID} --query Cluster.MasterPublicDnsName --output text`

ssh -i "${LAB_KEY_FILE}"

############################################
# PySpark import from AWS Open Data        #
############################################
S3_BUCKET_NAME=`aws s3api list-buckets --query "Buckets[0].Name" --output text`
pyspark --conf spark.driver.args="$S3_BUCKET_NAME"

s3_bucket = sc.getConf().get("spark.driver.args")

noaa_actuals = spark.read.option("header", True).csv('s3://noaa-gsod-pds/2022/*')
noaa_actuals_output = noaa_actuals.coalesce(32)

noaa_actuals_output.write \
  .format('parquet') \
  .mode('overwrite') \
  .save(f's3://{s3_bucket}/noaa_surface_summary/2022')
  
noaa_actuals_output.write \
  .format('parquet') \
  .mode('overwrite') \
  .save('/user/hadoop/noaa_surface_summary/2022')
  
noaa_actuals.show(10)
print(f'2022 weather observations: {noaa_actuals.count()}')

noaa_actuals.createOrReplaceTempView('noaa_actuals')

avg_high = spark.sql("SELECT AVG(MAX) FROM noaa_actuals")
avg_high.show()

avg_high.write \
  .format('csv') \
  .mode('overwrite') \
  .save('/user/hadoop/noaa_aggregates/2022/agg/avg_high_tmp')
  
exit()

############################################
# ACCESS FILES IN HDFS                     #
############################################

hdfs dfs -ls /user/hadoop/noaa_surface_summary # Check imported data in HDFS
hdfs dfs -ls /user/hadoop/noaa_aggregates/2022/agg/avg_high_tmp # Check imported data in HDFS
hdfs dfs -cat /user/hadoop/noaa_aggregates/2022/agg/avg_high_tmp/*.csv # Print file to console.  Replace wildcard with file name.

exit