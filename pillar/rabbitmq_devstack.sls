#!jinja|yaml

{% set rabbitmq_admin_password = salt.random.get_str(20) %}

rabbitmq:
  overrides:
    version: '3.6.10-1'
  configuration:
    rabbit:
      auth_backends:
        - '@rabbit_auth_backend_internal'
  env:
    RABBITMQ_USE_LONGNAMES: 'true'
  users:
    - name: guest
      state: absent
    - name: admin
      state: present
      settings:
        tags:
          - administrator
        perms:
          - '/xqueue':
              - '.*'
              - '.*'
              - '.*'
          - '/celery':
              - '.*'
              - '.*'
              - '.*'
        password: {{ rabbitmq_admin_password }}
  vhosts:
    - name: xqueue
      state: present
    - name: celery
      state: present
