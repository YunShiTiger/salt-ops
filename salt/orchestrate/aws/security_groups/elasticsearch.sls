{% set VPC_NAME = salt.environ.get('VPC_NAME', 'MITx QA') %}
{% set VPC_RESOURCE_SUFFIX = salt.environ.get(
    'VPC_RESOURCE_SUFFIX',
    VPC_NAME.lower().replace(' ', '-')) %}
{% set ENVIRONMENT = salt.environ.get(
    'ENVIRONMENT',
    VPC_NAME.lower().replace(' ', '-')) %}
{% set BUSINESS_UNIT = salt.environ.get('BUSINESS_UNIT', 'residential') %}
{% set VPC_RESOURCE_SUFFIX_UNDERSCORE = VPC_RESOURCE_SUFFIX.replace('-', '_') %}
{% set app_name = salt.environ.get('APP_NAME', 'edx') %}
{% set env_settings = salt.pillar.get('environments:{}'.format(ENVIRONMENT)) %}
{% set network_prefix = env_settings.network_prefix %}
{% set cidr_block_public_subnet_1 = '{}.1.0/24'.format(network_prefix) %}
{% set cidr_block_public_subnet_2 = '{}.2.0/24'.format(network_prefix) %}
{% set cidr_block_public_subnet_3 = '{}.3.0/24'.format(network_prefix) %}
{% set cidr_ip = '{}.0.0/22'.format(network_prefix) %}
{% set cidr_block = '{}.0.0/16'.format(network_prefix) %}


create_elasticsearch_security_group_in_{{ VPC_NAME }}:
  boto_secgroup.present:
    - name: elasticsearch-{{ VPC_RESOURCE_SUFFIX }}
    - vpc_name: {{ VPC_NAME }}
    - description: ACL for elasticsearch servers
    - rules:
        - ip_protocol: tcp
          from_port: 9200
          to_port: 9200
          source_group_name: {{ app_name }}-{{ VPC_RESOURCE_SUFFIX }}
        - ip_protocol: tcp
          from_port: 9300
          to_port: 9400
          source_group_name: elasticsearch-{{ VPC_RESOURCE_SUFFIX }}
    - require:
        - boto_vpc: create_{{ VPC_RESOURCE_SUFFIX_UNDERSCORE }}_vpc
        - boto_secgroup: create_{{ app_name }}_security_group_in_{{ VPC_NAME }}
    - tags:
        Name: elasticsearch-{{ VPC_RESOURCE_SUFFIX }}
        business_unit: {{ BUSINESS_UNIT }}
