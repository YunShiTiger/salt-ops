delete_edx_logs_older_than_30_days:
  cmd.run:
    - name: |
        find /edx/var/log -type f  -mtime +30 -name "*.gz" -exec rm -f {} \;
