#!/bin/bash

# AWS EKS Cluster Setup Script
# Make sure AWS CLI and kubectl are configured with appropriate permissions

# Variables
CLUSTER_NAME="brain-tasks-cluster"
REGION="us-east-1"
NODE_GROUP_NAME="brain-tasks-nodes"
NODE_TYPE="t3.medium"
DESIRED_NODES=2
MIN_NODES=1
MAX_NODES=3

echo "Setting up EKS cluster: ${CLUSTER_NAME}..."

# Create EKS cluster
aws eks create-cluster \
    --name ${CLUSTER_NAME} \
    --region ${REGION} \
    --kubernetes-version 1.29 \
    --role-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/EKSClusterRole \
    --resources-vpc-config subnetIds=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=*subnet* --query 'Subnets[0:2].SubnetId' --output text | tr '\t' ','),securityGroupIds=$(aws ec2 describe-security-groups --filters Name=group-name,Values=*default* --query 'SecurityGroups[0].GroupId' --output text) \
    || echo "Cluster may already exist or needs VPC configuration"

# Wait for cluster to be active
echo "Waiting for cluster to become active..."
aws eks wait cluster-active --name ${CLUSTER_NAME} --region ${REGION}

# Create node group
aws eks create-nodegroup \
    --cluster-name ${CLUSTER_NAME} \
    --nodegroup-name ${NODE_GROUP_NAME} \
    --region ${REGION} \
    --scaling-config desiredSize=${DESIRED_NODES},minSize=${MIN_NODES},maxSize=${MAX_NODES} \
    --subnets $(aws ec2 describe-subnets --filters Name=tag:Name,Values=*subnet* --query 'Subnets[0:2].SubnetId' --output text | tr '\t' ',') \
    --instance-types ${NODE_TYPE} \
    --ami-type AL2_x86_64 \
    --node-role arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/EKSNodeRole \
    || echo "Node group may already exist"

# Wait for node group to be active
echo "Waiting for node group to become active..."
aws eks wait nodegroup-active --cluster-name ${CLUSTER_NAME} --nodegroup-name ${NODE_GROUP_NAME} --region ${REGION}

# Update kubeconfig
aws eks update-kubeconfig --region ${REGION} --name ${CLUSTER_NAME}

# Verify cluster is running
kubectl get nodes
kubectl get services

echo "EKS cluster setup complete!"
echo "Cluster name: ${CLUSTER_NAME}"
echo "Region: ${REGION}"
