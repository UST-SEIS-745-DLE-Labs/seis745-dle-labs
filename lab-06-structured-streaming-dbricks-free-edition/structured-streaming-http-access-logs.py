# Databricks notebook source
# MAGIC %fs ls /databricks-datasets/sample_logs

# COMMAND ----------

# DBTITLE 1,Non-streaming DataFrame
import re
from pyspark.sql.types import *
import pyspark.sql.functions as F

inputPath = "/databricks-datasets/sample_logs/"
df = spark.read.text(inputPath)

converted = (
  df.select(F.unix_timestamp(F.regexp_replace(F.regexp_extract(df["value"], r".+\[(.+)]", 1), " ", ""), "dd/MMM/yyyy:HH:mm:ssZ")
                     .cast(TimestampType()).alias("RequestDateTime"),
                     F.split(df["value"], " ")[8].alias("HTTPStatusCode"))
    .filter(df["HTTPStatusCode"] >= 400)
    .groupBy(
      df["HTTPStatusCode"], 
      F.window(df["RequestDateTime"], "1 hour"))
    .count()
)



display(df)
display(converted.limit(10))

# COMMAND ----------

# MAGIC %sql
# MAGIC DROP VOLUME IF EXISTS workspace.default.`http-logs-checkpoint`;
# MAGIC CREATE VOLUME IF NOT EXISTS workspace.default.`http-logs-checkpoint`;

# COMMAND ----------

checkpoint_location = "/Volumes/workspace/default/http-logs-checkpoint"

# COMMAND ----------

from pyspark.sql.types import *
import pyspark.sql.functions as F

inputPath = "/databricks-datasets/sample_logs/"

stream = (
    spark
    .readStream
    .option("maxFilesPerTrigger", 1)
    .option("checkpointLocation", checkpoint_location)
    .text(inputPath)
)

aggregated = (
    stream.select(F.unix_timestamp(F.regexp_replace(F.regexp_extract(stream["value"], r".+\[(.+)]", 1), " ", ""), "dd/MMM/yyyy:HH:mm:ssZ")
                     .cast(TimestampType()).alias("RequestDateTime"),
                     F.split(stream["value"], " ")[8].alias("HTTPStatusCode"))
    .filter(stream["HTTPStatusCode"] >= 400)
    .groupBy(
      stream["HTTPStatusCode"], 
      F.window(stream["RequestDateTime"], "1 hour"))
    .count()
)

(aggregated.writeStream
         .format("memory")
         .queryName("live_http_counts")
         .outputMode("update")
         .trigger(availableNow=True)
         .option("checkpointLocation", checkpoint_location)
         .start())

# COMMAND ----------

# DBTITLE 1,Check if DF is a streaming DataFrame (structured stream)
aggregated.isStreaming

# COMMAND ----------

# Re-execute this cell to update counts from streaming data
display(spark.table("live_http_counts"))
