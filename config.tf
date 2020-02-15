terraform {
  required_version = "0.12.20"

  backend "s3" {
    bucket = "watabee-static-web-site-hosting-terraform"
    key    = "root"
    region = "ap-northeast-1"
  }
}

provider "aws" {
  version = "2.49.0"
  region  = "ap-northeast-1"
}
