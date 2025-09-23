FROM docker.io/fedora:42

# Debugging convenience.
RUN dnf --assumeyes install vim git
RUN dnf --assumeyes install nmap-ncat

# Building/installing ruby.
RUN dnf --assumeyes install rbenv

# Building gems.
RUN dnf --assumeyes install postgresql-devel

# https://github.com/rbenv/rbenv?tab=readme-ov-file#how-rbenv-hooks-into-your-shell
ENV PATH="/root/.rbenv/shims:${PATH}"

WORKDIR /gamocosm

COPY .ruby-version ./

RUN rbenv install

# https://bundler.io/man/bundle-config.1.html#set
RUN bundle config set --local silence_root_warning true
RUN bundle config set --local without development

COPY Gemfile Gemfile.lock ./

RUN bundle install

# Copy directories and files that are less likely to change first.
COPY bin bin
COPY lib lib
COPY vendor vendor

COPY public public
COPY test test

COPY db db
COPY scripts scripts
COPY config config
COPY app app

COPY config.ru Rakefile ./
COPY LICENSE README.md ./

ENV RAILS_ENV=production
ENV RAILS_LOG_TO_STDOUT=1

# https://github.com/rails/rails/pull/46760
RUN SECRET_KEY_BASE=1 rails assets:precompile
