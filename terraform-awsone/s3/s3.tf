# #############################################################################
# Create S3 bucket
# #############################################################################
resource "random_string" "random_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "playground_awsone" {
   bucket = "playground-awsone-${random_string.random_suffix.result}"
}

resource "aws_s3_bucket_ownership_controls" "playground_awsone" {
  bucket = aws_s3_bucket.playground_awsone.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}
