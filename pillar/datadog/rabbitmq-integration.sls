{% set minion_id = salt.grains.get('id', '') %}
{% set rabbitmq_creds = salt.vault.cached_read('rabbitmq-{env}/creds/datadog'.format(env=salt.grains.get('environment')), cache_prefix=minion_id, ignore_invalid=True) %}

{% if rabbitmq_creds %}
datadog_user: {{ rabbitmq_creds.data.username }}
datadog_pass: {{ rabbitmq_creds.data.password }}
datadog:
  integrations:
    rabbitmq:
      settings:
        instances:
          - rabbitmq_api_url: http://localhost:15672/api
            rabbitmq_user: {{ rabbitmq_creds.data.username }}
            rabbitmq_pass: {{ rabbitmq_creds.data.password }}
{% endif %}
