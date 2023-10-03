terraform {
  required_providers {
    ciscomcd = {
      source = "CiscoDevNet/ciscomcd"
    }
  }
}

provider "ciscomcd" {
    api_key_file = file(var.mcd_api_key_file)
}
