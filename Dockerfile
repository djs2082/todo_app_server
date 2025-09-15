FROM ruby:3.0.2

RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 3000

# scp -r -i your-key.pem ./app ubuntu@your-instance-public-ip:/home/ubuntu/
# ssh -i your-key.pem ubuntu@your-instance-public-ip

# The actual command will be overridden in docker-compose.yml
CMD ["rails", "server", "-b", "0.0.0.0"]