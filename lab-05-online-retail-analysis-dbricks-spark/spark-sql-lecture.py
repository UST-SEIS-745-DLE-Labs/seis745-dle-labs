# Databricks notebook source
# DBTITLE 1,Leveraging spark read operation to read external CSV file into a DataFrame
invoices = spark.read \
    .csv("/databricks-datasets/online_retail/data-001/data.csv", header=True, inferSchema=True)

display(invoices)

# COMMAND ----------

# DBTITLE 1,Translate strings to timestamp and inspect the output
invoice_typed = invoices.selectExpr(
  "InvoiceNo AS invoice_number",
  "StockCode AS stock_code",
  "InvoiceDate AS original_invoice_date",
  "TO_TIMESTAMP(InvoiceDate, 'M/d/yy H:m') AS invoice_date"
)

invoice_typed.printSchema()
display(invoice_typed)

# COMMAND ----------

# DBTITLE 1,Define a new date column using the withColumn approach
import pyspark.sql.functions as F

invoice_with_column = invoices.withColumn("invoice_date_v2", F.to_timestamp(F.col("InvoiceDate"), "M/d/yy H:m"))

display(invoice_with_column)

# COMMAND ----------

# DBTITLE 1,Using withColum and F.expr
invoice_with_column = invoices.withColumn("invoice_date_v2", F.expr("TO_TIMESTAMP(InvoiceDate, 'M/d/yy H:m') AS invoice_date"))

display(invoice_with_column)

# COMMAND ----------

# DBTITLE 1,Creating a SQL view
invoices.createTempView("invoices")

# COMMAND ----------

# DBTITLE 1,Leveraging in-line SQL
# MAGIC %sql
# MAGIC SELECT 
# MAGIC   CAST(InvoiceNo AS LONG) AS InvoiceNoLong,
# MAGIC   TO_TIMESTAMP(InvoiceDate, 'M/d/yy H:m') AS InvoiceDateTyped,
# MAGIC   Description
# MAGIC FROM invoices
# MAGIC WHERE Description LIKE '%BLOCKS';

# COMMAND ----------

# DBTITLE 1,Spark read with inferSchema
invoices = spark.read \
    .csv("/databricks-datasets/online_retail/data-001/data.csv", header=True, inferSchema=True)


invoices.printSchema()

# COMMAND ----------

# DBTITLE 1,Using the Dataframe API
df_select = invoices.select(
  (invoices["UnitPrice"] * invoices["Quantity"]).alias("Revenue"), 
  invoices["CustomerID"])
display(df_select.take(5))

# COMMAND ----------

# DBTITLE 1,Aggregations by Customer ID using the DataFrame API
# Example: Group by customer ID
df_group_by = df_select.groupBy(df_select["CustomerID"])
df_aggregated = df_group_by.agg(F.sum("Revenue").alias("Revenue"))

# Example: Sort by Revenue
df_sorted = df_aggregated.sort(df_aggregated["Revenue"].desc())

display(df_sorted.take(5))

# COMMAND ----------

# DBTITLE 1,Filtering results using the DataFrame API
#Example: Filter nulls
df_filtered = df_sorted.where(df_sorted["CustomerID"].isNotNull())

display(df_filtered.take(5))

# COMMAND ----------

# DBTITLE 1,Explicit aggregations by stock code
# Putting it all together, what products are sold at the highest quantity in the UK?
df_uk = invoices.filter((invoices["Country"] == "United Kingdom") & (invoices["StockCode"] != ""))

df_uk_products = df_uk.select(df_uk["StockCode"], df_uk["Quantity"])

df_uk_product_quantity = df_uk_products.groupBy(df_uk_products["StockCode"])

df_aggregated = df_uk_product_quantity.agg(F.sum(df_uk_products["Quantity"]).alias("TotalQuantity"))

df_sorted = df_aggregated.sort(df_aggregated["TotalQuantity"].desc())

display(df_sorted.take(10))

# COMMAND ----------

# DBTITLE 1,Abbreviated aggregations by stock code
# Example: Filtering, aggregating, and sorting using the DataFrame API:
df_sorted = invoices.filter((F.col("Country") == "United Kingdom") & (F.col("StockCode") != "")) \
          .select(F.col("StockCode"), F.col("Quantity")) \
          .groupBy(F.col("StockCode")) \
          .agg(F.sum(F.col("Quantity")).alias("TotalQuantity")) \
          .sort(F.col("TotalQuantity").desc())

display(df_sorted.take(10))

# COMMAND ----------

# DBTITLE 1,Visualization of sales by stock code
# Example: Group by stock code
df_aggregated_sorted = invoices \
  .withColumn("Revenue", (invoices["UnitPrice"] * invoices["Quantity"])) \
  .groupBy("StockCode") \
  .agg(F.sum("Revenue").alias("Revenue")) \
  .sort(F.col("Revenue").desc()) \
  .take(10)

display(df_aggregated_sorted)

# COMMAND ----------

# DBTITLE 1,Leveraging dictionary-based aggregation
# Similarly, find the highest grossing product using dict object as input to the agg function
df_uk = invoices.filter((invoices["Country"] == "United Kingdom") & (invoices["StockCode"] != ""))

df_uk_products = df_uk.select(df_uk["StockCode"], (df_uk["Quantity"] * df_uk["UnitPrice"]).alias("TotalRevenue"))

df_aggregated = df_uk_products.groupBy(df_uk_products["StockCode"]).agg({"TotalRevenue": "sum"})

df_sorted = df_aggregated.sort(df_aggregated["sum(TotalRevenue)"].alias("TotalRevenue").desc())
          
display(df_sorted)

# COMMAND ----------

# DBTITLE 1,Abbreviated dictionary-based aggregation
df_averaged = invoices \
                .groupBy(invoices["Description"]) \
                .agg({"Quantity": "min"}) \
                .sort(F.col("min(Quantity)").asc())

display(df_averaged.take(10))

# COMMAND ----------

# DBTITLE 1,Select shorthand
# Using agg to quickly list order statistics:
df_product_orders = invoices.select(invoices["StockCode"], \
                                    invoices["Quantity"], \
                                    (invoices["UnitPrice"] * invoices["Quantity"]).alias("TotalRevenue"))

# COMMAND ----------

# DBTITLE 1,DataFrame partition by country, order by revenue
from pyspark.sql.window import Window
from pyspark.sql.functions import row_number, col

# Select columns.  Use df["column"] syntax rather than df.column to avoid issues
df_select = invoices.select(invoices["Country"], invoices["Description"], (invoices["UnitPrice"] * invoices["Quantity"]).alias("Revenue"))

windowSpec  = Window.partitionBy("Country").orderBy(col("Revenue").desc())

df_ranked = df_select.withColumn("row_number", F.rank().over(windowSpec))

# Top product in each country by revenue
display(df_ranked.where(col("row_number") == 1))

# COMMAND ----------

# DBTITLE 1,Using SQL with Dataframes
invoices.createOrReplaceTempView("invoice")

tbl_output = spark.sql("""
  SELECT TO_TIMESTAMP(invoicedate, "M/d/yy H:mm") FROM invoice WHERE TO_TIMESTAMP(invoicedate, "M/d/yy H:mm") IS not NULL
  """)

display(tbl_output)

# COMMAND ----------

# DBTITLE 1,Spark SQL approach
highest_grossing_uk_products = spark.sql("""
  SELECT StockCode, sum(Quantity * UnitPrice) as TotalRevenue
  FROM invoice
  WHERE country = "United Kingdom"
  AND StockCode is not null
  GROUP BY StockCode
  ORDER BY sum(Quantity * UnitPrice) desc
  LIMIT 10
""")

display(highest_grossing_uk_products.take(5))

# COMMAND ----------

# DBTITLE 1,In-line SQL leveraging %sql magic command
# MAGIC %sql
# MAGIC SELECT StockCode, sum(Quantity * UnitPrice) as TotalRevenue
# MAGIC FROM invoice
# MAGIC WHERE country = "United Kingdom"
# MAGIC AND StockCode IS NOT NULL
# MAGIC GROUP BY StockCode
# MAGIC ORDER BY sum(Quantity * UnitPrice) desc
# MAGIC LIMIT 10;

# COMMAND ----------

# DBTITLE 1,Optimization leveraging explain and a physical execution plan
explain_plan = spark.sql("""
  EXPLAIN
  SELECT StockCode, sum(Quantity * UnitPrice) as TotalRevenue
  FROM invoice
  WHERE country = "United Kingdom"
  AND StockCode is not null
  GROUP BY StockCode
  ORDER BY sum(Quantity * UnitPrice) desc
  LIMIT 10
""")

display(explain_plan)