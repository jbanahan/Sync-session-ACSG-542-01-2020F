ARG RUBY_VERSION

FROM ruby:$RUBY_VERSION

# Install dependencies
COPY .dockerdev/Aptfile /tmp/Aptfile
RUN apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get -yq dist-upgrade && \
  DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
    build-essential net-tools \
    mysql-client \
    $(cat /tmp/Aptfile | xargs) && \
    apt-get clean && \
    rm -rf /var/cache/apt/archives/* && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    truncate -s 0 /var/log/*log

# Configure bundler
ENV LANG=C.UTF-8 \
  BUNDLE_JOBS=4 \
  BUNDLE_RETRY=3

# Create a directory for the app code
RUN mkdir -p /app
WORKDIR /app
ADD Gemfile /app/
ADD Gemfile.lock /app/
