elastic_stack:
  beats:
    metricbeat:
      config:
        metricbeat.config.modules:
          path: /etc/metricbeat/modules.d/*.yml
          reload.enabled: true
          reload.period: 30s
        name: {{ grains['id'] }}
        tags:
          - {{ grains['id'] }}
          - {{ grains.get('environment') }}
          - {{ grains.get('roles')|join(',') }}
          - {{ grains.get('osfullname') }}
        processors:
          - add_cloud_metadata: ~
          - add_host_metadata: ~
        output.elasticsearch:
          hosts:
            - http://elasticsearch.service.operations.consul:9200
          compression_level: 3
      modules:
        system:
          - module: system
            metricsets:
              - cpu
              - filesystem
              - load
              - memory
              - network
              - process
              - process_summary
              - uptime
            enabled: 'true'
            period: 1s
            processes:
              - '.*'
