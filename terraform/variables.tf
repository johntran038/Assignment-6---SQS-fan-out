variable "aws_region" {
  default = "us-east-1"
}

variable "input_bucket_name" {
  type    = string
  default = "assignment6-fanout-input-bucket"
}

variable "output_bucket_name" {
  type    = string
  default = "assignment6-fanout-output-bucket"
}

variable "thumbnail_size" {
  type    = string
  default = "128x128"
}
