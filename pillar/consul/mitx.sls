{% set ENVIRONMENT = salt.grains.get('environment') %}
{% set env_settings = salt.cp.get_file_str("salt://environment_settings.yml")|load_yaml %}
{% set env_data = env_settings.environments[ENVIRONMENT] %}

{% set mysql_endpoint = salt.boto_rds.get_endpoint('{env}-rds-mysql'.format(env=ENVIRONMENT)) %}

consul:
  extra_configs:
    defaults:
      recursors:
        - {{ env_settings.environments[ENVIRONMENT].network_prefix }}.0.2
        - 8.8.8.8
    {% if 'consul_server' in salt.grains.get('roles', []) %}
    hosted_services:
      services:
        - name: mysql
          port: {{ mysql_endpoint.split(':')[1] }}
          address: {{ mysql_endpoint.split(':')[0] }}
          check:
            tcp: '{{ mysql_endpoint }}'
            interval: 10s
        {% for cache_config in env_data.get('backends', {}).get('elasticache', []) %}
        {% if cache_config.engine == 'memcached' %}
        {% set cache_data = salt.boto3_elasticache.describe_cache_clusters(cache_config.cluster_id) %}
        {% else %}
        {% set cache_data = salt.boto3_elasticache.describe_replication_groups(cache_config.cluster_id) %}
        {% endif %}
        {% if cache_data[0].get('ConfigurationEndpoint') %}
        {% set endpoint = cache_data[0].ConfigurationEndpoint %}
        {% else %}
        {% set endpoint = cache_data[0].NodeGroups[0].PrimaryEndpoint %}
        {% endif %}
        - name: {{ cache_config.cluster_id }}
          port: {{ endpoint.Port }}
          address: {{ endpoint.Address }}
          check:
            tcp: '{{ endpoint.Address }}:{{ endpoint.Port }}'
            interval: 10s
        {% endfor %}
    {% endif %}
