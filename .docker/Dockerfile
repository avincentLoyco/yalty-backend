FROM yalty/centos-ruby:2.3.3
MAINTAINER "Yann Lugrin" <yann.lugrin@yalty.io>

# Versions
ARG BUNDLER_VERSION
ARG RAKE_VERSION
ARG PUMA_VERSION

# Other args
ARG BUNDLE_PATH=/code/vendor/bundle
ARG BUNDLE_APP_CONFIG=/code/.bundle
ARG BUNDLE_WITHOUT=development:test

# App envs
ENV RAILS_ENV=production
ENV RAILS_PORT=3000
ENV WEB_CONCURRENCY=1
ENV MAX_THREADS=5
ENV YALTY_APP_EMAIL=hello@yalty.io
ENV YALTY_APP_DOMAIN=lvh.me
ENV YALTY_OAUTH_ID=270a2b75eca9bec3b905301f959860d191777938312c03e22ce397a3dbb23043
ENV YALTY_OAUTH_SECRET=034f95ad0943085c9f82151ba390b5f7d661e5869531ecec3c7c3bf785d840ce
ENV YALTY_OAUTH_REDIRECT_URI=http://$YALTY_APP_DOMAIN/setup
ENV YALTY_OAUTH_SCOPES=all_access
ENV YALTY_MAINTENANCE_MODE=false
ENV SECRET_KEY_BASE=6a839d686e3f72eee506a11e8aa807725d69e4dc9ca3cb1a8ad31e0746b07201c40939a34b852a85eb9d44f2181de14a20dedfaeca6fa2e7cea359058fdbaff9
ENV REDIS_URL=redis://redis:6379
ENV DATABASE_URL=postgres://rails@db:5432/rails
ENV SMTP_ADDRESS=smtp
ENV SMTP_PORT=25
ENV SMTP_USERNAME=
ENV SMTP_PASSWORD=

# Bundle envs
ENV BUNDLE_PATH=$BUNDLE_PATH
ENV BUNDLE_BIN=$BUNDLE_PATH/bin
ENV BUNDLE_APP_CONFIG=$BUNDLE_APP_CONFIG
ENV BUNDLE_SILENCE_ROOT_WARNING=true
ENV BUNDLE_RETRY=3
ENV BUNDLE_JOBS=3

# Other envs
ENV DISABLE_SSL=true
ENV DISABLE_SPRING=true
ENV PATH=$BUNDLE_PATH/bin:$PATH

# Prepare
RUN mkdir -p  /code

WORKDIR /code

COPY Gemfile /code/Gemfile
COPY Gemfile.lock /code/Gemfile.lock

COPY .docker/update-yum-base-config.sed /update-yum-base-config.sed
COPY .docker/update-yum-updates-config.sed /update-yum-updates-config.sed

# Build
RUN set -ex \
  \
  && PATH=/usr/pgsql-9.4/bin:$PATH \
  \
  && buildDeps=' \
    make \
    gcc-c++ \
    postgresql94-devel \
  ' \
  && cat /etc/yum.repos.d/CentOS-Base.repo \
    | sed -n -f /update-yum-base-config.sed \
    | sed -n -f /update-yum-updates-config.sed \
    > /etc/yum.repos.d/CentOS-Base.repo.new \
  && mv /etc/yum.repos.d/CentOS-Base.repo.new /etc/yum.repos.d/CentOS-Base.repo \
  && yum install -y https://download.postgresql.org/pub/repos/yum/9.4/redhat/rhel-7-x86_64/pgdg-centos94-9.4-3.noarch.rpm \
  && yum -y update \
  && yum -y install $buildDeps \
  && yum clean all \
  && rm -rf /var/cache/yum/* \
  \
  && gem install rake --version "$RAKE_VERSION" \
  && gem install bundler --version "$BUNDLER_VERSION" \
  && gem install puma --version "$PUMA_VERSION" \
  && bundle install --without development test --deployment --clean \
  && rm -rf $GEM_HOME/cache/* \
  && rm -rf $BUNDLE_PATH/cache/* \
  && rm -rf $BUNDLE_PATH/*/*/cache/* \
  \
  && yum -y remove $buildDeps

# App
COPY .docker/run.sh /docker-run.sh
COPY . /code

RUN mkdir -p  /code/log
RUN mkdir -p  /code/tmp/pids

EXPOSE $RAILS_PORT
CMD ["/docker-run.sh"]
