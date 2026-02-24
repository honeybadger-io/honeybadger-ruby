# CLAUDE.md

This file provides guidance for AI agents when working with code in this repository.

## Project Overview

Honeybadger Ruby gem — error tracking and observability for Ruby applications. Supports Rails, Sinatra, Hanami, and standalone Ruby. Requires Ruby >= 3.0.

## Common Commands

### Tests (RSpec)

```bash
bundle exec rake              # Run all tests (units + integrations + features)
bundle exec rake spec:units   # Unit tests only
bundle exec rake spec:features # Feature/CLI tests (Aruba-based, slower)
bundle exec rake spec:integrations # Integration tests

# Single test file
bundle exec rspec spec/unit/honeybadger/agent_spec.rb

# Single test by line number
bundle exec rspec spec/unit/honeybadger/agent_spec.rb:42

# Tests with a specific Appraisal gemfile (e.g., Rails 8)
bundle exec appraisal rails8 rake spec:units
```

### Linting

```bash
bundle exec standardrb        # Check style (auto-fixes by default, see .standard.yml)
bundle exec standardrb --no-fix # Check without fixing
```

### Appraisals (multi-framework testing)

```bash
bundle exec appraisal install # Install all appraisal gemfiles
bundle exec appraisal list    # List available appraisals
```

Available appraisals: standalone, rack, rack-1, sinatra, hanami, rails6.1, rails7.0, rails7.1, rails7.2, rails8, rails (edge), sidekiq, sidekiq7, resque, delayed_job, binding_of_caller.

## Architecture

### Entry Points

- `lib/honeybadger.rb` — Framework detection entrypoint. Detects Rails/Sinatra/Hanami and loads the appropriate initializer from `lib/honeybadger/init/`.
- `lib/honeybadger/ruby.rb` — Core require that loads `Honeybadger::Singleton`.
- `bin/honeybadger` — CLI (Thor-based, vendored in `vendor/cli/`).

### Core Classes

- **`Agent`** (`lib/honeybadger/agent.rb`) — Central orchestrator. Global singleton accessed via `Honeybadger.method_name` (delegated through `Singleton`). Manages configuration, context, plugins, and worker threads.
- **`Config`** (`lib/honeybadger/config.rb`) — Layered configuration: Ruby DSL > environment variables (`HONEYBADGER_*`) > YAML > defaults. Sources in `lib/honeybadger/config/`.
- **`Notice`** (`lib/honeybadger/notice.rb`) — Exception/error data structure with backtrace, context, sanitization, and JSON serialization.
- **`Event`** (`lib/honeybadger/event.rb`) — Custom event/Insights payload. Acts like a Hash via delegation.
- **`Plugin`** (`lib/honeybadger/plugin.rb`) — Plugin registration system with `requirement` and `execution` blocks. All plugins in `lib/honeybadger/plugins/`.

### Plugin System

Plugins register via `Honeybadger::Plugin.register('name')` with requirement blocks (checked at load time) and execution blocks (run when requirements are met). ~22 plugins for frameworks, job queues, HTTP clients, etc. See `lib/honeybadger/plugins/` for examples.

### Backend Abstraction

`lib/honeybadger/backend/` — `Server` (production HTTP), `Debug` (stdout), `Null` (no-op), `Test` (in-memory). Decouples delivery from collection.

### Worker Threads

- `Worker` — base async notice delivery
- `EventsWorker` — async event/Insights processing
- `MetricsWorker` — periodic metric collection (calls plugin `collect` blocks)

### Rack Middleware

`lib/honeybadger/rack/` — `ErrorNotifier` (catches exceptions), `UserFeedback`, `UserInformer`.

### Breadcrumbs

`lib/honeybadger/breadcrumbs/` — Ring buffer-based trail of events leading to an error. Integrates with ActiveSupport::Notifications.

## Key Conventions

- Public API classes/methods are marked with YARD `@api public`. Everything else is internal and may change without notice.
- All commits follow [conventional commits](https://www.conventionalcommits.org/). Releases are automated via Release Please.
- Tests are filtered by framework: specs tagged `framework: :rails` only run under a Rails appraisal gemfile. Same for `:sinatra`, `:rake`, `:ruby`.
- `spec/spec_helper.rb` stubs `https://api.honeybadger.io/v1/notices` globally and sets up a null backend agent before each test.
- Feature specs use Aruba (CLI testing framework) with 12s timeout (120s on JRuby).
