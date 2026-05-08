provider "aws" {
  region = var.aws_region
}

# s3 buckets
resource "aws_s3_bucket" "input" {
  bucket = var.input_bucket_name
}

resource "aws_s3_bucket" "output" {
  bucket = var.output_bucket_name
}

# sns topic
resource "aws_sns_topic" "topic" {
  name = "fanout-topic"
}

# sqs queue
resource "aws_sqs_queue" "queue" {
  name = "fanout-queue"
}

# sns -> sqs subscription
resource "aws_sns_topic_subscription" "sns_to_sqs" {
  topic_arn = aws_sns_topic.topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.queue.arn
}

# allow sns to send to sqs
resource "aws_sqs_queue_policy" "allow_sns" {
  queue_url = aws_sqs_queue.queue.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = "*",
      Action = "sqs:SendMessage",
      Resource = aws_sqs_queue.queue.arn,
      Condition = {
        ArnEquals = {
          "aws:SourceArn" = aws_sns_topic.topic.arn
        }
      }
    }]
  })
}

resource "aws_sns_topic_policy" "allow_s3" {
  arn = aws_sns_topic.topic.arn

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = { Service = "s3.amazonaws.com" },
        Action = "SNS:Publish",
        Resource = aws_sns_topic.topic.arn,
        Condition = {
          ArnLike = {
            "aws:SourceArn" = aws_s3_bucket.input.arn
          }
        }
      }
    ]
  })
}


# s3 -> sns event
resource "aws_s3_bucket_notification" "s3_to_sns" {
  bucket = var.input_bucket_name

  topic {
    topic_arn = aws_sns_topic.topic.arn
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [
    aws_sns_topic_policy.allow_s3
  ]
}

# iam role for lambda
resource "aws_iam_role" "lambda_role" {
  name = "fanout-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

# iam policy
resource "aws_iam_policy" "lambda_policy" {
  name = "fanout-lambda-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["logs:*"],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = ["s3:GetObject"],
        Resource = "${aws_s3_bucket.input.arn}/*"
      },
      {
        Effect = "Allow",
        Action = ["s3:PutObject"],
        Resource = "${aws_s3_bucket.output.arn}/*"
      },
      {
        Effect = "Allow",
        Action = ["sqs:*"],
        Resource = aws_sqs_queue.queue.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# lambda function
resource "aws_lambda_function" "thumbnail" {
  function_name = "fanout-thumbnail"

  role    = aws_iam_role.lambda_role.arn
  handler = "handler.lambda_handler"
  runtime = "python3.11"

  filename         = "${path.module}/../lambda_thumbnail.zip"
  source_code_hash = filebase64sha256("${path.module}/../lambda_thumbnail.zip")

  environment {
    variables = {
      OUTPUT_BUCKET  = var.output_bucket_name
      THUMBNAIL_SIZE = var.thumbnail_size
    }
  }
}

# sqs -> lambda trigger
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.queue.arn
  function_name    = aws_lambda_function.thumbnail.arn
  batch_size       = 1
}
