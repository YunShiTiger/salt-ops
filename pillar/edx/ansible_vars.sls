#!jinja|yaml|gpg

{# TODO: Incorporate this for deploying xqueue to a separate instance
{# This needs to be set to a domain that is addressable by the xqueue server #}
{# because it is used when constructing the callback URL #}
{# EDXAPP_LMS_SITE_NAME: lms.service.consul #}
{# EDXAPP_CMS_SITE_NAME: cms.service.consul #}
{# EDXAPP_XQUEUE_URL: http://xqueue.service.consul #}

{# Move all following pillar data under a top-level key of `ansible_vars` #}
{# Use subkeys for the respective apps/playbooks (e.g. `forum`, `xqueue`, etc.) #}

{% import_yaml "environment_settings.yml" as env_settings %}
{% from "shared/edx/mitx.jinja" import edx with context %}
{% set business_unit = salt.grains.get('business_unit', 'residential') %}
{% set purpose = salt.grains.get('purpose', 'current-residential-live') %}
{% set purpose_suffix = purpose.replace('-', '_') %}
{% set environment = salt.grains.get('environment', 'mitx-qa') %}
{% set purpose_data = env_settings.environments[environment].purposes[purpose] %}
{% set cache_configs = env_settings.environments[environment].backends.elasticache %}
{% if cache_configs is mapping %}
  {% set cache_configs = [cache_configs] %}
{% endif %}


{# BEGIN VAULT DATA LOOKUPS #}
{% set xqueue_rabbitmq_creds = salt.vault.read(
    'rabbitmq-{env}/creds/xqueue-{purpose}'.format(
        env=environment,
        purpose=purpose)) %}
{% set edxapp_rabbitmq_creds = salt.vault.read(
    'rabbitmq-{env}/creds/celery-{purpose}'.format(
        env=environment,
        purpose=purpose)) %}
{% set admin_mysql_creds = salt.vault.read(
    'mysql-{env}/creds/admin'.format(
        env=environment)) %}
{% set xqueue_mysql_creds = salt.vault.read(
    'mysql-{env}/creds/xqueue-{purpose}'.format(
        env=environment,
        purpose=purpose)) %}
{% set edxapp_mysql_creds = salt.vault.read(
    'mysql-{env}/creds/edxapp-{purpose}'.format(
        env=environment,
        purpose=purpose)) %}
{% set edxapp_mongodb_contentstore_creds = salt.vault.read(
    'mongodb-{env}/creds/contentstore-{purpose}'.format(
        env=environment,
        purpose=purpose)) %}
{% set edxapp_mongodb_modulestore_creds = salt.vault.read(
    'mongodb-{env}/creds/modulestore-{purpose}'.format(
        env=environment,
        purpose=purpose)) %}
{% set forum_mongodb_creds = salt.vault.read(
    'mongodb-{env}/creds/forum-{purpose}'.format(
        env=environment,
        purpose=purpose)) %}
{% set gitlog_mongodb_creds = salt.vault.read(
    'mongodb-{env}/creds/gitlog-{purpose}'.format(
        env=environment,
        purpose=purpose)) %}
{% set mitx_s3_creds = salt.vault.read(
    'aws-mitx/creds/mitx-s3-{purpose}-{env}'.format(
        env=environment,
        purpose=purpose)) %}
{% set edxapp_xqueue_creds = salt.vault.read(
    'secret-{business_unit}/{env}/edxapp-xqueue-django-auth-{purpose}'.format(
        business_unit=business_unit,
        env=environment,
        purpose=purpose)) %}
{% set xqwatcher_xqueue_creds = salt.vault.read(
    'secret-{business_unit}/{env}/xqwatcher-xqueue-django-auth-{purpose}'.format(
        business_unit=business_unit,
        env=environment,
        purpose=purpose)) %}
{% set remote_gradebook = salt.vault.read(
    'secret-{business_unit}/{env}/remote_gradebook'.format(
        business_unit=business_unit, env=environment)) %}
{# END VAULT DATA LOOKUPS #}

{# Begin Duplicated Variables #}
{# multivariate #}
{% set CMS_DOMAIN = purpose_data.domains.cms %}
{% set EDXAPP_CMS_ISSUER = "https://{}/oauth2".format(CMS_DOMAIN) %}
{% set COMMENTS_SERVICE_KEY = salt.vault.read('secret-residential/global/forum-api-key').data.value %} # TODO: randomly generate? (tmacey 2017/03/16)
{% set DEFAULT_FEEDBACK_EMAIL = 'mitx-support@mit.edu' %}
{% set DEFAULT_FROM_EMAIL = 'mitx-support@mit.edu' %}
{# multivariate, needs to be different for Professional Education, sandbox, etc #}
{% set GIT_REPO_DIR = edx.edxapp_git_repo_dir %}
{# multivariate #}
{% set LMS_DOMAIN = purpose_data.domains.lms %}
{% set EDXAPP_LMS_ISSUER = "https://{}/oauth2".format(LMS_DOMAIN) %}
{% set MONGODB_HOST = 'mongodb-master.service.consul' %}
{% set MONGODB_MODULESTORE_ENGINE =  'xmodule.modulestore.mongo.MongoModuleStore' %}
{% set MONGODB_REPLICASET = salt.pillar.get('mongodb:replset_name', 'rs0') %}
{% set MONGODB_PORT = 27017 %}
{% set MONGODB_USE_SSL = False %}
{% set MYSQL_HOST = 'mysql.service.consul' %}
{% set MYSQL_PORT = 3306 %}
{% set THEME_NAME = 'mitx-theme' %}
{% set TIME_ZONE = 'America/New_York' %}
{% set TLS_LOCATION = edx.edxapp_tls_location_name %}
{% set TLS_KEY_NAME = edx.edxapp_tls_key_name %}
{% set XQUEUE_PASSWORD = salt.vault.read('secret-residential/global/xqueue-password').data.value %}
{% set XQUEUE_USER = 'lms' %}
{# End Duplicated Variables #}

edx:
  ansible_vars:
    ### COMMON VARS ###
    COMMON_MYSQL_ADMIN_USER: {{ admin_mysql_creds.data.username }}
    COMMON_MYSQL_ADMIN_PASS: {{ admin_mysql_creds.data.password }}
    COMMON_MYSQL_MIGRATE_USER: {{ admin_mysql_creds.data.username }}
    COMMON_MYSQL_MIGRATE_PASS: {{ admin_mysql_creds.data.password }}

    ### XQUEUE ENVIRONMENT ###
    XQUEUE_AWS_ACCESS_KEY_ID: {{ mitx_s3_creds.data.access_key }}
    XQUEUE_AWS_SECRET_ACCESS_KEY: {{ mitx_s3_creds.data.secret_key }}
    XQUEUE_BASIC_AUTH_USER: mitx
    XQUEUE_BASIC_AUTH_PASSWORD: |
      {{ XQUEUE_PASSWORD|indent(6) }}
    XQUEUE_DJANGO_USERS:
      {{ edxapp_xqueue_creds.data.username }}: {{ edxapp_xqueue_creds.data.password }}
      {{ xqwatcher_xqueue_creds.data.username }}: {{ xqwatcher_xqueue_creds.data.password }}
    XQUEUE_LOGGING_ENV: {{ edx.edxapp_log_env_suffix}}
    XQUEUE_MYSQL_DB_NAME: xqueue_{{ purpose_suffix }}
    XQUEUE_MYSQL_HOST: {{ MYSQL_HOST }}
    XQUEUE_MYSQL_PASSWORD: {{ xqueue_mysql_creds.data.password }}
    XQUEUE_MYSQL_PORT: {{ MYSQL_PORT }}
    XQUEUE_MYSQL_USER: {{ xqueue_mysql_creds.data.username }}
    XQUEUE_QUEUES:
        'MITx-42.01x': 'https://xserver.mitx.mit.edu/fgxserver'
        'MITx-8371': 'https://xqueue.mitx.mit.edu/qis_xserver'
        # TODO: Are these courses still in use? Can we shut down the xserver instance? (tmacey 2017-03-16)
        'MITx-6.s064x': 'http://127.0.0.1:8051'
        'MITx-7.QBWr': 'http://127.0.0.1:8050'
        'matlab': 'https://mitx.mss-mathworks.com/stateless/mooc/MITx'
        # push queue
        'edX-DemoX': 'http://localhost:8050'
        # pull queues
        'Watcher-MITx-6.0001r': !!null
        'Watcher-MITx-6.00x': !!null
        'open-ended': !!null
        'open-ended-message': !!null
        'test-pull': !!null
        'certificates': !!null
    XQUEUE_RABBITMQ_HOSTNAME: nearest-rabbitmq.query.consul
    XQUEUE_RABBITMQ_PASS: {{ xqueue_rabbitmq_creds.data.password }}
    XQUEUE_RABBITMQ_USER: {{ xqueue_rabbitmq_creds.data.username }}
    XQUEUE_RABBITMQ_VHOST: /xqueue_{{ purpose_suffix }}
    XQUEUE_S3_BUCKET: mitx-grades-{{ purpose }}-{{ environment }}
    XQUEUE_WORKERS_PER_QUEUE: 2
    xqueue_source_repo: "https://github.com/mitodl/xqueue.git"
    xqueue_version: "master"

    ### EDXAPP ENVIRONMENT ###
    {# TODO: Determine if this is still necessary (tmacey 2017/03/16) #}
    common_debian_pkgs:
      - ntp
      - acl
      - lynx-cur
      - logrotate
      - rsyslog
      - git
      - unzip
      - python2.7
      - python-pip
      - python2.7-dev
    elb_pre_post: false {# prevents ansible from trying to handle ELB for us (tmacey 2017-03-16) #}
    {# residential only #}
    edxapp_course_static_dir: /edx/var/edxapp/course_static_dummy {# private variable, used to hack around the fact that we mount our course data via a shared file system (tmacey 2017-03-16) #}
    {# residential only, set this in order to verride the `fs_root` setting for module/content store, need to understand more fully how this gets used in GITHUB_REPO_ROOT (tmacey 2017/03/17) #}
    edxapp_course_data_dir: {{ GIT_REPO_DIR }}

    EDXAPP_AWS_STORAGE_BUCKET_NAME: mitx-storage-{{ purpose }}-{{ environment }}
    EDXAPP_IMPORT_EXPORT_BUCKET: !!null
    EDXAPP_AWS_S3_CUSTOM_DOMAIN: !!null
    EDXAPP_CELERY_WORKERS:
      - queue: low
        service_variant: cms
        concurrency: 1
        monitor: True
      - queue: default
        service_variant: cms
        concurrency: 1
        monitor: True
      - queue: high
        service_variant: cms
        concurrency: 1
        monitor: True
      - queue: low
        service_variant: lms
        concurrency: 1
        monitor: True
      - queue: default
        service_variant: lms
        concurrency: 2
        monitor: True
      - queue: high
        service_variant: lms
        concurrency: 2
        monitor: True
      - queue: high_mem
        service_variant: lms
        concurrency: 1
        monitor: False
        max_tasks_per_child: 1
    EDXAPP_CMS_ISSUER: "{{ EDXAPP_CMS_ISSUER }}"
    EDXAPP_CMS_ROOT_URL: "https://{{ CMS_DOMAIN }}"
    {# Tell Ansible to install python dependencies from github. https://github.com/edx/edx-platform/blob/ned%2Ftest-ficus/requirements/edx/edx-private.txt#L1 (tmacey 2017/03/16) #}
    EDXAPP_INSTALL_PRIVATE_REQUIREMENTS: true
    EDXAPP_LMS_ISSUER: "{{ EDXAPP_LMS_ISSUER }}"
    EDXAPP_LMS_ROOT_URL: "https://{{ LMS_DOMAIN }}"
    EDXAPP_LMS_SITE_NAME: {{ purpose_data.domains.lms }}
    EDXAPP_CMS_SITE_NAME: {{ purpose_data.domains.cms }}

    EDXAPP_MEMCACHE:
      {% for cache_config in cache_configs %}
      {% set cache_purpose = cache_config.get('purpose', 'shared') %}
      {% if cache_purpose in purpose %}
      {% set ELASTICACHE_CONFIG = salt.boto3_elasticache.describe_cache_clusters(cache_config.cluster_id[:20].strip('-'), ShowCacheNodeInfo=True)[0] %}
      {% for host in ELASTICACHE_CONFIG.CacheNodes %}
      - {{ host.Endpoint.Address }}:{{ host.Endpoint.Port }}
      {% endfor %}
      {% endif %}
      {% endfor %}

    ####################################################################
    ############### MongoDB SETTINGS ###################################
    ####################################################################
    {# Settings for Content Store #}
    EDXAPP_MONGO_DB_NAME: contentstore_{{ purpose_suffix }}
    EDXAPP_MONGO_HOSTS: {{ MONGODB_HOST }}
    EDXAPP_MONGO_PASSWORD: {{ edxapp_mongodb_contentstore_creds.data.password }}
    EDXAPP_MONGO_PORTS: {{ MONGODB_PORT }}
    EDXAPP_MONGO_USER: {{ edxapp_mongodb_contentstore_creds.data.username }}
    {# TODO: revisit once PKI is deployed (tmacey 2017/03/17) #}
    EDXAPP_MONGO_USE_SSL: {{ MONGODB_USE_SSL }}

    {# Settings for Module Store #}
    {# We have to replicate the data three times in order to allow for #}
    {# a different database name between the content and module stores. #}
    {# It is a quirk of how the edX Ansible repo has the vars configured. #}
    {# (tmacey 2017/03/17) #}
    doc_store_config: &doc_store_config
      db: modulestore_{{ purpose_suffix }}
      host: "{{ MONGODB_HOST }}"
      {# multivariate, vault #}
      password: {{ edxapp_mongodb_modulestore_creds.data.password }}
      port: {{ MONGODB_PORT }}
      {# multivariate, vault #}
      user: {{ edxapp_mongodb_modulestore_creds.data.username }}
      collection:  'modulestore'
      replicaset: "{{ MONGODB_REPLICASET }}"
      readPreference: "nearest"
      ssl: {{ MONGODB_USE_SSL }}
      socketTimeoutMS: 3000
      connectTimeoutMS: 2000

    EDXAPP_LMS_DRAFT_DOC_STORE_CONFIG:
      <<: *doc_store_config

    EDXAPP_LMS_SPLIT_DOC_STORE_CONFIG:
      <<: *doc_store_config

    EDXAPP_CMS_DOC_STORE_CONFIG:
      <<: *doc_store_config


    #####################################################################
    ############### MySQL Config ########################################
    #####################################################################
    EDXAPP_MYSQL_DB_NAME: edxapp_{{ purpose_suffix }}
    EDXAPP_MYSQL_HOST: {{ MYSQL_HOST }}
    EDXAPP_MYSQL_PASSWORD: {{ edxapp_mysql_creds.data.password }}
    EDXAPP_MYSQL_PORT: {{ MYSQL_PORT }}
    EDXAPP_MYSQL_USER: {{ edxapp_mysql_creds.data.username }}

    #####################################################################
    ########### Auth Configs ############################################
    #####################################################################
    EDXAPP_AWS_ACCESS_KEY_ID: {{ mitx_s3_creds.data.access_key }}
    EDXAPP_AWS_SECRET_ACCESS_KEY: {{ mitx_s3_creds.data.secret_key }}
    EDXAPP_CELERY_PASSWORD: {{ edxapp_rabbitmq_creds.data.password }}
    EDXAPP_CELERY_USER: {{ edxapp_rabbitmq_creds.data.username }}
    {# multivariate #}
    EDXAPP_GOOGLE_ANALYTICS_ACCOUNT: {{ edx.edxapp_google_analytics_account }}
    {# multivariate, vault #}
    EDXAPP_XQUEUE_DJANGO_AUTH:
      username: {{ edxapp_xqueue_creds.data.username }}
      password: {{ edxapp_xqueue_creds.data.password }}
    EDXAPP_YOUTUBE_API_KEY: {{ salt.vault.read('secret-residential/global/edxapp-youtube-api-key').data.value }}
    EDXAPP_LMS_AUTH_EXTRA:
      SECRET_KEY: {{ salt.vault.read('secret-residential/global/edxapp-lms-django-secret-key').data.value }}
      MONGODB_LOG:
        db: gitlog_{{ purpose_suffix }}
        host: mongodb-master.service.consul
        user: {{ gitlog_mongodb_creds.data.username }}
        password: {{ gitlog_mongodb_creds.data.password }}
        replicaset: "{{ MONGODB_REPLICASET }}"
        readPreference: "nearest"
      REMOTE_GRADEBOOK_USER: {{ remote_gradebook.data.user }}
      REMOTE_GRADEBOOK_PASSWORD: {{ remote_gradebook.data.password }}
    EDXAPP_CMS_AUTH_EXTRA:
      SECRET_KEY: {{ salt.vault.read('secret-residential/global/edxapp-cms-django-secret-key').data.value }}

    #####################################################################
    ########### Environment Configs #####################################
    #####################################################################

    ########## START THEMING ########################################
    EDXAPP_COMPREHENSIVE_THEME_SOURCE_REPO: 'https://github.com/mitodl/mitx-theme.git'
    EDXAPP_COMPREHENSIVE_THEME_VERSION: {{ purpose_data.versions.theme }}
    edxapp_theme_source_repo: 'https://github.com/mitodl/mitx-theme.git'
    edxapp_theme_version: {{ purpose_data.versions.theme }}
    EDXAPP_COMPREHENSIVE_THEME_DIRS:
      - /edx/app/edxapp/themes/
    {# multivariate #}
    edxapp_theme_name: {{ THEME_NAME }}
    {# multivariate #}
    EDXAPP_DEFAULT_SITE_THEME: {{ THEME_NAME }}
    ########## END THEMING ########################################

    EDXAPP_ANALYTICS_DASHBOARD_URL: !!null
    EDXAPP_BUGS_EMAIL: mitx-support@mit.edu
    {# multivariate, only needed for current deployment. will be removed in favor of SAML (tmacey 2017/03/20) #}
    EDXAPP_CAS_ATTRIBUTE_PACKAGE: 'git+https://github.com/mitodl/mitx_cas_mapper#egg=mitx_cas_mapper'
    {# multivariate, only used for current residential #}
    EDXAPP_CAS_SERVER_URL: 'https://cas.mitx.mit.edu/cas'
    {# multivariate, only used for current residential #}
    EDXAPP_CAS_ATTRIBUTE_CALLBACK:
      module: mitx_cas_mapper
      function: populate_user
    {# multivariate, only used for current residential #}
    EDXAPP_CAS_EXTRA_LOGIN_PARAMS:
      provider: touchstone
      appname: MITx
    {# multivariate #}
    EDXAPP_CELERY_BROKER_VHOST: /celery_{{ purpose_suffix }}
    EDXAPP_CMS_BASE: {{ CMS_DOMAIN }}
    EDXAPP_CODE_JAIL_LIMITS:
      REALTIME: 3
      CPU: 3
      FSIZE: 1048576
      PROXY: 0
      VMEM: 536870912
    EDXAPP_COMMENTS_SERVICE_KEY: {{ COMMENTS_SERVICE_KEY }}
    EDXAPP_COMMENTS_SERVICE_URL: "http://localhost:4567"
    EDXAPP_CONTACT_EMAIL: mitx-support@mit.edu
    EDXAPP_ENABLE_CSMH_EXTENDED: False
    EDXAPP_ENABLE_READING_FROM_MULTIPLE_HISTORY_TABLES: False
    EDXAPP_CUSTOM_COURSES_EDX: True
    EDXAPP_DEFAULT_FEEDBACK_EMAIL: "{{ DEFAULT_FEEDBACK_EMAIL }}"
    EDXAPP_DEFAULT_FROM_EMAIL: "{{ DEFAULT_FROM_EMAIL }}"
    EDXAPP_DEFAULT_FILE_STORAGE: 'storages.backends.s3boto.S3BotoStorage'
    EDXAPP_ELASTIC_SEARCH_CONFIG:
      - host: nearest-elasticsearch.query.consul
        port: 9200
    EDXAPP_ENABLE_COMPREHENSIVE_THEMING: true
    EDXAPP_ENABLE_MOBILE_REST_API: True
    {# multivariate #}
    EDXAPP_ENABLE_OAUTH2_PROVIDER: False
    EDXAPP_ENABLE_SYSADMIN_DASHBOARD: True
    EDXAPP_FILE_UPLOAD_STORAGE_BUCKET_NAME: mitx-storage-{{ purpose }}-{{ environment }}
    {# multivariate #}
    EDXAPP_FILE_UPLOAD_STORAGE_PREFIX: {{ edx.edxapp_upload_storage_prefix }}
    EDXAPP_GIT_REPO_DIR: "{{ GIT_REPO_DIR }}"
    EDXAPP_GRADE_BUCKET: mitx-grades-{{ purpose }}-{{ environment }}
    EDXAPP_GRADE_ROOT_PATH: {{ edx.edxapp_aws_grades_root_path }}
    EDXAPP_GRADE_STORAGE_TYPE: S3
    EDXAPP_IMPORT_EXPORT_BUCKET: "mitx-storage-{{ salt.grains.get('purpose') }}-{{ salt.grains.get('environment') }}"
    EDXAPP_JWT_SECRET_KEY: {{ salt.vault.read('secret-{business_unit}/{env}/edxapp-jwt-secret-key'.format(env=environment, business_unit=business_unit)).data.value }}
    EDXAPP_LMS_BASE: "{{ LMS_DOMAIN }}"
    EDXAPP_MKTG_URL_LINK_MAP:
      CONTACT: !!null
      FAQ: !!null
      HONOR: !!null
      PRIVACY: !!null
    EDXAPP_ORA2_FILE_PREFIX: "{{ salt.grains.get('environment') }}-dev/ora2"
    EDXAPP_PLATFORM_NAME: MITx Residential
    EDXAPP_RABBIT_HOSTNAME: nearest-rabbitmq.query.consul
    EDXAPP_TECH_SUPPORT_EMAIL: mitx-support@mit.edu
    EDXAPP_TIME_ZONE: "{{ TIME_ZONE }}"

    # Use YAML references (& and *) and hash merge <<: to factor out shared settings
    # see http://atechie.net/2009/07/merging-hashes-in-yaml-conf-files/
    common_feature_flags: &common_feature_flags
      ALLOW_ALL_ADVANCED_COMPONENTS: true
      AUTH_USE_CAS: true
      AUTH_USE_CERTIFICATES: false
      AUTH_USE_OPENID_PROVIDER: false
      BYPASS_ACTIVATION_EMAIL_FOR_EXTAUTH: true
      CERTIFICATES_ENABLED: false
      DISABLE_LOGIN_BUTTON: false
      DISPLAY_HISTOGRAMS_TO_STAFF: true
      ENABLE_COURSE_BLOCKS_NAVIGATION_API: true
      ENABLE_DISCUSSION_SERVICE: true
      ENABLE_INSTRUCTOR_ANALYTICS: true
      ENABLE_INSTRUCTOR_LEGACY_DASHBOARD: true
      ENABLE_PEARSON_HACK_TEST: false
      ENABLE_RENDER_XBLOCK_API: true
      ENABLE_SPECIAL_EXAMS: true
      PREVIEW_LMS_BASE: {{ purpose_data.domains.preview }}
      REROUTE_ACTIVATION_EMAIL: mitx-support@mit.edu
      RESTRICT_ENROLL_BY_REG_METHOD: false
      SUBDOMAIN_BRANDING: false
      SUBDOMAIN_COURSE_LISTINGS: false
      MILESTONES_APP: true
      ENABLE_PREREQUISITE_COURSES: true

    common_env_config: &common_env_config
      ADDL_INSTALLED_APPS:
        - ubcpi
      ADMINS:
      - ['MITx Stacktrace Recipients', 'cuddle-bunnies@mit.edu']
      SERVER_EMAIL: mitxmail@mit.edu
      TIME_ZONE_DISPLAYED_FOR_DEADLINES: "{{ TIME_ZONE }}"

    EDXAPP_LMS_ENV_EXTRA:
      <<: *common_env_config
      BULK_EMAIL_DEFAULT_FROM_EMAIL: mitx-support@mit.edu
      COURSE_ABOUT_VISIBILITY_PERMISSION: "{{ edx.edxapp_course_about_visibility_permission }}"
      COURSE_CATALOG_VISIBILITY_PERMISSION: "{{ edx.edxapp_course_catalog_visibility_permission }}"
      COURSE_MODE_DEFAULTS:
        bulk_sku: !!null
        currency: 'usd'
        description: !!null
        expiration_datetime: !!null
        min_price: 0
        name: 'Honor'
        sku: !!null
        slug: 'honor'
        suggested_prices: ''
      FEATURES:
        <<: *common_feature_flags
        ALLOW_COURSE_STAFF_GRADE_DOWNLOADS: true
        ALLOW_PUBLIC_ACCOUNT_CREATION: false
        ENABLE_AUTO_COURSE_REGISTRATION: true
        ENABLE_INSTRUCTOR_EMAIL: true
        ENABLE_INSTRUCTOR_REMOTE_GRADEBOOK_CONTROLS: true
        ENABLE_PAID_COURSE_REGISTRATION: false
        ENABLE_S3_GRADE_DOWNLOADS: true
        ENABLE_SHOPPING_CART: true
        ENABLE_SYSADMIN_DASHBOARD: true
        INDIVIDUAL_DUE_DATES: true
        LICENSING: true
        REQUIRE_COURSE_EMAIL_AUTH: false
        RESTRICT_ENROLL_NO_ATSIGN_USERNAMES: true
      FIELD_OVERRIDE_PROVIDERS:
        - courseware.student_field_overrides.IndividualStudentOverrideProvider
      GIT_IMPORT_STATIC: false
      LOGGING_ENV: lms-{{ edx.edxapp_log_env_suffix}}
      OAUTH_OIDC_ISSUER: "{{ EDXAPP_LMS_ISSUER }}"
      REMOTE_GRADEBOOK:
        URL: {{ remote_gradebook.data.url }}
        DEFAULT_NAME: !!null
      STUDENT_FILEUPLOAD_MAX_SIZE: "{{ edx.edxapp_max_upload_size * 1024 * 1024 }}"

    EDXAPP_CMS_ENV_EXTRA:
      <<: *common_env_config
      FEATURES:
        <<: *common_feature_flags
        ALLOW_COURSE_RERUNS: true
        ALLOW_HIDING_DISCUSSION_TAB: true
        ALLOW_PUBLIC_ACCOUNT_CREATION: False
        DISABLE_COURSE_CREATION: true
        DISABLE_START_DATES: true
        ENABLE_EXPORT_GIT: true
        ENABLE_SQL_TRACKING_LOGS: true
        SEGMENT_IO: false
        STAFF_EMAIL: mitx-support@mit.edu
      LOGGING_ENV: cms-{{ edx.edxapp_log_env_suffix }}
      OAUTH_OIDC_ISSUER: "{{ EDXAPP_CMS_ISSUER }}"

    ################################################################################
    #################### Forum Settings ############################################
    ################################################################################

    FORUM_API_KEY: "{{ COMMENTS_SERVICE_KEY }}"
    FORUM_ELASTICSEARCH_HOST: "nearest-elasticsearch.query.consul"
    FORUM_MONGO_USER: {{ forum_mongodb_creds.data.username }}
    FORUM_MONGO_PASSWORD: {{ forum_mongodb_creds.data.password }}
    FORUM_MONGO_HOSTS:
      - {{ MONGODB_HOST }}
    FORUM_MONGO_PORT: {{ MONGODB_PORT }}
    {# multivariate #}
    FORUM_MONGO_DATABASE: forum_{{ purpose_suffix }}
    FORUM_RACK_ENV: "production"
    FORUM_SINATRA_ENV: "production"
    FORUM_USE_TCP: True
    forum_source_repo: "https://github.com/mitodl/cs_comments_service.git"
    forum_version: {{ purpose_data.versions.forum }}

    ### Specific configuration overrides ###

    {# multivariate #}
    edx_platform_version: {{ purpose_data.versions.edxapp }}
    edx_platform_repo: 'https://github.com/mitodl/edx-platform.git'

    EDXAPP_LMS_PREVIEW_NGINX_PORT: 80
    EDXAPP_CMS_NGINX_PORT: 80
    EDXAPP_LMS_NGINX_PORT: 80
    EDXAPP_CMS_SSL_NGINX_PORT: 443
    EDXAPP_LMS_SSL_NGINX_PORT: 443

    # Configure TLS
    NGINX_ENABLE_SSL: True
    NGINX_REDIRECT_TO_HTTPS: True
    NGINX_HTTPS_REDIRECT_STRATEGY: "scheme"

    NGINX_SSL_CERTIFICATE: '{{ TLS_LOCATION }}/{{ TLS_KEY_NAME }}.crt'
    NGINX_SSL_KEY: '{{ TLS_LOCATION }}/{{ TLS_KEY_NAME }}.key'

    # Configure HTTP auth
    COMMON_ENABLE_BASIC_AUTH: False

    # Ask search bots to not index sandboxes
    NGINX_ROBOT_RULES:
      - agent: '*'
        disallow: '/'

    # Disable useless roles
    COMMON_ENABLE_AWS_ROLE: False
    COMMON_ENABLE_NEWRELIC: False
    COMMON_ENABLE_NEWRELIC_INFRASTRUCTURE: False
    COMMON_ENABLE_MINOS: False
