{% set data_path = '/tmp/edx_config' -%}
{% set venv_path = '/tmp/edx_config/venv' -%}
{% set repo_path = '/tmp/edx_config/configuration' -%}
{% set conf_file = '/tmp/edx_config/edx-sandbox.conf' -%}
{% set git_export_path = salt.pillar.get('edxapp:EDXAPP_GIT_REPO_EXPORT_DIR',
                                         '/edx/var/edxapp/export_course_repos') -%}
{% set git_servers = salt.pillar.get('edx:ssh_hosts',
                                     [{'name': 'github.com',
                                       'fingerprint': '9d:38:5b:83:a9:17:52:92:56:1a:5e:c4:d4:81:8e:0a:ca:51:a2:64:f1:74:20:11:2e:f8:8a:c3:a1:39:49:8f'},
                                      {'name': 'github.mit.edu',
                                       'fingerprint': '98:fd:6f:32:bb:11:90:fe:a5:e3:66:ec:d1:db:17:7a:3a:b7:62:0c:4c:0f:6a:f9:36:a6:e8:22:6a:ac:b3:0d'}]) %}
{% set theme_repo = salt.pillar.get('edx:edxapp:custom_theme:repo', 'https://github.com/mitodl/mitx-theme') -%}
{% set theme_name = salt.pillar.get('edx:edxapp:THEME_NAME', None) -%}
{% set theme_branch = salt.pillar.get('edx:edxapp:custom_theme:branch', 'mitx') -%}
{% set theme_dir = salt.pillar.get('edx:edxapp:EDXAPP_COMPREHENSIVE_THEME_DIR', '/edx/app/edxapp/themes') -%}

include:
  - .run_ansible

{% if salt.grains.get('osfinger') == 'Ubuntu-12.04' %}
configure_git_ppa_for_edx:
  pkgrepo.managed:
    - ppa: git-core/ppa
    - require_in:
        - pkg: install_os_packages

configure_python_ppa_for_edx:
  pkgrepo.managed:
    - ppa: fkrull/deadsnakes-python2.7
    - require_in:
        - pkg: install_os_packages
{% endif %}

install_os_packages:
  pkg.installed:
    - pkgs:
        - git
        - libmysqlclient-dev
        - mariadb-client-10.0
        - landscape-common
        - libssl-dev
        - python2.7
        - python2.7-dev
        - python-pip
        - python-virtualenv
        - nfs-common
        - postfix
        - memcached
    - refresh: True
    - refresh_modules: True
    - require_in:
        - virtualenv: create_ansible_virtualenv
        - git: clone_edx_configuration

{% if salt.pillar.get('edx:generate_tls_certificate') %}
generate_self_signed_certificate:
  module.run:
    - name: tls.create_self_signed_cert
    - CN: {{ salt.pillar.get('edx:ansible_env_config:TLS_KEY_NAME') }}
    - replace: True
    - require_in:
      - cmd: run_ansible
{% else %}
{%
  set key_path = '{}/{}'.format(
    salt.pillar.get('edx:edxapp:TLS_LOCATION'),
    salt.pillar.get('edx:edxapp:TLS_KEY_NAME')
  )
%}
{% for ext in ['crt', 'key'] %}
place_tls_{{ ext }}_file:
  file.managed:
    - name: {{ key_path }}.{{ ext }}
    - contents_pillar: {{ 'edx:tls_{}'.format(ext) }}
    - user: root
    - group: root
    - mode: 600
    - makedirs: True
    - require_in:
      - cmd: run_ansible
{% endfor %}
{% endif %}

{% if 'devstack' not in salt.grains.get('roles') %}
mount_efs_filesystem_for_course_assets:
  mount.mounted:
    - name: /mnt/data
    - device: {{ salt.grains.get('ec2:availability_zone', 'us-east-1b')|trim }}.{{ salt.pillar.get('edx:efs_id')|trim }}.efs.us-east-1.amazonaws.com:/
    - fstype: nfs4
    - mkmnt: True
    - persist: True
    - mount: True

create_course_asset_symlink:
  file.symlink:
    - name: /edx/var/edxapp/course_static
    - target: {{ salt.pillar.get('edx:edxapp:GIT_REPO_DIR', '/mnt/data/prod_repos') }}
    - makedirs: True
    - force: True
    - user: edxapp
    - group: www-data

{# Steps to enable git export for courses #}
make_git_export_directory:
  file.directory:
    - name: {{ git_export_path }}
    - user: www-data
    - group: www-data
    - makedirs: True

add_private_ssh_key_to_www-data_for_git_export:
  file.managed:
    - name: /var/www/.ssh/id_rsa
    - contents_pillar: edx:ssh_key
    - mode: 0600
    - makedirs: True
    - dir_mode: 0700
    - user: www-data
    - group: www-data
{% endif %}

{% if theme_name %}
install_edxapp_theme:
  file.directory:
    - name: {{ theme_dir }}
    - makedirs: True
    - user: edxapp
    - group: edxapp
  git.latest:
    - name: {{ theme_repo }}
    - branch: {{ theme_branch }}
    - target: {{ theme_dir }}/{{ theme_name }}
    - user: edxapp
    - force_checkout: True
    - force_clone: True
    - force_reset: True
    - update_head: True
    - require:
      - file: install_edxapp_theme
    - require_in:
      - cmd: run_ansible

compile_assets_for_lms:
  cmd.run:
    - name: /edx/bin/edxapp-update-assets-lms
    - onchanges:
        - git: install_edxapp_theme
    - require:
        - cmd: run_ansible

compile_assets_for_cms:
  cmd.run:
    - name: /edx/bin/edxapp-update-assets-cms
    - onchanges:
        - git: install_edxapp_theme
    - require:
        - cmd: run_ansible
{% endif %}

{% for host in git_servers %}
add_{{ host.name }}_to_known_hosts_for_edxapp:
  ssh_known_hosts.present:
    - name: {{ host.name }}
    - user: www-data
    - enc: ssh-rsa
    - fingerprint: "{{ host.fingerprint }}"
    - fingerprint_hash_type: sha256
{% endfor %}
