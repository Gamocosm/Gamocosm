FROM docker.io/ruby:3.1.2

WORKDIR /gamocosm

ENV RAILS_ENV=production
ENV RAILS_LOG_TO_STDOUT=1

RUN bundle config set --local without development

COPY Gemfile Gemfile.lock ./

RUN bundle install

# Copy less-likely to change dirs first.
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

# https://github.com/rails/rails/pull/46760
RUN SECRET_KEY_BASE=1 rails assets:precompile
