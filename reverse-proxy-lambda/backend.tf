terraform {
  cloud {
    organization = "mr-gav-meow"

    workspaces {
      name = "reverse-proxy-lambda"
    }
  }
}
