FROM ruby:3.3.0-slim

# Set environment variables early
ENV DEBIAN_FRONTEND=noninteractive \
    app_path=/usr/app \
    RAILS_SERVE_STATIC_FILES=true \
    RAILS_LOG_TO_STDOUT=true \
    LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2 \
    RAILS_ENV="production"

RUN apt-get update && apt-get install -y --no-install-recommends \
    libjemalloc-dev \
    curl \
    gnupg \
    build-essential \
    ca-certificates \
    && mkdir -p /etc/apt/keyrings

# 1. Install Node.js 20 (LTS) - Modern Method
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list

# 2. Install Node.js and enable Yarn via corepack (more reliable than yarn apt package)
RUN apt-get update && apt-get install -y --no-install-recommends nodejs \
    && corepack enable \
    && corepack prepare yarn@stable --activate

# 3. Install all dependencies in one layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    bzip2 \
    git \
    shared-mime-info \
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
    ffmpeg \
    supervisor \
    libvips42 \
    libxrender1 \
    fonts-wqy-zenhei \
    libjemalloc2 \
    vim \
    && rm -rf /var/lib/apt/lists/*

WORKDIR $app_path

# Install Bundler
RUN gem install bundler -v 2.6.6 

# Copy Gemfile first for better caching
COPY Gemfile* ./
RUN bundle config set --local deployment 'true' \
    && bundle config set --local without 'development test' \
    && bundle install --jobs 4

# Copy the rest of the application
COPY . $app_path

# Precompile Assets
RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rake assets:clean \
    && SECRET_KEY_BASE_DUMMY=1 bundle exec rake assets:precompile

# Set Executable Permission for Entrypoint
RUN chmod +x /usr/app/docker-entrypoint.sh
ENTRYPOINT ["/usr/app/docker-entrypoint.sh"]

COPY ./supervisord.conf /etc/supervisord.conf

CMD ["supervisord", "-c", "/etc/supervisord.conf"]