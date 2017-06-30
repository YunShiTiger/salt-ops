install_duplicity:
  pkg.installed:
    - pkgs:
        - duplicity
        - python-pip

install_duplicity_backend_requirements:
  pip.installed:
    - name: boto

{% for service in salt.pillar.get('backups:enabled', []) %}
{% if service.get('pkgs') %}
install_packages_for_{{ service.title }}_backup:
  pkg.installed:
    - pkgs: {{ service.pkgs }}
{% endif %}

run_backup_for_{{ service.title }}:
  file.managed:
    - name: /backups/{{service.title}}_backup.sh
    - source: salt://backups/templates/backup_{{ service.name }}.sh
    - template: jinja
    - context:
        settings: {{ service.settings }}
  cmd.script:
    - name: salt://backups/templates/backup_{{ service.name }}.sh
    - template: jinja
    - context:
        settings: {{ service.settings }}
{% endfor %}
