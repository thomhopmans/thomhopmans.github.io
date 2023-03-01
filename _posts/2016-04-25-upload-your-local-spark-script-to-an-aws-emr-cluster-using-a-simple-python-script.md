---
layout: post
title: "Upload your local Spark script to an AWS EMR cluster using a simple Python script"
date: 2016-04-25 12:00:00 +0100
categories:
    - data engineering
    - python
    - aws
    - spark
image: /images/posts/2016/spark_on_amazon_web_services_aws.png
author: Thom Hopmans
---

<a href="http://spark.apache.org/" target="_blank">Apache Spark</a> is definitely one of the hottest topics in the Data Science community at the moment. Last month when we visited <a href="http://pydata.org/amsterdam2016/" target="_blank">PyData Amsterdam 2016</a> we witnessed a great example of Spark's immense popularity. The speakers at PyData talking about Spark had the largest crowds after all.

Sometimes we see that these popular topics are slowly transforming in *buzzwords* that are abused for generating publicity, e.g. words as *data scientist* and *deep learning* but also *Hadoop* and *DMP*. I don't hope that *Spark* will suffer the same fate as it is definitely a powerful tool for data scientists. In the field of distributed computing Spark provides much more flexibility than MapReduce. Additionally, Spark uses memory more efficiently and therefore writes less data to disk than MapReduce, making Spark on average around 10 to 100 times faster.

In this article we introduce a method to upload our local Spark applications to an **Amazon Web Services (AWS)** cluster in a programmatic manner using a simple Python script. The benefit of doing this programmatically compared to interactively is that it is easier to schedule a Python script to run daily. Additionally, it also saves us time. Time we can spend better by drinking more coffee and thinking of new ideas!

## The challenge

For one of our Data Science applications we recently decided to create a new part of the data pipeline with `PySpark` (Spark in Python). For now, I am not going to elaborate on how to build your own Spark applications as there are already <a href="https://districtdatalabs.silvrback.com/getting-started-with-spark-in-python" target="_blank">plenty></a> of <a href="http://www.tutorialspoint.com/apache_spark/apache_spark_core_programming.htm" target="_blank">tutorials</a> on <a href="https://www.dataquest.io/mission/123/introduction-to-spark/" target="_blank">how to do so</a> on the <a href="https://www.youtube.com/watch?v=dQw4w9WgXcQ&ref=the-marketing-technologist-the-marketing-technology-blog" target="_blank">world wide web</a>.

As usual we started by creating the Spark application using only a subset of the full dataset. This subset is usually small enough to test the Spark application locally on our laptops. Then, after creating a locally working Spark application, we scale the application up using an AWS **Elastic Map Reduce (EMR)** cluster to process the full dataset. However, this is where we ran into some inconvenient issues. The original MapReduce data pipeline was also built in Python using the <a href="https://pythonhosted.org/mrjob/" target="_blank">`MRjob`</a> module. `MRjob` takes away the trouble of uploading your local code to an AWS cluster by using its built-in functions. However, `MRJob` does not support Spark applications (yet?) and therefore we have to get our own hands dirty this time...

## The interactive method using the AWS CLI

Using the <a href="https://aws.amazon.com/cli/" target="_blank">`awscli`</a> module we can quickly spin up an AWS EMR cluster with Spark pre-installed using the commandline.

```bash
aws emr create-cluster \
--name "Spark Example" \
--release-label emr-4.4.0 \
--applications Name=Hadoop Name=Spark 
--ec2-attributes KeyName=keypair\
--instance-groups Name=EmrMaster,InstanceGroupType=MASTER,InstanceCount=1,InstanceType=m3.xlarge,BidPrice=0.05 \
Name=EmrCore,InstanceGroupType=CORE,InstanceCount=2,InstanceType=m3.xlarge,BidPrice=0.05 \
--use-default-roles
```

We need to place our code onto the cluster because we do not want the run the SparkContext on our local computer due to increased latency and availability. Therefore, we SSH into the cluster. On the cluster we create a Python file, e.g. `run.py`, and copy/paste the code for the Spark application.

```bash
aws emr ssh --cluster-id j-XXXX --key-pair-file keypair.pem
sudo nano run.py
-- copy/paste local code to cluster
```

We `logout` of the cluster and add a new step to the EMR cluster to start our Spark application via `spark-submit`.

```bash
aws emr add-steps \
--cluster-id j-XXXXX \
--steps Type=CUSTOM_JAR,Name="Spark Program",Jar="command-runner.jar",ActionOnFailure=CONTINUE,Args=["spark-submit",home/hadoop/run.py]
```

Note that Amazons EMR clusters have access to S3 buckets (if the IAM roles are configured properly though). Therefore, we do not need to add other steps to copy our data back and forth between S3 and the cluster. We can just specify the proper S3 bucket in our Spark application by using for example

```python
data = ("s3://input_bucket/*")
```

or

```python
data = saveAsTextFile("s3://output_bucket/")
```

Unfortunately, this S3 connection only works within our Spark application. We cannot run a Spark Python script hosted on S3 with `spark-submit s3://bucket/spark_code.py`...

## This is still too much work...

Using the AWS command-line interface and the above commands we can interactively move our local Spark application to an AWS cluster. However, this interactive method is not easy to schedule daily as it requires some manual steps. **Especially SSHing into the cluster and copy-pasting our local code to the cluster itself is tricky**. It also does not fit well in our current Python data pipeline. Therefore, we prefer a more programmatic method in Python. This Python script can then be easily scheduled to run daily/weekly/monthly.

## The final solution

Therefore we developed a simple Python script to execute all the necessary steps. The biggest challenge was **how to 'copy/paste' our local code onto the cluster without using SSH**? The solution for this problem turned out to be relatively easy. That is, we compress our local Spark script in a single file, upload this file to a temporary S3 bucket and add a Bootstrap action to the cluster that downloads and decompresses this file.

Hence, the final solution consists of the following steps executed in Python using <a href="https://boto3.readthedocs.org/en/latest/" target="_blank">`Boto3`</a> (an AWS SDK for Python):

- Define a S3 bucket to store our files temporarily and check if it exists

```python
def temp_bucket_exists(self, s3):
    try:
        s3.meta.client.head_bucket(Bucket=self.s3_bucket_temp_files)
    except botocore.exceptions.ClientError as e:
        # If a client error is thrown, then check that it was a 404 error.
        # If it was a 404 error, then the bucket does not exist.
        error_code = int(e.response['Error']['Code'])
        if error_code == 404:
            terminate("Bucket for temporary files does not exist")
        terminate("Error while connecting to Bucket")
    return true
```

- Compress the Python files of the Spark application to a `.tar` file.

```python
def tar_python_script(self):
    # Create tar.gz file
    t_file = tarfile.open("files/script.tar.gz", 'w:gz')
    # Add Spark script path to tar.gz file
    files = os.listdir(self.path_script)
    for f in files:
        t_file.add(self.path_script + f, arcname=f)
    t_file.close()
```

- Upload the `tar` file to the S3 bucket for temporary files.

```python
def upload_temp_files(self, s3):
    # Shell file: setup (download S3 files to local machine)
    s3.Object(self.s3_bucket_temp_files, self.job_name + '/setup.sh').put(
       Body=open('files/setup.sh', 'rb'), ContentType='text/x-sh'
    )
    # Shell file: Terminate idle cluster
    s3.Object(self.s3_bucket_temp_files, self.job_name + '/terminate_idle_cluster.sh').put(
        Body=open('files/terminate_idle_cluster.sh', 'rb'), ContentType='text/x-sh'
    )
    # Compressed Python script files (tar.gz)
    s3.Object(self.s3_bucket_temp_files, self.job_name + '/script.tar.gz').put(
        Body=open('files/script.tar.gz', 'rb'), ContentType='application/x-tar'
    )
```

- Spin up an AWS EMR cluster with Hadoop and Spark as application plus two bootstrap actions. One bootstrap action is a shell script which downloads the `tar` file from our temporary files S3 bucket and decompresses the `tar` file on the remote cluster. The other bootstrap action ensures that the cluster is terminated after an hour of inactivity to prevent high unexpected AWS charges.

### setup.sh

```bash
#!/bin/bash
# Parse arguments
s3_bucket_script="$1/script.tar.gz"
# Download compressed script tar file from S3
aws s3 cp $s3_bucket_script/home/hadoop/script.tar.gz
# Untar file
tar zxvf "/home/hadoop/script.tar.gz" -C /home/hadoop/
# Install requirements for additional Python modules (uncomment if needed)
# sudo python2.7 -m pip install pandas
```

### .py

```python
def start_spark_cluster(self, c):
    response = c.run_job_flow(
        Name=self.job_name,
        ReleaseLabel="emr-4.4.0",
        Instances={
            'InstanceGroups': [
                {'Name': 'EmrMaster',
                 'Market': 'SPOT',
                 'InstanceRole': 'MASTER',
                 'BidPrice': '0.05',
                 'InstanceType': 'm3.xlarge',
                 'InstanceCount': 1},
                {'Name': 'EmrCore',
                 'Market': 'SPOT',
                 'InstanceRole': 'CORE',
                 'BidPrice': '0.05',
                 'InstanceType': 'm3.xlarge',
                 'InstanceCount': 2}
            ],
            'Ec2KeyName': self.ec2_key_name,
            'KeepJobFlowAliveWhenNoSteps': False
        },
        Applications=[{'Name': 'Hadoop'}, {'Name': 'Spark'}],
        JobFlowRole='EMR_EC2_DefaultRole',
        ServiceRole='EMR_DefaultRole',
        VisibleToAllUsers=True,
        BootstrapActions=[
            {'Name': 'setup',
             'ScriptBootstrapAction': {
                 'Path': 's3n://{}/{}/setup.sh'.format(self.s3_bucket_temp_files, self.job_name),
                 'Args': ['s3://{}/{}'.format(self.s3_bucket_temp_files, self.job_name)]}},
            {'Name': 'idle timeout',
             'ScriptBootstrapAction': {
                 'Path': 's3n://{}/{}/terminate_idle_cluster.sh'.format(self.s3_bucket_temp_files, self.job_name),
                 'Args': ['3600', '300']
                    }
                },
            ],
        )
```

- Add a step to the EMR cluster to run the Spark application using `spark-submit`.

```python
def step_spark_submit(self, c, arguments):
    response = c.add_job_flow_steps(
        JobFlowId=self.job_flow_id,
        Steps=[{
            'Name': 'Spark Application',
            'ActionOnFailure': 'CANCEL_AND_WAIT',
            'HadoopJarStep': {
               'Jar': 'command-runner.jar',
               'Args': ["spark-submit", "/home/hadoop/run.py", arguments]
            }
        }]
    )
```

- Describe status of cluster until all steps are finished and cluster is terminated.

```python
def describe_status_until_terminated(self, c):
    stop = False
    while stop is False:
        description = c.describe_cluster(ClusterId=self.job_flow_id)
        state = description['Cluster']['Status']['State']
        if state == 'TERMINATED' or state == 'TERMINATED_WITH_ERRORS':
            stop = True
        print(state)
        time.sleep(30)
```

- Remove the temporary files from the S3 bucket when the cluster is terminated.

```python
def remove_temp_files(self, s3):
    bucket = s3.Bucket(self.s3_bucket_temp_files)
    for key in bucket.objects.all():
        if key.key.startswith(self.job_name) is True:
            key.delete()
```

- Grab a beer and start analyzing the output data of your Spark application.

## Final notes

An example code of the full Python code can be found on <a href="https://github.com/thomhopmans/themarketingtechnologist" target="_blank">GitHub</a>. Note that my expertise is not building high-performance data pipelines and that the above code therefore probably could be improved in several ways. My interest comes from quickly (read: lazily) deploying and scaling up our models to provide new and better insights for our clients. If you have any tips to make this easier, please leave them in the comments. :)

**Tip:** Note that in this example we defined the cluster to terminate after all steps are completed. However, when developing a Spark application we often want the cluster to wait for more steps. This however introduces the risk of high unexpected AWS charges if we forget to terminate the cluster. Therefore, we always add <a href="https://github.com/Yelp/mrjob/blob/master/mrjob/bootstrap/terminate_idle_cluster_emr.sh" target="_blank">`terminate_idle_cluster_emr.sh`</a> as a bootstrap action when starting the cluster. This small script is developed by `MRjob` and terminates a cluster after a specified period of inactivity, better to be safe than sorry!
