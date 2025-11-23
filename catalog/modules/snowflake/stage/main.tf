resource "time_sleep" "wait_30s_for_iam_propagation" {
  create_duration = "30s"
}

resource "snowflake_stage" "stage" {
  name                = upper(var.name)
  url                 = var.url
  database            = var.database
  schema              = var.schema
  storage_integration = var.storage_integration
  directory           = "ENABLE = true, AUTO_REFRESH = true, REFRESH_ON_CREATE = true"

  depends_on = [time_sleep.wait_30s_for_iam_propagation]
}