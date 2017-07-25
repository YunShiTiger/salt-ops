{% for user, pubkeys in salt.pillar.get('users', {}).items() %}
create_user_for_ssh:
  user.present:
    - name: {{ user }}
    - shell: /bin/bash

{% for pubkey in pubkeys %}
{% set enc, key, comment = pubkey.split() %}
add_{{ comment }}_public_key_to_{{ user }}:
  ssh_auth.present:
    - name: {{ key }}
    - user: {{ user }}
    - enc: {{ enc }}
    - comment: {{ comment }}
{% endfor %}
create_sudoers_file_for_{{ user }}:
  file.managed:
    - name: /etc/sudoers.d/{{ user }}
    - contents: "{{ user }} ALL=(ALL) NOPASSWD:ALL"
    - mode: 0440
{% endfor %}
