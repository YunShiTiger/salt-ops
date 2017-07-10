{% set VPC_NAME = 'micromasters' %}
{% set VPC_RESOURCE_SUFFIX = VPC_NAME.lower() | replace(' ', '-') %}
{% set VPC_NET_PREFIX = '10.10' %}
{% set ENVIRONMENT = 'micromasters' %}
{% set subnet_ids = [] %}
{% for subnet in salt.boto_vpc.describe_subnets(subnet_names=[
    'public1-{}'.format(VPC_RESOURCE_SUFFIX), 'public2-{}'.format(VPC_RESOURCE_SUFFIX), 'public3-{}'.format(VPC_RESOURCE_SUFFIX)])['subnets'] %}
{% do subnet_ids.append('{0}'.format(subnet['id'])) %}
{% endfor %}

load_elasticsearch_cloud_profile:
  file.managed:
    - name: /etc/salt/cloud.profiles.d/elasticsearch.conf
    - source: salt://orchestrate/aws/cloud_profiles/elasticsearch.conf

generate_elasticsearch_cloud_map_file:
  file.managed:
    - name: /etc/salt/cloud.maps.d/{{ ENVIRONMENT }}_elasticsearch_map.yml
    - source: salt://orchestrate/aws/map_templates/elasticsearch.yml
    - template: jinja
    - makedirs: True
    - context:
        environment_name: {{ ENVIRONMENT }}
        roles:
          - elasticsearch
        securitygroupid:
          - {{ salt.boto_secgroup.get_group_id(
            'elasticsearch-{}'.format(VPC_RESOURCE_SUFFIX),
            vpc_name=VPC_NAME) }}
          - {{ salt.boto_secgroup.get_group_id(
            'salt_master-{}'.format(VPC_RESOURCE_SUFFIX),
            vpc_name=VPC_NAME) }}
        subnetids: {{ subnet_ids }}
        volume_size: 200
        tags:
          escluster: {{ ENVIRONMENT }}
    - require:
        - file: load_elasticsearch_cloud_profile

deploy_elasticsearch_nodes:
  salt.runner:
    - name: cloud.map_run
    - path: /etc/salt/cloud.maps.d/{{ ENVIRONMENT }}_elasticsearch_map.yml
    - parallel: True
    - require:
        - file: generate_elasticsearch_cloud_map_file

load_pillar_data_on_{{ ENVIRONMENT }}_elasticsearch_nodes:
  salt.function:
    - name: saltutil.refresh_pillar
    - tgt: 'G@roles:elasticsearch and G@environment:{{ ENVIRONMENT }}'
    - tgt_type: compound
    - require:
        - salt: deploy_elasticsearch_nodes

populate_mine_with_{{ ENVIRONMENT }}_elasticsearch_data:
  salt.function:
    - name: mine.update
    - tgt: 'G@roles:elasticsearch and G@environment:{{ ENVIRONMENT }}'
    - tgt_type: compound
    - require:
        - salt: load_pillar_data_on_{{ ENVIRONMENT }}_elasticsearch_nodes

build_{{ ENVIRONMENT }}_elasticsearch_nodes:
  salt.state:
    - tgt: 'G@roles:elasticsearch and G@environment:{{ ENVIRONMENT }}'
    - tgt_type: compound
    - highstate: True
    - require:
        - salt: deploy_elasticsearch_nodes
