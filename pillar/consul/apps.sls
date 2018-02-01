{# Definition of services in the rc-apps and production-apps environments #}
{% set ENVIRONMENT = salt.grains.get('environment') %}
{% set env_settings = salt.cp.get_file_str("salt://environment_settings.yml")|load_yaml %}
{% set env_data = env_settings.environments[ENVIRONMENT] %}

consul:
  extra_configs:
    defaults:
      recursors:
        - {{ env_settings.environments[ENVIRONMENT].network_prefix }}.0.2
        - 8.8.8.8
    {% if 'consul_server' in salt.grains.get('roles', []) %}
    aws_services:
      services:
        {% for dbconfig in env_data.backends.rds %}
        {% set rds_endpoint = salt.boto_rds.get_endpoint('{env}-rds-{engine}-{db}'.format(env=ENVIRONMENT, engine=dbconfig.engine, db=dbconfig.name)) %}
        - name: {{ dbconfig.engine }}-{{ dbconfig.name }}
          port: {{ rds_endpoint.split(':')[1] }}
          address: {{ rds_endpoint.split(':')[0] }}
          check:
            tcp: '{{ rds_endpoint }}'
            interval: 10s
        {% endfor %}
        {% for cache_config in env_data.backends.elasticache %}
        {% if cache_config.engine == 'memcached' %}
        {% set cache_data = salt.boto3_elasticache.describe_cache_clusters(cache_config.cluster_id) %}
        {% else %}
        {% set cache_data = salt.boto3_elasticache.describe_replication_groups(cache_config.cluster_id) %}
        {% endif %}
        - name: {{ cache_config.cluster_id }}
          port: {{ cache_data[0].ConfigurationEndpoint.Port }}
          address: {{ cache_data[0].ConfigurationEndpoint.Address }}
          check:
            tcp: '{{ cache_data[0].ConfigurationEndpoint.Address }}:{{ cache_data[0].ConfigurationEndpoint.Port }}'
            interval: 10s
        {% endfor %}
    {% endif %}
