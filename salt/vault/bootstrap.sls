include:
  - vault.initialize

{% for backend in ['github', 'app-id', 'aws-ec2'] %}
enable_{{ backend }}_auth_backend:
  vault.auth_backend_enabled:
    - backend_type: {{ backend }}
    - require:
        - vault: initialize_vault_server
{% endfor %}

enable_syslog_audit_backend:
  vault.audit_backend_enabled:
    - backend_type: syslog

create_salt_master_policy:
  vault.policy_created:
    - name: salt-master
    - rules:
        path:
          '*':
            policy: sudo
          'sys/*':
            policy: sudo

register_root_ec2_role:
  vault.ec2_role_created:
    - role: salt-master
    - bound_ami_id: ami-116d857a
    - policies:
        - root
        - salt-master