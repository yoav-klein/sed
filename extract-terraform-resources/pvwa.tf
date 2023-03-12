########################################################################################################################
# Kubernetes secrets in PVWA                                                                                           #
########################################################################################################################
resource "local_sensitive_file" "pvwa_vars" {
  content = yamlencode(
    {
      dashed_name                          = local.dashed_name
      aws_account_id                       = data.aws_caller_identity.current.id
      aws_account_name                     = local.aws_account_name
      region                               = local.region
      alero_environment                    = local.environment
      alero_pcloud_kms_region              = local.alero_pcloud_kms_region
      aws_hosted_zone_id                   = data.aws_route53_zone.alero.id
      rds_endpoint                         = aws_rds_cluster.rds_cluster[0].endpoint
      rds_read_endpoint                    = aws_rds_cluster.rds_cluster[0].reader_endpoint
      rds_username                         = aws_rds_cluster.rds_cluster[0].master_username
      redis_endpoint                       = aws_elasticache_replication_group.redis.primary_endpoint_address
      elasticsearch_endpoint               = aws_elasticsearch_domain.es-domain.endpoint
      elasticsearch_logging_endpoint       = aws_elasticsearch_domain.es-logging-domain.endpoint
      elasticsearch_sws_endpoint           = aws_elasticsearch_domain.es-sws-domain.endpoint
      email_sender                         = "noreply@${local.route53_domain_name}"
      ses_region                           = local.ses_region
      acme_url                             = local.acme_url
      pcloud_kms_region                    = local.pcloud_kms_region
      alero_queue_url                      = aws_sqs_queue.pcloud_queue.id
      alero_dl_queue_url                   = aws_sqs_queue.pcloud_dl_queue.id
      alero_pcloud_kms_key_arn             = local.alero_pcloud_kms_key_arn
      pcloud_alero_kms_key_arn             = local.pcloud_alero_kms_key_arn
      pcloud_role_arn                      = local.pcloud_role_arn
      alero_pcloud_role_arn                = local.alero_pcloud_role_arn
      pcloud_verification_key_arn          = local.pcloud_verification_key_arn
      alero_verification_key_arn           = local.alero_verification_key_arn
      pcloud_queue                         = local.pcloud_queue_url
      pcloud_sim_queue_url                 = local.pcloud_sim_queue_url
      pcloud_region                        = local.pcloud_region
      pcloud_bucket                        = module.pcloud_sync.bucket.id
      alero_migration_sm_role_consumer_arn = local.alero_migration_sm_role_consumer_arn
      pcloud_migration_sm_role_reader_arn  = local.pcloud_migration_sm_role_reader_arn
      sws_bucket_name                      = module.sws-recordings.bucket.id
      sqs_encryption_key_arn               = local.sqs_encryption_key_arn
      sws_events_url                       = aws_sqs_queue.sws_events_queue.id
    }
  )
  filename = "${path.root}/ansible/pvwa/pvwa_vars.yml"
}

resource "null_resource" "pvwa_create" {
  provisioner "local-exec" {
    when    = create
    command = "ansible-playbook ${path.module}/ansible/pvwa/add_secrets.yml"
  }

  depends_on = [aws_secretsmanager_secret_version.rds_secret[0], aws_secretsmanager_secret_version.redis, local_sensitive_file.pvwa_vars]
}

resource "null_resource" "pvwa_destroy" {
  triggers = {
    alero_environment = local.environment
  }

  provisioner "local-exec" {
    when = destroy
    command = "ansible-playbook ${path.module}/ansible/pvwa/delete_secrets.yml -e \"alero_environment='${self.triggers.alero_environment}'\""
  }

  depends_on = [aws_secretsmanager_secret_version.rds_secret[0], aws_secretsmanager_secret_version.redis, local_sensitive_file.pvwa_vars]
}
