# 

## Section 1: Set environment variables and create an S3 bucket (or reuse an existing one)

1)  Once you have opened your Codespace and cloned the repository, it
    should look something like this:

![](./media/image2.png)

2)  First, open lab-params.sh You need to update the CLIENT_IP
    variable with your IP address shown at
    <https://checkip.amazonaws.com/>. Don't forget to save lab-params.sh
    after updating the variable (Ctrl+S on Windows)

![](./media/image3.png)

3)  Next, run codespace-init.sh to install lab dependencies and the
    AWS CLI. While it does not hurt to install the AWS CLI a second
    time, if you have previously installed the AWS CLI in this
    environment you may simply run the first and last executable lines
    (sudo apt and aws configure).

> Just like Lab 1, you will need to get your AWS access key id, secret
> access key, and session token from your AWS Academy environment.
>
> ![](./media/image4.png)
>
> ![](./media/image5.png)

4)  Now that you have configured the AWS CLI and set necessary lab
    variables, we can start deploying resources. Open env-init.sh to
    start deploying lab infrastructure. The following lines of code
    initialize lab parameters, queries for an existing S3 bucket using
    the AWS CLI, and creates a new S3 bucket if one does not yet exist.

![](./media/image6.png)

5)  You may double check that your bucket was created at
    <https://s3.console.aws.amazon.com/s3>:

![](./media/image7.png)

## Section 2: Deploy an Amazon EC2 Instance for hosting Debezium

1)  The next step in env-init.sh deploys an EC2
    instance leveraging the AWS CLI. Run this section of code to turn
    your client IP address into a proper CIDR range, create a keypair
    for authentication, create a security group and corresponding
    firewall rules, and run the instance:

    ![](./media/image8.png)

2)  This next section queries instance attributes and assigns them to variables. This includes the instance
    id, public domain name, and local IP address for your EC2 instance.
    It also associates the instance with the security profile
    LabInstanceProfile provided by Vocareum. We will use this to
    facilitate connectivity with the instance and interoperability with
    other AWS resources later in the lab.

    ![](./media/image9.png)

3)  Make sure the EC2 instance is running and review the configuration in the
    AWS console at <https://us-east-1.console.aws.amazon.com/ec2/>:

    ![](./media/image10.png)

## Section 3: Create a cloud MySQL database hosted on RDS and initialize data, streaming tables

1)  In the first two sections, we made sure to deploy a cloud storage
    instance on S3 and a cloud virtual machine on EC2 for hosting
    streaming services. Next, we are going to deploy a SQL Database
    leveraging Amazon's PaaS Relational Database Service (RDS). For this
    lab we will be leveraging MySQL as the database provider and our
    data source.

2)  First, create a new security group
    specifically for secure database access. This will allow your
    Codespace instance, streaming environment on EC2, and PC to access
    MySQL on port 3306:

    ![](./media/image11.png)

3)  The Debezium MySQL connector is dependent on the binary log to
    capture changes. This section of code creates a database parameter
    group which overrides some of the MySQL defaults for compatibility
    with Debezium:

![](./media/image12.png)

4)  Create the RDS instance, associating
    both the security group and parameter group with the new MySQL
    database. Note that the aws rds wait command will block until the
    database is available. It is necessary to wait before moving on to
    the next steps. It takes potentially 5-10 minutes to spin up the RDS
    instance.

    ![](./media/image13.png)

5)  Open the RDS console and view your new
    database instance by clicking 'databases' at
    <https://us-east-1.console.aws.amazon.com/rds>:

    ![](./media/image14.png)

6)  We are leveraging the MySQL employees database to populate sample
    data and explore streaming data collection. This database is
    documented here: <https://dev.mysql.com/doc/employee/en/>. The
    following section of code downloads the database initialization
    artifacts from Git. Note that when you use the MySQL command line
    interface, you are connecting from Cloud9 to your remote RDS
    instance hosted by Amazon.

**Database initialization:**

![](./media/image15.png)

**Database output:**

![](./media/image16.png)

**Database tests:**

![](./media/image17.png)

7)  Rather than stream directly from base tables, we want to avoid an
    overly large initial load (Debezium snapshot load) from these
    tables. Instead, we are creating empty copies of these tables and
    populating them with a subset of data to better manage load on our
    lab environment. We will insert, update, and delete records later in
    the lab once streaming services are up and running.

![](./media/image18.png)

8)  Validate tables leveraging the SHOW TABLES command:

![](./media/image19.png)

## Section 4: Start Debezium services and load Confluent S3 sink connector

1.  Run the following section of code to copy files and open an SSH
    session with your running EC2 instance created in section 2. Note
    that we are copying the Confluent S3 connector (zip file) so that we
    can install it on our Kafka Connect instance later:

![](./media/image20.png)

> **ASCII art welcomes you to the Amazon Linux instance:**

![](./media/image21.png)

1)  You will be using docker to run different services on this machine:
    Zookeeper, Kafka (brokers), Kafka Connect with Debezium/Confluent
    connectors, and Debezium UI (currently expiremental). Run the
    following section of code to install and configure Docker and
    prepare the Confluent connector for installation on Kafka Connect:

![](./media/image22.png)

2)  As discussed in class, Kafka may rely on Zookeeper for cluster
    configuration management and consumer-partition offsets. Zookeeper
    needs to be up and running before we start Kafka. Note that we are
    leveraging the Debezium docker image to run Zookeeper, Kafka,
    Connect, and Debezium services. Query the logs until you see the
    following output indicating that Zookeeper is up and ready to take
    requests.

> ![](./media/image23.png)

**Zookeeper running and ready to take
requests:**

![](./media/image24.png)
3)  Now that Zookeeper is up and running, we can start Kafka. Note the
    docker link, ensuring that the Kafka container can access services
    running on the Zookeeper container. The link feature may be
    deprecated in a future Docker release, but is still used by these
    Debezium containers.

**Starting Kafka:**

![](./media/image25.png)

**Kafka running and ready to take
requests:**

![](./media/image26.png)

4)  Similarly, we are now ready to start Kafka Connect. Note the volume
    mapping which places the extracted Confluent S3 sink connector in
    the plugins directory on Debezium, allowing us to integrate with S3.
    Additionally, there is a link to enable the dependency between Kafka
    Connect and Kafka.

**Starting Kafka Connect:**
> ![](./media/image27.png)
>
**Kafka Connect running and ready to
> take requests:**

> ![](./media/image28.png)

5)  Finally, start Debezium UI. We will take a brief look at this
    service to validate our Debezium connector in the next section. Once
    you have started Debezium UI, you should switch back to your first
    terminal session in Cloud9.

**Starting Debezium UI:**

(./media/image29.png)

6)  List Kafka topics. Now that all of our Kafka and Debezium-related
    service are up and running on our EC2 instance, exit twice to return
    control back to your GitHub Codespace machine. You should see the
    shell user change from ec2-user to your GitHub account name.
    ![](./media/image30.png)