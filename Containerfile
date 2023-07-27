FROM docker.io/ruby:3.1.2

WORKDIR /gamocosm

ENV RAILS_ENV=production
ENV RAILS_LOG_TO_STDOUT=1

RUN bundle config set --local without development test

COPY Gemfile Gemfile.lock ./

RUN bundle install

# https://guides.rubyonrails.org/getting_started.html#creating-the-blog-application
COPY app app
COPY bin bin
COPY config config
COPY db db
COPY lib lib
COPY public public
COPY scripts scripts
COPY test test
COPY vendor vendor

COPY config.ru Rakefile ./
COPY LICENSE README.md ./

# https://github.com/rails/rails/pull/46760
RUN SECRET_KEY_BASE=1 rails assets:precompile
