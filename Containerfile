FROM docker.io/ruby:3.1.2

WORKDIR /gamocosm

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

COPY config.ru Rakefile ./
COPY LICENSE README.md ./

COPY id_gamocosm.pub ./

RUN rails assets:precompile
