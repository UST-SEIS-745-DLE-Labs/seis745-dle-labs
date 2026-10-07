# Databricks notebook source
# MAGIC %sql
# MAGIC DROP DATABASE IF EXISTS workspace.retail_db CASCADE;

# COMMAND ----------

with open("./retail_db_dbricks.sql") as f:
    sql = f.read()

for statement in sql.split(";"):
    if statement is None or statement.strip() == "":
        print("Not executing empty statement.")
    else:
        spark.sql(statement)

# COMMAND ----------

categories = spark.table('workspace.retail_db.categories')
display(categories)

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT * FROM workspace.retail_db.categories