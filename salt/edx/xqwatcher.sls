{% set data_path = '/tmp/edx_config' -%}
{% set venv_path = '/tmp/edx_config/venv' -%}
{% set repo_path = '/tmp/edx_config/configuration' -%}
{% set conf_file = '/tmp/edx_config/edx-xqwatcher.conf' -%}
{% set playbooks = salt.pillar.get('xqueue:playbooks', ['edx-east/xqwatcher.yml']) %}

include:
  - .run_ansible

configure_git_ppa_for_edx:
  pkgrepo.managed:
    - ppa: git-core/ppa
    - require_in:
        - pkg: install_os_packages

install_os_packages:
  pkg.installed:
    - pkgs:
        - git
        - python
        - python-dev
        - python3
        - python3-dev
        - python-pip
        - python-virtualenv
        - libmysqlclient-dev
        - libssl-dev
    - refresh: True
    - refresh_modules: True
    - require_in:
      - cmd: run_ansible

activate_xqwatcher_supervisor_config:
  file.symlink:
    - name: /edx/app/supervisor/conf.d/xqwatcher.conf
    - target: /edx/app/supervisor/conf.available.d/xqwatcher.conf
    - user: supervisor
    - group: www-data
  cmd.wait:
    - name: /edx/bin/supervisorctl reread && /edx/bin/supervisorctl update
    - watch:
        - file: activate_xqwatcher_supervisor_config
