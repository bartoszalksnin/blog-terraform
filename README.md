# blog-terraform

1. Create a bucket for the terraform state

aws s3api create-bucket --bucket bartosz.tech.terraform --region eu-west-2 --create-bucket-configuration LocationConstraint=eu-west-2
# Update to include public access block

# todo sort out initial iam setup
