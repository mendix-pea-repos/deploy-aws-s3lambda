output "teraform_aws_role_output" {
 value = aws_iam_role.lambda_role.name
}

output "teraform_aws_role_arn_output" {
 value = aws_iam_role.lambda_role.arn
}

output "teraform_logging_arn_output" {
 value = aws_iam_policy.iam_policy_for_lambda.arn
}

output "terraform_aws_s3_bucketname"{
 value = aws_s3_bucket.mx_s3bucket.bucket
}

output "terraform_aws_lambda_function"{
 value = aws_lambda_function.terraform_lambda_func.function_name
}