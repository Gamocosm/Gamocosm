FROM docker.io/ruby:3.1.2

WORKDIR /gamocosm

ARG secret_key_base

ENV SECRET_KEY_BASE=$secret_key_base

ENV RAILS_ENV=production
ENV RAILS_LOG_TO_STDOUT=1

RUN gem update bundler

COPY Gemfile Gemfile.lock ./

RUN bundle install

COPY app app
COPY bin bin
COPY config config
COPY db db
COPY lib lib
COPY public public
COPY test test

COPY config.ru Rakefile ./
COPY LICENSE README.md ./

RUN --mount=type=secret,id=gamocosm-ssh-key,target=/gamocosm/id_gamocosm rails assets:precompile
