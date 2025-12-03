FROM ruby:3.3.0-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    libjemalloc-dev \
    curl \
    gnupg \
    build-essential \
    software-properties-common

RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
  && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
  && curl -sL https://deb.nodesource.com/setup_14.x | bash -

RUN apt-get install -y --no-install-recommends \
    bzip2 \
    git \
    shared-mime-info \
    ca-certificates \
    libffi-dev \
    libpq-dev \
    libgdbm-dev \
    libssl-dev \
    libyaml-dev \
    patch \
    procps \
    ruby-dev \
    zlib1g-dev \
    liblzma-dev \
    default-mysql-client \
    default-libmysqlclient-dev \
    openssl \
    tzdata \
    file \
    imagemagick \
    iproute2 \
    nodejs \
    yarn \
    ffmpeg \
    supervisor \
    libvips42 \
    libxrender1 \
    fonts-wqy-zenhei \
    libjemalloc2 \
    vim \
    && rm -rf /var/lib/apt/lists/*

ENV DEBIAN_FRONTEND=noninteractive
ENV app_path=/usr/app
ENV RAILS_SERVE_STATIC_FILES=true
ENV RAILS_LOG_TO_STDOUT=true
ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2 
ENV RAILS_ENV="production"

WORKDIR $app_path

# Install Bundler
RUN gem install bundler -v 2.6.6 

# Copy Gemfile first for better caching
COPY Gemfile* ./
RUN bundle config set --local deployment 'true'
RUN bundle config set --local without 'development test'
RUN bundle install --jobs 4

# Copy the rest of the application
ADD . $app_path

# Precompile Assets with a dummy SECRET_KEY_BASE (only used during build)
RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rake assets:clean
RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rake assets:precompile

# Set Executable Permission for Entrypoint
RUN chmod +x /usr/app/docker-entrypoint.sh
ENTRYPOINT ["/usr/app/docker-entrypoint.sh"]

# Copy supervisord configuration
COPY ./supervisord.conf /etc/supervisord.conf

# Start supervisord
CMD ["supervisord", "-c", "/etc/supervisord.conf"]