########################################################################################################################
# RDS roles and policies                                                                                               #
########################################################################################################################
###########################################################
# RDS Enhanced Monitoring                                 #
###########################################################
data "aws_iam_policy_document" "rds_enhanced_monitoring" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_enhanced_monitoring" {
  name_prefix        = "rds-monitoring-${local.dashed_name}"
  assume_role_policy = data.aws_iam_policy_document.rds_enhanced_monitoring.json
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

###########################################################
# RDS scheduled shutdown                                  #
###########################################################
data "aws_iam_policy_document" "rds_scheduled_powercycle" {
  count = substr(local.environment, -3, -1) == "pt3" ? 1 : 0

  statement {
    actions   = ["logs:CreateLogGroup"]
    resources = ["arn:aws:logs:${local.region}:${local.aws_account}:*"]
  }

  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:${local.region}:${local.aws_account}:log-group:*"]
  }

  statement {
    actions = [
      "rds:DescribeDBInstances",
      "rds:DescribeDBClusters"
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "rds:StartDBCluster",
      "rds:StopDBCluster",
      "rds:ListTagsForResource"
    ]
    resources = [aws_rds_cluster.rds_cluster[0].arn]
  }
}

resource "aws_iam_role" "rds_scheduled_powercycle" {
  count = substr(local.environment, -3, -1) == "pt3" ? 1 : 0

  name        = "${local.dashed_name}-rds-shutdown-role"
  description = "Role for Lambda to keep RDS shut down in offline environments"

  assume_role_policy = jsonencode(
  {
    Version   = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Effect = "Allow",
      }
    ]
  }
  )

  inline_policy {
    name   = "${local.dashed_name}-rds-shutdown-policy"
    policy = data.aws_iam_policy_document.rds_scheduled_powercycle[0].json
  }
}


########################################################################################################################
# Aurora mysql          													                                           #
########################################################################################################################
resource "random_password" "rds_password" {
  length = local.rds_password_length
  special = true
  override_special = "!#$&"
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = local.rds_subnet_group_name
  subnet_ids = aws_subnet.private.*.id #[for id in aws_subnet.private.*.id.*.id: id] #Need to check the var
              #[for id in aws_subnet.private.*.id: id]

  tags = merge(
  {
    Name        = "alero-rds-${local.environment}-${local.dashed_name}-subnet-group",
    Project     = var.project,
    Environment = local.environment
  },
  var.tags
  )
}

/*
data "aws_db_cluster_snapshot" "latest_snapshot" {
  count                                 = var.dr_process ? 1 : 0
  db_instance_identifier                = aws_db_instance.prod.id #TODO: Should be investigated a little bit more.
  most_recent                           = true
}
*/

resource "aws_rds_cluster" "dr_rds_cluster" {
  count                                 = var.dr_process ? 1 : 0
  cluster_identifier      	            = local.rds_cluster_id #"${var.sub_domain}-${var.main_domain}-aurora-cluster"

  #snapshot_identifier                   = data.aws_db_cluster_snapshot.latest_snapshot.id

  engine                  	            = "aurora-mysql"
  engine_version          	            = local.rds_engine_version
  vpc_security_group_ids  	            = [aws_security_group.security_group["mysql"].id]
  engine_mode 		  	                = "provisioned"
  port			  	                    = 3306
  #source_region		  	                = local.region
  master_username         	            = "master"
  master_password         	            = random_password.rds_password.result
  db_subnet_group_name	  	            = aws_db_subnet_group.rds_subnet_group.name
  backup_retention_period               = 1
  preferred_backup_window 	            = "07:00-08:00"
  preferred_maintenance_window 	        = "mon:03:00-mon:04:00"
  storage_encrypted		                = true
  iam_database_authentication_enabled 	= false
  enabled_cloudwatch_logs_exports	    = ["error", "general", "slowquery", "audit"]
  skip_final_snapshot       	        = true
  depends_on                            = [aws_db_subnet_group.rds_subnet_group]
  deletion_protection                   = true

  tags = merge(
  {
    Name        = "${local.name}-rds",
    Project     = var.project,
    Environment = local.environment
  },
  var.tags
  )
}

resource "aws_rds_cluster" "rds_cluster" {
  count                                 = var.dr_process ? 0 : 1
  cluster_identifier      	            = local.rds_cluster_id #"${var.sub_domain}-${var.main_domain}-aurora-cluster"
  engine                  	            = "aurora-mysql"
  engine_version          	            = local.rds_engine_version
  vpc_security_group_ids  	            = [aws_security_group.security_group["mysql"].id]
  engine_mode 		  	                = "provisioned"
  port			  	                    = 3306
  #source_region		  	                = local.region
  master_username         	            = "master"
  master_password         	            = random_password.rds_password.result
  db_subnet_group_name	  	            = aws_db_subnet_group.rds_subnet_group.name
  backup_retention_period               = local.rds_backup_retention
  preferred_backup_window 	            = "07:00-08:00"
  preferred_maintenance_window 	        = "mon:03:00-mon:04:00"
  storage_encrypted		                = true
  iam_database_authentication_enabled 	= false
  enabled_cloudwatch_logs_exports	    = ["error", "general", "slowquery", "audit"]
  skip_final_snapshot       	        = true
  depends_on                            = [aws_db_subnet_group.rds_subnet_group]
  deletion_protection                   = true

  tags = merge(
  {
    Name        = "${local.name}-rds",
    Project     = var.project,
    Environment = local.environment
  },
  var.tags
  )
}

locals {
  alero_rds_cluster = try(aws_rds_cluster.rds_cluster[0].id, aws_rds_cluster.dr_rds_cluster[0].id)
}

resource "aws_rds_cluster_instance" "cluster_instances" {
  for_each = toset(local.rds_instances)

  identifier                 = each.key
  cluster_identifier         = local.alero_rds_cluster
  instance_class             = local.rds_instance_class
  engine	                 = "aurora-mysql"
  monitoring_interval        = "30"
  monitoring_role_arn        = aws_iam_role.rds_enhanced_monitoring.arn
  auto_minor_version_upgrade = false

  tags = merge(
  {
    Name        = "${local.name}-rds",
    Project     = var.project,
    Environment = local.environment
  },
  var.tags
  )
}

########################################################################################################################
# Upload passwords to Secrets Manager                                                                                  #
########################################################################################################################
#Store RDS passwords in Secrets Manager for use by PVWA Ansible scripts
resource "aws_secretsmanager_secret" "rds_secret" {
  count                   = var.dr_process ? 0 : 1
  name                    = "${local.dashed_name}/RDS/rds_master_pass"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "rds_secret" {
  count         = var.dr_process ? 0 : 1
  secret_id     = aws_secretsmanager_secret.rds_secret[0].id
  secret_string = aws_rds_cluster.rds_cluster[0].master_password
}

#Store RDS password in Secrets Manager for use by PVWA Ansible scripts
resource "aws_secretsmanager_secret" "dr_rds_secret" {
  count                   = var.dr_process ? 1 : 0
  name                    = "${local.dashed_name}/RDS/dr_rds_master_pass"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "dr_rds_secret" {
  count         = var.dr_process ? 1 : 0
  secret_id     = aws_secretsmanager_secret.dr_rds_secret[0].id
  secret_string = aws_rds_cluster.dr_rds_cluster[0].master_password
}


########################################################################################################################
# RDS scheduled weekly shutdown Lambda and EventBridge                                                                 #
########################################################################################################################
resource "aws_lambda_function" "rds_scheduled_powercycle" {
  count = substr(local.environment, -3, -1) == "pt3" ? 1 : 0

  function_name    = "${local.dashed_name}-RDS-Scheduled-Powercycle"
  handler          = "rdsScheduledPowercycle.lambda_handler"
  role             = aws_iam_role.rds_scheduled_powercycle[0].arn
  runtime          = "python3.9"
  filename         = "${path.root}/lambdas/rdsScheduledPowercycle.zip"
  source_code_hash = filebase64sha256("${path.root}/lambdas/rdsScheduledPowercycle.zip")
  timeout          = 60

  tags = merge(
  var.tags,
  {
    Project       = var.project,
    Environment   = local.environment,
  },
  )
}

module "rds_scheduled_startup" {
  source = "./modules/eventbridge_to_lambda"
  count  = substr(local.environment, -3, -1) == "pt3" ? 1 : 0

  event_rule_name        = "${local.dashed_name}-RDS-Scheduled-Startup-rule"
  event_rule_description = "Rule to temporarily start RDS clusters in environments that will remain offline"
  event_rule_schedule    = "cron(00 21 ? * SAT *)"
  target_lambda_arn      = aws_lambda_function.rds_scheduled_powercycle[0].arn
  target_lambda_name     = aws_lambda_function.rds_scheduled_powercycle[0].function_name
  target_lambda_input    = jsonencode(
    {
      REGION       = local.region,
      CLUSTER_NAME = aws_rds_cluster.rds_cluster[0].id,
      ACTION       = "start"
    }
  )
}

module "rds_scheduled_shutdown" {
  source = "./modules/eventbridge_to_lambda"
  count  = substr(local.environment, -3, -1) == "pt3" ? 1 : 0

  event_rule_name        = "${local.dashed_name}-RDS-Scheduled-Shutdown-rule"
  event_rule_description = "Rule to stop RDS clusters in environments that will remain offline"
  event_rule_schedule    = "cron(00 23 ? * SAT *)"
  target_lambda_arn      = aws_lambda_function.rds_scheduled_powercycle[0].arn
  target_lambda_name     = aws_lambda_function.rds_scheduled_powercycle[0].function_name
  target_lambda_input    = jsonencode(
    {
    REGION       = local.region,
    CLUSTER_NAME = aws_rds_cluster.rds_cluster[0].id,
    ACTION       = "stop"
    }
  )
}
