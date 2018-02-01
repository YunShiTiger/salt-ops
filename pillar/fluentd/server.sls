{% set micromasters_ir_bucket = 'odl-micromasters-ir-data' %}
{% set micromasters_ir_bucket_creds = salt.vault.read('aws-mitx/creds/read-write-{bucket}'.format(bucket=micromasters_ir_bucket)) %}
{% set edx_tracking_bucket = 'odl-residential-tracking-data' %}
{% set edx_tracking_bucket_creds = salt.vault.read('aws-mitx/creds/read-write-{bucket}'.format(bucket=edx_tracking_bucket)) %}
{% set fluentd_shared_key = salt.vault.read('secret-operations/global/fluentd_shared_key').data.value %}
{% set mailgun_webhooks_token = salt.vault.read('secret-operations/global/mailgun_webhooks_token').data.value %}
{% set redash_webhook_token = salt.vault.read('secret-operations/global/redash_webhook_token').data.value %}
{% set odl_wildcard_cert = salt.vault.read('secret-operations/global/odl_wildcard_cert') %}
{% import_yaml 'fluentd/fluentd_directories.yml' as fluentd_directories %}

fluentd:
  persistent_directories: {{ fluentd_directories }}
  overrides:
    nginx_config:
      server_name: log-input.odl.mit.edu
      cert_file: log-input.crt
      key_file: log-input.key
      cert_contents: |
        {{ odl_wildcard_cert.data.value|indent(8) }}
      key_contents: |
        {{ odl_wildcard_cert.data.key|indent(8) }}
  plugins:
    - fluent-plugin-s3
    - fluent-plugin-elasticsearch
  proxied_plugins:
    - route: mailgun-webhooks
      port: 9001
      token: {{ mailgun_webhooks_token }}
    - route: redash-webhook
      port: 9002
      token: {{ redash_webhook_token }}
  configs:
    - name: monitor_agent
      settings:
        - directive: source
          attrs:
            - '@type': monitor_agent
            - bind: 127.0.0.1
            - port: 24220
    - name: elasticsearch
      settings:
        - directive: source
          attrs:
            - '@id': heroku_logs_inbound
            - '@type': syslog
            - tag: heroku_logs
            - bind: 127.0.0.1
            - port: 5140
            - protocol_type: tcp
            - nested_directives:
                - directive: parse
                  attrs:
                    - message_format: rfc5424
        - directive: source
          attrs:
            - '@id': mailgun-events
            - '@type': http
            - port: 9001
            - bind: ::1
            - format: none
        - directive: source
          attrs:
            - '@id': redash-events
            - '@type': http
            - port: 9002
            - bind: ::1
            - format: json
        - directive: source
          attrs:
            - '@id': salt_logs_inbound
            - '@type': udp
            - tag: saltmaster
            - format: json
            - port: 9999
            - keep_time_key: 'true'
        - directive: source
          attrs:
            - '@id': secure_input
            - '@type': forward
            - port: 5001
            - nested_directives:
              - directive: transport
                directive_arg: tls
                attrs:
                  - cert_path: '/etc/ssl/certs/log-input.crt'
                  - private_key_path: '/etc/ssl/certs/log-input.key'
                  - private_key_passphrase: ''
        {# The purpose of this block is to stream data from the
        micromasters application to S3 for analysis by the
        institutional research team. If they ever need to change
        the way that they consume that data then this is the
        place to change it. #}
        - directive: match
          directive_arg: heroku.micromasters
          attrs:
            - '@type': copy
            - nested_directives:
                - directive: store
                  attrs:
                    - '@type': s3
                    - aws_key_id: {{ micromasters_ir_bucket_creds.data.access_key }}
                    - aws_sec_key: {{ micromasters_ir_bucket_creds.data.secret_key }}
                    - s3_bucket: {{ micromasters_ir_bucket }}
                    - s3_region: us-east-1
                    - path: logs/
                    - s3_object_key_format: '%{path}%{time_slice}_%{index}.%{file_extension}'
                    - time_slice_format: '%Y-%m-%d'
                    - nested_directives:
                      - directive: buffer
                        attrs:
                          - '@type': file
                          - path: {{ fluentd_directories.micromasters_s3_buffers }}
                          - timekey: 3600
                          - timekey_wait: '10m'
                          - timekey_use_utc: 'true'
                    - nested_directives:
                      - directive: format
                        attrs:
                          - '@type': json
                - directive: store
                  attrs:
                    - '@type': relabel
                    - '@label': '@es_logging'
        {# End IR block #}
        - directive: match
          directive_arg: edx.tracking
          attrs:
            - '@type': copy
            - nested_directives:
              - directive: store
                attrs:
                  - '@type': relabel
                  - '@label': '@prod_edx_tracking_events'
              - directive: store
                attrs:
                  - '@type': relabel
                  - '@label': '@es_logging'

        - directive: match
          directive_arg: '**'
          attrs:
            - '@type': relabel
            - '@label': '@es_logging'

        - directive: label
          directive_arg: '@es_logging'
          attrs:
            - nested_directives:
              - directive: match
                directive_arg: '**'
                attrs:
                  - '@id': es_outbound
                  - '@type': elasticsearch_dynamic
                  - logstash_format: 'true'
                  - flush_interval: '10s'
                  - hosts: elasticsearch.service.operations.consul
                  - logstash_prefix: 'logstash-${record.fetch("environment", "blank") != "blank" ? record.fetch("environment") : tag_parts[0]}'
                  - include_tag_key: 'true'
                  - tag_key: fluentd_tag
                  - reload_on_failure: 'true'
                  - reconnect_on_error: 'true'
                  - flatten_hashes: 'true'
                  - flatten_hashes_separator: __

        - directive: label
          directive_arg: '@prod_edx_tracking_events'
          attrs:
            - nested_directives:
                - directive: filter
                  directive_arg: 'edx.tracking'
                  attrs:
                    - '@type': grep
                    - nested_directives:
                      - directive: regexp
                        attrs:
                          - key: environment
                          - pattern: mitx-production
                - directive: match
                  directive_arg: edx.tracking
                  attrs:
                    - '@type': s3
                    - aws_key_id: {{ edx_tracking_bucket_creds.data.access_key }}
                    - aws_sec_key: {{ edx_tracking_bucket_creds.data.secret_key }}
                    - s3_bucket: {{ edx_tracking_bucket }}
                    - s3_region: us-east-1
                    - path: logs/
                    - s3_object_key_format: '%{path}%{time_slice}_%{index}.%{file_extension}'
                    - time_slice_format: '%Y-%m-%d'
                    - nested_directives:
                      - directive: buffer
                        attrs:
                          - '@type': file
                          - path: {{ fluentd_directories.residential_tracking_logs }}
                          - timekey: 3600
                          - timekey_wait: '10m'
                          - timekey_use_utc: 'true'
                    - nested_directives:
                      - directive: format
                        attrs:
                          - '@type': json

beacons:
  service:
    fluentd:
      onchangeonly: True
    disable_during_state_run: True
