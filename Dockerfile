# syntax=docker/dockerfile:1

# ── Build stage: install gems ─────────────────────────────────────────────────
FROM ruby:4.0.1-alpine AS builder

RUN apk add --no-cache \
    build-base \
    postgresql-dev

WORKDIR /app

COPY Gemfile Gemfile.lock* ./
RUN bundle config set --local without 'development test' && \
    bundle install --jobs 4 --retry 3

# ── Runtime stage ─────────────────────────────────────────────────────────────
FROM ruby:4.0.1-alpine AS runtime

# libpq: pg adapter runtime dependency; tzdata: reliable Time zone support
RUN apk add --no-cache \
    libpq \
    tzdata

WORKDIR /app

# Copy only the installed gem tree from the builder (no compiler toolchain)
COPY --from=builder /usr/local/bundle /usr/local/bundle

COPY . .

RUN chmod +x bin/entrypoint

ENV RACK_ENV=production

ENTRYPOINT ["bin/entrypoint"]
CMD ["bundle", "exec", "ruby", "bot.rb"]
