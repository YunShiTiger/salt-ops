{% set ENVIRONMENT = salt.grains.get('environment') %}
elasticsearch:
  lookup:
    pkgs:
      - openjdk-7-jre-headless
    verify_package: False
    configuration_settings:
      discovery.zen.hosts_provider: ec2
      discovery.ec2.tag.escluster: {{ ENVIRONMENT }}
      gateway.recover_after_nodes: 2
      gateway.expected_nodes: 3
      discovery.zen.minimum_master_nodes: 2
      cluster.name: {{ ENVIRONMENT }}
      repositories:
        s3:
          bucket: {{ ENVIRONMENT }}-elasticsearch-backups
          region: us-east-1
      network.host: [_eth0_, _lo_]
    products:
      elasticsearch: '1.7'
  plugins:
    - name: cloud-aws
      location: elasticsearch/elasticsearch-cloud-aws/2.7.1
