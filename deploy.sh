#!/bin/bash
# Voice Flow - One-command deploy script
# Run this from your Mac/laptop where you have AWS credentials

set -e
cd "$(dirname "$0")"

echo "=== Voice Flow Deploy ==="
echo ""

# Step 1: Check prerequisites
echo "Checking prerequisites..."

if ! command -v sam &> /dev/null && ! python3 -m samcli --version &> /dev/null 2>&1; then
    echo "ERROR: SAM CLI not found. Install: pip install aws-sam-cli"
    exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
    echo "ERROR: No AWS credentials. Run:"
    echo "  ada credentials update --account YOUR_ACCOUNT_ID --role YOUR_ROLE --provider conduit"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "  AWS Account: $ACCOUNT_ID"
echo "  Region: us-west-2"
echo ""

# Step 2: Build backend
echo "Building Lambda backend..."
cd mobile/backend
sam build --use-container
echo ""

# Step 3: Deploy
echo "Deploying to AWS..."
sam deploy \
    --stack-name voice-flow-backend \
    --capabilities CAPABILITY_IAM \
    --region us-west-2 \
    --resolve-s3 \
    --no-confirm-changeset \
    --no-fail-on-empty-changeset

# Step 4: Get API endpoint
API_URL=$(aws cloudformation describe-stacks \
    --stack-name voice-flow-backend \
    --region us-west-2 \
    --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
    --output text)

echo ""
echo "=== Deploy Complete ==="
echo ""
echo "API Endpoint: $API_URL"
echo ""
echo "Next steps:"
echo "  1. Update mobile apps with your API endpoint:"
echo "     - ios/VoiceFlow/VoiceRecorder.swift"
echo "     - ios/VoiceFlowKeyboard/KeyboardViewController.swift"
echo "     - android/app/src/main/kotlin/com/voiceflow/VoiceFlowApi.kt"
echo ""
echo "  2. Test desktop:"
echo "     ./run.sh"
echo ""
echo "  3. Build mobile apps in Xcode / Android Studio"
