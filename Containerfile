FROM docker.io/ruby:3.1.2

WORKDIR /gamocosm

ENV RAILS_ENV=production
ENV RAILS_LOG_TO_STDOUT=1

COPY Gemfile Gemfile.lock ./

RUN bundle install

COPY app app
COPY bin bin
COPY config config
COPY db db
COPY lib lib
COPY public public
COPY scripts scripts
COPY test test

COPY config.ru Rakefile ./
COPY LICENSE README.md ./

RUN SECRET_KEY_BASE=1 rails assets:precompile
