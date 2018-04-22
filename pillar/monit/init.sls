{% set slack_webhook_url_devops = salt.vault.read('secret-operations/global/slack/slack_mitx_eng_alerts').data.value %}

monit_app:
  notification: 'slack'
  slack_webhook_url: {{ slack_webhook_url_devops }}
