locals {
  zone_count = length(data.aws_availability_zones.current.zone_ids)
  zone_names = var.aws_availability_zones_names != null ? var.aws_availability_zones_names : data.aws_availability_zones.current.names
}
