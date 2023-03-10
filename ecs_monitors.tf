locals {
    ecs = {
        notify_emails = ["@support@domain.com","@theman@domain.com"]
        list_of_environments = ["development", "production"]
        list_of_ecs_services = ["app", "website", "api"]
        map_of_monitor_types = {
            cpuutilization = {
                name = "cpuutilization",
                critical_level = "80",
                warning_level = "70"
            },
            memory_utilization = {
                name = "memory_utilization",
                critical_level = "85",
                warning_level = "75"
            }
        }
        list_of_regions = ["eu-central-1", "us-east-1"]
        aws_service = "ECS"
    }

    all_ecs_monitor_data = distinct(flatten([
        for env in local.ecs.list_of_ecs_services : [
            for service in local.ecs.list_of_environments : [
                for type in local.ecs.map_of_monitor_types : [
                    for region in local.ecs.list_of_regions : {
                            type = type.name
                            name = "${service} ${type.name} ${env} ${region}"
                            env = env
                            service = service
                            region = region
                            warning_level = type.warning_level
                            critical_level = type.critical_level
                            tags = ["env:${env}", "region:${region}", "service:${local.ecs.aws_service}", "name:${service}", "type:${type.name}"]
                            notify_emails = local.ecs.notify_emails
                            message = "${type.name} of ${service} too high, Notify: ${join(",", local.ecs.notify_emails)}"
                            query = "avg(last_30m):avg:aws.ecs.service.${type.name}.maximum{servicename:${service},env:${env},region:${region}} > ${type.critical_level}"
                    }
                ]
            ]
        ]
    ]))
}


resource "datadog_monitor" "ecs_monitor_automation" {
    for_each   = {
        for index, monitor in local.all_ecs_monitor_data:
        monitor.name => monitor
    }
    name        = each.value.name
    type        = "query alert"
    query       = each.value.query
    message     = each.value.message
    escalation_message = each.value.message
    monitor_thresholds {
        warning  = each.value.warning_level
        critical = each.value.critical_level
    }

    include_tags = true
    tags        = each.value.tags
}

provider "aws" {
    region = var.aws_region
    profile = var.aws_profile
}

output "test_output" {
    value = local.all_ecs_monitor_data
}

output "map_output" {
    value = local.ecs.map_of_monitor_types
}
