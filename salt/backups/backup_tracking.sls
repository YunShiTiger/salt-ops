{% set edx_tracking_local_folder = '/edx/var/log/tracking' %}
{% set instance_id = salt.grains.get('id') %}

tar_tracking_data:
  cmd.run:
    - name: 'tar -czf edx_tracking_{{ instance_id }}.tgz *'
    - cwd: {{ edx_tracking_local_folder }}
    - creates: {{ edx_tracking_local_folder }}/edx_tracking_{{ instance_id }}.tgz

upload_tar_to_s3:
  module.run:
    - name: s3.put
    - bucket: {{ edx_tracking_bucket }}
    - path: 'retired-instance-logs'
    - local_file: {{ edx_tracking_local_folder }}/edx_tracking_{{ instance_id }}.tgz
