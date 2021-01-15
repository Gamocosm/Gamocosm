FROM ruby:2.6.5

# install required packages
RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs

# setup workspace
RUN mkdir /myapp
WORKDIR /myapp
COPY Gemfile /myapp/Gemfile
COPY Gemfile.lock /myapp/Gemfile.lock
COPY Rakefile /myapp/Rakefile

# install gems
RUN gem install bundler:2.1.4
RUN bundle install

# entrypoint
CMD bundle exec rails s
