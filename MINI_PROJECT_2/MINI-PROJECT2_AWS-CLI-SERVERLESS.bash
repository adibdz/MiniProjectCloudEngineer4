#!/usr/bin/env bash

AWSLOCAL="aws --endpoint-url=http://localhost:4566 --profile localstack"

P() {
  printf "[+] %s: %s\n" "$1" "$2"
  sleep 1
}

zipFunction() {
    zip hello_world.zip hello_world.py > /dev/null 2>&1
    P "ZIP" "CREATED"
}

IAMRoleLambda() {
    LAMBDA_ROLE=$($AWSLOCAL iam create-role \
      --role-name lambda-execution-role \
      --assume-role-policy-document '{
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Principal": { "Service": "lambda.amazonaws.com" },
                "Action": "sts:AssumeRole"
            }]
        }' \
      --query 'Role.Arn' --output text)
    P "(iam) IAM Role Lambda ARN:" "$LAMBDA_ROLE"
}

createLambdaFunction() {
    LAMBDA_ARN=$($AWSLOCAL lambda create-function \
      --function-name hello-world \
      --runtime python3.13 \
      --handler hello_world.handler \
      --role $LAMBDA_ROLE \
      --zip-file fileb://hello_world.zip \
      --query 'FunctionArn' --output text)
    P "(lambda) Lambda ARN:" "$LAMBDA_ARN"
}

waitLambdaFunction() {
    echo -n "[+] (lambda) Waiting Lambda Function to be active: "
    $AWSLOCAL lambda wait function-active-v2 --function-name hello-world
    echo "D O N E  !!"
    sleep 1
}

createApiGateway() {
    API_ID=$($AWSLOCAL apigateway create-rest-api \
      --name hello-api \
      --query 'id' --output text)
    P "(apigateway) API ID" "$API_ID"

    ROOT_ID=$($AWSLOCAL apigateway get-resources \
      --rest-api-id $API_ID \
      --query 'items[0].id' --output text)
    P "(apigateway) Root resource ID:" "$ROOT_ID"
}

createResourceAndMethod() {
    RESOURCE_ID=$($AWSLOCAL apigateway create-resource \
      --rest-api-id $API_ID \
      --parent-id $ROOT_ID \
      --path-part hello \
      --query 'id' --output text)
    P "(apigateway) Resource ID:" "$RESOURCE_ID"

    $AWSLOCAL apigateway put-method \
      --rest-api-id $API_ID \
      --resource-id $RESOURCE_ID \
      --http-method GET \
      --authorization-type NONE > /dev/null 2>&1
    P "(apigateway) HTTP Method" "GET Created"
}

connectApiGatewayToLambda() {
    ACCOUNT_ID=$($AWSLOCAL sts get-caller-identity --query Account --output text)
    $AWSLOCAL apigateway put-integration \
      --rest-api-id $API_ID \
      --resource-id $RESOURCE_ID \
      --http-method GET \
      --type AWS_PROXY \
      --integration-http-method POST \
      --uri "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:${ACCOUNT_ID}:function:hello-world/invocations" > /dev/null 2>&1
    P "(apigateway) API Gateway to Lambda Integration" "Created"
}

deployApiGateway() {
    $AWSLOCAL apigateway create-deployment \
      --rest-api-id $API_ID \
      --stage-name dev > /dev/null 2>&1
    P "(apigateway) Deployment Stage (dev)" "Created"
}

testURL() {
    P "Your URL" "http://localhost:4566/restapis/$API_ID/dev/_user_request_/hello"
    RES=$(curl -s -X GET "http://localhost:4566/restapis/$API_ID/dev/_user_request_/hello?name=Muhammad%20Adib%20Dzulfikar")
    P "CURL URL Response" "$RES"
}

zipFunction
IAMRoleLambda
createLambdaFunction
waitLambdaFunction
createApiGateway
createResourceAndMethod
connectApiGatewayToLambda
deployApiGateway
testURL