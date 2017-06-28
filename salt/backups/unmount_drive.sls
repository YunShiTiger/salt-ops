{% from "orchestrate/edx/backup" import backup with context %}

unmount_backup_drive:
  mount.unmounted:
    - name: /backups
    - device: /dev/xvdb

detach_backup_volume:
  cloud.action:
    - func: boto_ec2.detach_volume
    - kwargs:
        tags:
          Name: {{ backup.backup_volume_name }}
          device: /dev/xvdb
    - require:
        - salt: unmount_backup_drive
