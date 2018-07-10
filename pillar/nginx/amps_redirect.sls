{% set app_name = 'amps-redirect' %}

nginx:
  ng:
    install_from_source: False
    source_version: 1.15.1
    source_hash: c7206858d7f832b8ef73a45c9b8f8e436bcb1ee88db2bc85b8e438ecec9d5460
    certificates:
      odl_wildcard:
        public_cert: __vault__::secret-operations/global/odl_wildcard_cert>data>value
        private_key: __vault__::secret-operations/global/odl_wildcard_cert>data>key
    servers:
      managed:
        {{ app_name }}:
          enabled: True
          config:
            - server:
                - server_name: amps-web.amps.ms.mit.edu
                - listen:
                    - 80
                - listen:
                    - '[::]:80'
                - location /:
                    - return: 301 https://docs.google.com/forms/d/e/1FAIpQLSdvkI2cPG1iMM4gN_KyKem4fNLh4irWzrmjX-JhcFXa51su5g/viewform?fbzx=2658557852628862500
            - server:
                - server_name: amps-web.amps.ms.mit.edu
                - listen:
                    - 443
                    - ssl
                    - default
                - listen:
                    - '[::]:443'
                    - ssl
                - ssl_certificate: /etc/nginx/ssl/odl_wildcard.crt
                - ssl_certificate_key: /etc/nginx/ssl/odl_wildcard.key
                - ssl_stapling: 'on'
                - ssl_stapling_verify: 'on'
                - ssl_session_timeout: 1d
                - ssl_session_tickets: 'off'
                - ssl_protocols:
                    - TLSv1.2
                    - TLSv1.3
                - ssl_ciphers: "ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256\
                     :ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384\
                     :DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256\
                     :ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384\
                     :ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256\
                     :DHE-RSA-AES256-SHA:ECDHE-ECDSA-DES-CBC3-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES128-GCM-SHA256\
                     :AES256-GCM-SHA384:AES128-SHA256:AES256-SHA256:AES128-SHA:AES256-SHA:DES-CBC3-SHA:!DSS"
                - ssl_prefer_server_ciphers: 'on'
                - resolver: 1.1.1.1
                - location /:
                    - return: 301 https://docs.google.com/forms/d/e/1FAIpQLSdvkI2cPG1iMM4gN_KyKem4fNLh4irWzrmjX-JhcFXa51su5g/viewform?fbzx=2658557852628862500
