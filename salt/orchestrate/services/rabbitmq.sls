{% set env_settings = salt.cp.get_file_str("salt://environment_settings.yml")|load_yaml %}
{% set ENVIRONMENT = salt.environ.get('ENVIRONMENT', 'rc-apps') %}
{% set env_data = env_settings.environments[ENVIRONMENT] %}
{% set VPC_NAME = env_data.vpc_name %}
{% set INSTANCE_COUNT = salt.environ.get('INSTANCE_COUNT', 3) %}
{% set BUSINESS_UNIT = salt.environ.get('BUSINESS_UNIT', env_data.business_unit) %}
{% set launch_date = salt.status.time(format="%Y-%m-%d") %}
{% set subnet_ids = salt.boto_vpc.describe_subnets(
    vpc_id=salt.boto_vpc.describe_vpcs(
        name=env_data.vpc_name).vpcs[0].id
    ).subnets|map(attribute='id')|list %}
{% set rabbitmq_admin_password = salt.vault.read('secret-{}/{}/rabbitmq-admin-password'.format(BUSINESS_UNIT, ENVIRONMENT)) %}
{% if not rabbitmq_admin_password %}
{% set rabbitmq_admin_password = salt.random.get_str(42) %}
set_rabbitmq_admin_password_in_vault:
  salt.function:
    - tgt: 'roles:master'
    - tgt_type: grain
    - name: vault.write
    - arg:
        - secret-{{ BUSINESS_UNIT }}/{{ ENVIRONMENT }}/rabbitmq-admin-password
    - kwarg:
        value: {{ rabbitmq_admin_password }}
{% else %}
{% set rabbitmq_admin_password = rabbitmq_admin_password.data.value %}
{% endif %}
{% set SIX_MONTHS = '4368h' %}

load_rabbitmq_cloud_profile:
  file.managed:
    - name: /etc/salt/cloud.profiles.d/rabbitmq.conf
    - source: salt://orchestrate/aws/cloud_profiles/rabbitmq.conf
    - template: jinja

generate_rabbitmq_cloud_map_file:
  file.managed:
    - name: /etc/salt/cloud.maps.d/{{ ENVIRONMENT }}_rabbitmq_map.yml
    - source: salt://orchestrate/aws/map_templates/instance_map.yml
    - template: jinja
    - makedirs: True
    - context:
        service_name: rabbitmq
        environment_name: {{ ENVIRONMENT }}
        num_instances: {{ INSTANCE_COUNT }}
        tags:
          business_unit: {{ BUSINESS_UNIT }}
          Department: {{ BUSINESS_UNIT }}
          OU: {{ BUSINESS_UNIT }}
          Environment: {{ ENVIRONMENT }}
          launch-date: '{{ launch_date }}'
        roles:
          - rabbitmq
        securitygroupid:
          - {{ salt.boto_secgroup.get_group_id(
            'rabbitmq-{}'.format(ENVIRONMENT), vpc_name=VPC_NAME) }}
          - {{ salt.boto_secgroup.get_group_id(
            'salt_master-{}'.format(ENVIRONMENT), vpc_name=VPC_NAME) }}
          - {{ salt.boto_secgroup.get_group_id(
            'consul-agent-{}'.format(ENVIRONMENT), vpc_name=VPC_NAME) }}
          - {{ salt.boto_secgroup.get_group_id(
            'vault-{}'.format(ENVIRONMENT), vpc_name=VPC_NAME) }}
        subnetids: {{ subnet_ids }}

ensure_instance_profile_exists_for_rabbitmq:
  boto_iam_role.present:
    - name: rabbitmq-instance-role

deploy_rabbitmq_cloud_map:
  salt.runner:
    - name: cloud.map_run
    - path: /etc/salt/cloud.maps.d/{{ ENVIRONMENT }}_rabbitmq_map.yml
    - kwargs:
        parallel: True
    - require:
        - file: generate_rabbitmq_cloud_map_file

sync_external_modules_for_rabbitmq_nodes:
  salt.function:
    - name: saltutil.sync_all
    - tgt: 'G@roles:rabbitmq and G@environment:{{ ENVIRONMENT }}'
    - tgt_type: compound

load_pillar_data_on_rabbitmq_nodes:
  salt.function:
    - name: saltutil.refresh_pillar
    - tgt: 'G@roles:rabbitmq and G@environment:{{ ENVIRONMENT }}'
    - tgt_type: compound
    - require:
        - salt: deploy_rabbitmq_cloud_map

populate_mine_with_rabbitmq_node_data:
  salt.function:
    - name: mine.update
    - tgt: 'G@roles:rabbitmq and G@environment:{{ ENVIRONMENT }}'
    - tgt_type: compound
    - require:
        - salt: load_pillar_data_on_rabbitmq_nodes

build_rabbitmq_nodes:
  salt.state:
    - tgt: 'G@roles:rabbitmq and G@environment:{{ ENVIRONMENT }} and G@launch-date:{{ launch_date }}'
    - tgt_type: compound
    - highstate: True
    - batch: 1
    - require:
        - salt: populate_mine_with_rabbitmq_node_data
    - pillar:
        rabbitmq:
          users:
            - name: guest
              state: absent
            - name: admin
              state: present
              settings:
                tags:
                  - administrator
              password: {{ rabbitmq_admin_password }}

configure_vault_rabbitmq_backend:
  vault.secret_backend_enabled:
    - backend_type: rabbitmq
    - description: Backend to create dynamic RabbitMQ credentials for {{ ENVIRONMENT }}
    - mount_point: rabbitmq-{{ ENVIRONMENT }}
    - connection_config:
        connection_uri: "http://rabbitmq.service.{{ ENVIRONMENT }}.consul:15672"
        username: admin
        password: {{ rabbitmq_admin_password }}
        verify_connection: False
    - ttl_max: {{ SIX_MONTHS }}
    - ttl_default: {{ SIX_MONTHS }}
    - lease_max: {{ SIX_MONTHS }}
    - lease_default: {{ SIX_MONTHS }}
