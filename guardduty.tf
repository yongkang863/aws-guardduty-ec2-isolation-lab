# Enable GuardDuty
resource "aws_guardduty_detector" "primary" {
  enable = true
}

# Package Lambda Script into a .zip file automatically
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/isolate_ec2.py"
  output_path = "${path.module}/lambda/isolate_ec2.zip"
}

# Create Lambda Function
resource "aws_lambda_function" "isolate_ec2" {
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "SecurityLab-Isolate-EC2"
  role          = aws_iam_role.lambda_isolation_role.arn
  handler       = "isolate_ec2.lambda_handler"
  runtime       = "python3.9"
  # Allow time for boto3 initialization and the EC2 API request.
  timeout          = 30
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  # Pass the Quarantine SG ID to Python securely
  environment {
    variables = {
      QUARANTINE_SG_ID = aws_security_group.isolated_sg.id
    }
  }
}

# EventBridge Rule (Triggers when GuardDuty spots an EC2 attack)
resource "aws_cloudwatch_event_rule" "guardduty_finding" {
  name        = "GuardDuty-EC2-Finding"
  description = "Trigger Lambda on GuardDuty findings for EC2"
  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      resource = {
        resourceType = ["Instance"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "trigger_lambda" {
  rule      = aws_cloudwatch_event_rule.guardduty_finding.name
  target_id = "TriggerLambda"
  arn       = aws_lambda_function.isolate_ec2.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.isolate_ec2.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.guardduty_finding.arn
}
