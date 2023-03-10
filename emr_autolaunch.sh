#!/bin/bash
aws emr create-cluster \
 --release-label emr-6.9.0 \
 --instance-groups=file://instance_groups.json \
 --use-default-roles \
 --applications=file://applications.json \
 --ec2-attributes KeyName=keypair,SubnetId=subnet,EmrManagedMasterSecurityGroup=sg,EmrManagedSlaveSecurityGroup=sg \
 --termination-protected \
 --configurations=file://hive_ldap.json \
 --name EMR-auto \
 --managed-scaling-policy ComputeLimits='{MinimumCapacityUnits=2,MaximumCapacityUnits=4,UnitType=Instances}' \
 --log-uri s3://LOG_BUCKET \
 --bootstrap-actions Path=s3://LOG_BUCKET/preinit.sh,Name=init \
 --ebs-root-volume-size 30
