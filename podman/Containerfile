FROM docker.io/ruby:3.1.2

WORKDIR /gamocosm

RUN gem update bundler

COPY Gemfile Gemfile.lock ./

RUN bundle install

COPY . ./

RUN rails assets:precompile
