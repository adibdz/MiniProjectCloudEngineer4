#!/usr/bin/env bash

P() {
  printf "[+] %s: %s\n" "$1" "$2"
  sleep 1
}

# ROOT (localstack profile):
#   creates IAM infrastructure
#   groups, policies, attachments
#   > only root can bootstrap IAM from scratch

# INFRA-ENGINEER profile:
#   uses the permissions granted by root
#   creates VPC, EC2, subnets etc via Terraform
#   > never touches IAM setup itself

AWSLOCAL="aws --endpoint-url=http://localhost:4566 --profile infra-engineer"
AWSROOT="aws --endpoint-url=http://localhost:4566 --profile localstack"
MY_REGION="us-east-1"

createUser() {
# ─────────────────────────────────────────────
# Creating user
# ─────────────────────────────────────────────
    $AWSROOT iam create-user --user-name infra-engineer > /dev/null 2>&1
    P "Created user:" "infra-engineer"
}

createUserAccessKey() {
# ─────────────────────────────────────────────
# Creating new user access & secret key
# ─────────────────────────────────────────────
    $AWSROOT iam create-access-key --user-name infra-engineer --output json > /tmp/infra-engineer-keys.json
    ACCESSKEYID=$(jq -r '.AccessKey.AccessKeyId' /tmp/infra-engineer-keys.json)
    SECRETACCESSKEY=$(jq -r '.AccessKey.SecretAccessKey' /tmp/infra-engineer-keys.json)
    P "Access Key" "$ACCESSKEYID"
    P "Secret Key" "$SECRETACCESSKEY"
    P "Region" "$MY_REGION"
    aws configure set aws_access_key_id "$ACCESSKEYID" --profile infra-engineer
    aws configure set aws_secret_access_key "$SECRETACCESSKEY" --profile infra-engineer
    aws configure set region "$MY_REGION" --profile infra-engineer
    rm /tmp/infra-engineer-keys.json
    NEWUSERACCOUNTID=$($AWSLOCAL sts get-caller-identity --query "Account" --output text)
    P "User infra-engineer account id:" "$NEWUSERACCOUNTID"
}

createGroups() {
# ─────────────────────────────────────────────
# Creating groups
# ─────────────────────────────────────────────
    TARGET_GROUPS=("network-admins" "ec2-admins" "lb-admins" "terraform-admins")
    for GNAME in "${TARGET_GROUPS[@]}"; do
        $AWSROOT iam create-group --group-name $GNAME > /dev/null 2>&1
        P "Created group:" "$GNAME"
    done
}

createGroupPolicy() {
# ─────────────────────────────────────────────
# NetworkAdminPolicy (same as Project 1)
# ─────────────────────────────────────────────
    $AWSROOT \
      iam create-policy \
      --policy-name NetworkAdminPolicy \
      --policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
          "Effect": "Allow",
          "Action": [
            "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:DescribeVpcs",
            "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:DescribeSubnets",
            "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway",
            "ec2:AttachInternetGateway", "ec2:DetachInternetGateway",
            "ec2:DescribeInternetGateways",
            "ec2:CreateNatGateway", "ec2:DeleteNatGateway",
            "ec2:DescribeNatGateways",
            "ec2:CreateRouteTable", "ec2:DeleteRouteTable",
            "ec2:CreateRoute", "ec2:DeleteRoute",
            "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable",
            "ec2:DescribeRouteTables",
            "ec2:AllocateAddress", "ec2:ReleaseAddress",
            "ec2:DescribeAddresses", "ec2:AssociateAddress",
            "ec2:DisassociateAddress",
            "ec2:CreateTags", "ec2:DeleteTags", "ec2:DescribeTags",
            "ec2:DescribeAvailabilityZones",
            "ec2:DescribeAccountAttributes"
          ],
          "Resource": "*"
        }]
      }' > /dev/null 2>&1
    P "Created" "NetworkAdminPolicy"

    # ─────────────────────────────────────────────
    # EC2AdminPolicy (same as Project 1 + extras Terraform needs)
    # ─────────────────────────────────────────────
    $AWSROOT \
      iam create-policy \
      --policy-name EC2AdminPolicy \
      --policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
          "Effect": "Allow",
          "Action": [
            "ec2:RunInstances", "ec2:StopInstances",
            "ec2:StartInstances", "ec2:TerminateInstances",
            "ec2:DescribeInstances", "ec2:DescribeInstanceStatus",
            "ec2:DescribeInstanceAttribute",
            "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup",
            "ec2:DescribeSecurityGroups",
            "ec2:AuthorizeSecurityGroupIngress",
            "ec2:AuthorizeSecurityGroupEgress",
            "ec2:RevokeSecurityGroupIngress",
            "ec2:RevokeSecurityGroupEgress",
            "ec2:DescribeImages", "ec2:DescribeKeyPairs",
            "ec2:DescribeVpcAttribute",
            "ec2:ModifyVpcAttribute",
            "ec2:CreateTags", "ec2:DescribeTags",
            "iam:GetRole", "iam:GetInstanceProfile",
            "iam:ListRoles", "iam:ListInstanceProfiles",
            "iam:PassRole"
          ],
          "Resource": "*"
        }]
      }' > /dev/null 2>&1
    P "Created" "EC2AdminPolicy"

    # ─────────────────────────────────────────────
    # LBAdminPolicy (same as Project 1)
    # ─────────────────────────────────────────────
    $AWSROOT \
      iam create-policy \
      --policy-name LBAdminPolicy \
      --policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
          "Effect": "Allow",
          "Action": [
            "elasticloadbalancing:CreateLoadBalancer",
            "elasticloadbalancing:DeleteLoadBalancer",
            "elasticloadbalancing:DescribeLoadBalancers",
            "elasticloadbalancing:CreateTargetGroup",
            "elasticloadbalancing:DeleteTargetGroup",
            "elasticloadbalancing:DescribeTargetGroups",
            "elasticloadbalancing:RegisterTargets",
            "elasticloadbalancing:DeregisterTargets",
            "elasticloadbalancing:DescribeTargetHealth",
            "elasticloadbalancing:CreateListener",
            "elasticloadbalancing:DeleteListener",
            "elasticloadbalancing:DescribeListeners",
            "elasticloadbalancing:ModifyLoadBalancerAttributes",
            "elasticloadbalancing:DescribeLoadBalancerAttributes"
          ],
          "Resource": "*"
        }]
      }' > /dev/null 2>&1
      P "Created" "LBAdminPolicy"

    # ─────────────────────────────────────────────
    # TerraformStatePolicy (NEW — Terraform specific)
    # ─────────────────────────────────────────────
    $AWSROOT \
      iam create-policy \
      --policy-name TerraformStatePolicy \
      --policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
          "Effect": "Allow",
          "Action": [
            "iam:CreateRole", "iam:DeleteRole",
            "iam:GetRole", "iam:ListRoles",
            "iam:CreateUser", "iam:DeleteUser",
            "iam:GetUser", "iam:ListUsers",
            "iam:CreateGroup", "iam:DeleteGroup",
            "iam:GetGroup", "iam:ListGroups",
            "iam:CreatePolicy", "iam:DeletePolicy",
            "iam:GetPolicy", "iam:ListPolicies",
            "iam:AttachGroupPolicy", "iam:DetachGroupPolicy",
            "iam:AttachRolePolicy", "iam:DetachRolePolicy",
            "iam:ListAttachedGroupPolicies",
            "iam:ListAttachedRolePolicies",
            "iam:CreateInstanceProfile",
            "iam:DeleteInstanceProfile",
            "iam:GetInstanceProfile",
            "iam:AddRoleToInstanceProfile",
            "iam:RemoveRoleFromInstanceProfile",
            "iam:PassRole",
            "sts:GetCallerIdentity",
            "sts:AssumeRole"
          ],
          "Resource": "*"
        }]
      }' > /dev/null 2>&1
    P "Created" "TerraformStatePolicy"
}

atatchPolicytoGroups() {
# ─────────────────────────────────────────────
# Attach policies to groups
# ─────────────────────────────────────────────
    ROOTACCOUNTID=$($AWSROOT sts get-caller-identity --query "Account" --output text)
    P "Root account id:" "$ROOTACCOUNTID"

    # --policy-arn: it tells AWS exactly which policy to grab from its giant library.
    $AWSROOT \
      iam attach-group-policy \
      --group-name network-admins \
      --policy-arn arn:aws:iam::$ROOTACCOUNTID:policy/NetworkAdminPolicy
    P "network-admins" "← NetworkAdminPolicy"

    $AWSROOT \
      iam attach-group-policy \
      --group-name ec2-admins \
      --policy-arn arn:aws:iam::$ROOTACCOUNTID:policy/EC2AdminPolicy
    P "ec2-admins" "← EC2AdminPolicy"

    $AWSROOT \
      iam attach-group-policy \
      --group-name lb-admins \
      --policy-arn arn:aws:iam::$ROOTACCOUNTID:policy/LBAdminPolicy
    P "lb-admins" "← LBAdminPolicy"

    $AWSROOT \
      iam attach-group-policy \
      --group-name terraform-admins \
      --policy-arn arn:aws:iam::$ROOTACCOUNTID:policy/TerraformStatePolicy
    P "terraform-admins" "← TerraformStatePolicy"
}

addUserToGroups() {
# ─────────────────────────────────────────────
# Add infra-engineer to ALL groups
# ─────────────────────────────────────────────
  for GROUP in network-admins ec2-admins lb-admins terraform-admins; do
    $AWSROOT \
      iam add-user-to-group \
      --user-name infra-engineer \
      --group-name $GROUP
    P "infra-engineer" "→ $GROUP"
  done
}

verfyAll() {
# ─────────────────────────────────────────────
# Verify
# ─────────────────────────────────────────────
    echo ""
    echo "=== VERIFY: groups infra-engineer belongs to ==="
    $AWSROOT \
      iam list-groups-for-user \
      --user-name infra-engineer \
      --query 'Groups[].GroupName' \
      --output table

    echo ""
    echo "=== VERIFY: policies attached to each group ==="
    for GROUP in network-admins ec2-admins lb-admins terraform-admins; do
      echo "--- $GROUP ---"
      $AWSROOT \
        iam list-attached-group-policies \
        --group-name $GROUP \
        --query 'AttachedPolicies[].PolicyName' \
        --output table
    done
}

createUser
createUserAccessKey
createGroups
createGroupPolicy
atatchPolicytoGroups
addUserToGroups
verfyAll