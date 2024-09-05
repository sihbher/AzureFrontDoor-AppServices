locals {
  tags = {
    delete      = "yes"
    Environment = "Test"
    Created     = timestamp()
  }
}
