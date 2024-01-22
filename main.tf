provider "aws" {
  region     = "us-west-2"
}

resource "random_string" "randomString" {
  length  = 4
  upper   = false
  lower   = true
  special = false
}

resource "aws_iam_role" "lambda_role" {
 name   = "terraform_aws_lambda_role-${random_string.randomString.result}"
 assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# IAM policy for logging from a lambda

resource "aws_iam_policy" "iam_policy_for_lambda" {

  name         = "aws_iam_policy_for_terraform_aws_lambda_role-${random_string.randomString.result}"
  path         = "/"
  description  = "AWS IAM Policy for managing aws lambda role"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "s3:*",
        "s3-object-lambda:*"
      ],
      "Resource": "*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

# Policy Attachment on the role.

resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
  role        = aws_iam_role.lambda_role.name
  policy_arn  = aws_iam_policy.iam_policy_for_lambda.arn
}

# Generates an archive from content, a file, or a directory of files.

data "archive_file" "zip_the_python_code" {
 type        = "zip"
 source_dir  = "${path.module}/python/"
 output_path = "${path.module}/python/pyAnalyticsFunc.zip"
}


resource "aws_lambda_layer_version" "lambda_layer" {
  filename   = "${path.module}/layer/python.zip"
  layer_name = "panda_layer-${random_string.randomString.result}"

  compatible_runtimes = ["python3.10"]
}

# Create a lambda function
# In terraform ${path.module} is the current directory.
resource "aws_lambda_function" "terraform_lambda_func" {
 filename                       = "${path.module}/python/pyAnalyticsFunc.zip"
 function_name                  = "tfpea-LambdaAnalytic-${random_string.randomString.result}"
 role                           = aws_iam_role.lambda_role.arn
 handler                        = "pyAnalyticsFunc.lambda_handler"
 runtime                        = "python3.10"
 timeout                        = 30
 depends_on                     = [aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role]
 layers                         = [aws_lambda_layer_version.lambda_layer.arn]
}


resource "aws_s3_bucket" "mx_s3bucket" {
    bucket = "tfpea-s3bucket-${random_string.randomString.result}"

}

resource "aws_s3_bucket_ownership_controls" "mx_s3bucketcontrols" {
  bucket = aws_s3_bucket.mx_s3bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "mx_s3bucketblock" {
  bucket = aws_s3_bucket.mx_s3bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}


resource "aws_s3_bucket_acl" "mx_s3bucketacl"{
     depends_on = [
    aws_s3_bucket_ownership_controls.mx_s3bucketcontrols,
    aws_s3_bucket_public_access_block.mx_s3bucketblock,
  ]
    bucket = aws_s3_bucket.mx_s3bucket.id
    acl = "public-read"
}



resource "aws_s3_object" "object1" {
    for_each = fileset("upload/", "*")
    bucket = aws_s3_bucket.mx_s3bucket.id
    key = each.value
    source = "upload/${each.value}"
    etag = filemd5("upload/${each.value}")
}

resource "aws_s3_bucket_policy" "mx_s3bucketpolicy"{
  bucket = aws_s3_bucket.mx_s3bucket.id
  policy = <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::tfpea-s3bucket-${random_string.randomString.result}/*"
        }
    ]
}
EOF
depends_on = [ aws_s3_bucket_public_access_block.mx_s3bucketblock ]
}

