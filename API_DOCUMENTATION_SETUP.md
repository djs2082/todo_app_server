# API Documentation Setup (Swagger/OpenAPI)

## Document Information
- **Version:** 1.0
- **Last Updated:** 2025-11-04
- **Status:** Sprint 0 - API Documentation Framework
- **Purpose:** Guide for setting up and maintaining API documentation

---

## Table of Contents
1. [Overview](#overview)
2. [rswag Setup](#rswag-setup)
3. [Writing API Specs](#writing-api-specs)
4. [Generating Documentation](#generating-documentation)
5. [Swagger UI](#swagger-ui)
6. [Best Practices](#best-practices)
7. [Examples](#examples)

---

## Overview

### What is Swagger/OpenAPI?

**OpenAPI (formerly Swagger)** is a specification for describing REST APIs. It provides:
- Interactive API documentation
- Request/response examples
- Try-it-out functionality
- Auto-generated client SDKs
- API validation

### rswag

**rswag** is a Ruby gem that:
- Generates OpenAPI specs from RSpec tests
- Provides Swagger UI for browsing docs
- Validates requests/responses
- Generates API documentation automatically

### Architecture

```
┌─────────────────────────────────────────────────┐
│         RSpec Request Specs                      │
│  (spec/requests/*_spec.rb with rswag DSL)       │
└───────────────────┬─────────────────────────────┘
                    │
                    ▼
         ┌──────────────────────┐
         │  rake rswag:specs:   │
         │  swaggerize          │
         └──────────┬───────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│        OpenAPI JSON/YAML Files                   │
│      (swagger/v1/swagger.yaml)                  │
└───────────────────┬─────────────────────────────┘
                    │
                    ▼
         ┌──────────────────────┐
         │    Swagger UI        │
         │  /api-docs           │
         └──────────────────────┘
```

---

## rswag Setup

### Step 1: Add Gems

Add to `Gemfile`:

```ruby
# API Documentation
group :development, :test do
  gem 'rswag-specs'
end

group :development do
  gem 'rswag-api'
  gem 'rswag-ui'
end
```

Install:
```bash
bundle install
```

### Step 2: Install rswag

```bash
rails g rswag:install
```

This creates:
- `config/initializers/rswag_api.rb`
- `config/initializers/rswag_ui.rb`
- `spec/swagger_helper.rb`
- `swagger/v1/swagger.yaml` (template)

### Step 3: Configure Swagger Helper

**File:** `spec/swagger_helper.rb`

```ruby
require 'rails_helper'

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  config.swagger_root = Rails.root.join('swagger').to_s

  # Define one or more Swagger documents and provide global metadata
  config.swagger_docs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'TodoApp API V1',
        version: 'v1',
        description: 'Enterprise Todo Application REST API',
        contact: {
          name: 'API Support',
          email: 'api@todoapp.com',
          url: 'https://todoapp.com/support'
        },
        license: {
          name: 'MIT',
          url: 'https://opensource.org/licenses/MIT'
        }
      },
      paths: {},
      servers: [
        {
          url: 'http://localhost:3000',
          description: 'Development server'
        },
        {
          url: 'https://staging-api.todoapp.com',
          description: 'Staging server'
        },
        {
          url: 'https://api.todoapp.com',
          description: 'Production server'
        }
      ],
      components: {
        securitySchemes: {
          Bearer: {
            type: :http,
            scheme: :bearer,
            bearerFormat: 'JWT',
            description: 'JWT Authorization header using the Bearer scheme. Example: "Authorization: Bearer {token}"'
          }
        },
        schemas: {
          User: {
            type: :object,
            properties: {
              id: { type: :integer, example: 1 },
              email: { type: :string, example: 'user@example.com' },
              first_name: { type: :string, example: 'John' },
              last_name: { type: :string, example: 'Doe' },
              created_at: { type: :string, format: 'date-time' },
              updated_at: { type: :string, format: 'date-time' }
            },
            required: ['id', 'email', 'first_name', 'last_name']
          },
          Task: {
            type: :object,
            properties: {
              id: { type: :integer, example: 1 },
              title: { type: :string, example: 'Complete API documentation' },
              description: { type: :string, example: 'Write comprehensive API docs' },
              status: { type: :string, enum: ['pending', 'in_progress', 'paused', 'completed'] },
              priority: { type: :integer, enum: [0, 1, 2], example: 1 },
              due_date_time: { type: :string, format: 'date-time', nullable: true },
              created_at: { type: :string, format: 'date-time' },
              updated_at: { type: :string, format: 'date-time' }
            },
            required: ['id', 'title', 'status']
          },
          Error: {
            type: :object,
            properties: {
              error: { type: :string, example: 'Record not found' },
              message: { type: :string, example: 'The requested resource was not found' },
              status: { type: :integer, example: 404 }
            }
          }
        }
      },
      tags: [
        { name: 'Authentication', description: 'User authentication endpoints' },
        { name: 'Users', description: 'User management' },
        { name: 'Tasks', description: 'Task management' },
        { name: 'Accounts', description: 'Account/Organization management' },
        { name: 'Health', description: 'Health check endpoints' }
      ]
    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'
  config.swagger_format = :yaml
end
```

### Step 4: Configure Routes

**File:** `config/routes.rb`

```ruby
Rails.application.routes.draw do
  # Swagger/API documentation
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'

  # ... your other routes
end
```

### Step 5: Configure UI

**File:** `config/initializers/rswag_ui.rb`

```ruby
Rswag::Ui.configure do |c|
  # List the Swagger endpoints
  c.swagger_endpoint '/api-docs/v1/swagger.yaml', 'API V1 Docs'

  # Add Basic Auth in non-production environments
  if Rails.env.production?
    c.basic_auth_enabled = true
    c.basic_auth_credentials 'admin', ENV['SWAGGER_PASSWORD']
  end

  # Customize the UI
  c.config_object[:deepLinking] = true
  c.config_object[:displayRequestDuration] = true
  c.config_object[:docExpansion] = 'list'
  c.config_object[:filter] = true
end
```

---

## Writing API Specs

### Example: Tasks API Spec

**File:** `spec/requests/api/v1/tasks_spec.rb`

```ruby
require 'swagger_helper'

RSpec.describe 'Tasks API', type: :request do
  # Setup
  let(:user) { create(:user) }
  let(:account) { create(:account) }
  let(:token) { JsonWebToken.encode(user_id: user.id) }
  let(:Authorization) { "Bearer #{token}" }

  path '/api/v1/tasks' do
    get 'List all tasks' do
      tags 'Tasks'
      description 'Retrieves all tasks for the authenticated user'
      produces 'application/json'
      security [Bearer: []]

      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Items per page'
      parameter name: :status, in: :query, type: :string, required: false, description: 'Filter by status'
      parameter name: :priority, in: :query, type: :integer, required: false, description: 'Filter by priority'

      response '200', 'tasks found' do
        schema type: :object,
               properties: {
                 tasks: {
                   type: :array,
                   items: { '$ref' => '#/components/schemas/Task' }
                 },
                 meta: {
                   type: :object,
                   properties: {
                     total_count: { type: :integer },
                     page: { type: :integer },
                     per_page: { type: :integer },
                     total_pages: { type: :integer }
                   }
                 }
               }

        let(:page) { 1 }
        let(:per_page) { 20 }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['tasks']).to be_an(Array)
          expect(data['meta']).to be_a(Hash)
        end
      end

      response '401', 'unauthorized' do
        let(:Authorization) { 'Bearer invalid_token' }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end

    post 'Create a task' do
      tags 'Tasks'
      description 'Creates a new task'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: []]

      parameter name: :task, in: :body, schema: {
        type: :object,
        properties: {
          title: { type: :string, example: 'Complete project' },
          description: { type: :string, example: 'Finish all remaining tasks' },
          priority: { type: :integer, enum: [0, 1, 2], example: 1 },
          due_date_time: { type: :string, format: 'date-time', example: '2025-12-31T23:59:59Z' }
        },
        required: ['title']
      }

      response '201', 'task created' do
        let(:task) { { title: 'New Task', priority: 1 } }
        schema '$ref' => '#/components/schemas/Task'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['title']).to eq('New Task')
          expect(data['priority']).to eq(1)
        end
      end

      response '422', 'invalid request' do
        let(:task) { { title: '' } }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { 'Bearer invalid_token' }
        let(:task) { { title: 'Task' } }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/tasks/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Task ID'

    get 'Get a specific task' do
      tags 'Tasks'
      description 'Retrieves a specific task by ID'
      produces 'application/json'
      security [Bearer: []]

      response '200', 'task found' do
        schema '$ref' => '#/components/schemas/Task'

        let(:task_record) { create(:task, user: user) }
        let(:id) { task_record.id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(task_record.id)
        end
      end

      response '404', 'task not found' do
        let(:id) { 99999 }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { 'Bearer invalid_token' }
        let(:id) { 1 }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end

    patch 'Update a task' do
      tags 'Tasks'
      description 'Updates a specific task'
      consumes 'application/json'
      produces 'application/json'
      security [Bearer: []]

      parameter name: :task, in: :body, schema: {
        type: :object,
        properties: {
          title: { type: :string },
          description: { type: :string },
          status: { type: :string, enum: ['pending', 'in_progress', 'paused', 'completed'] },
          priority: { type: :integer, enum: [0, 1, 2] }
        }
      }

      response '200', 'task updated' do
        schema '$ref' => '#/components/schemas/Task'

        let(:task_record) { create(:task, user: user) }
        let(:id) { task_record.id }
        let(:task) { { title: 'Updated Title' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['title']).to eq('Updated Title')
        end
      end

      response '404', 'task not found' do
        let(:id) { 99999 }
        let(:task) { { title: 'Updated' } }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end

    delete 'Delete a task' do
      tags 'Tasks'
      description 'Deletes a specific task'
      produces 'application/json'
      security [Bearer: []]

      response '204', 'task deleted' do
        let(:task_record) { create(:task, user: user) }
        let(:id) { task_record.id }

        run_test!
      end

      response '404', 'task not found' do
        let(:id) { 99999 }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end
end
```

---

## Generating Documentation

### Generate Swagger Files

```bash
# Run rswag specs to generate swagger.yaml
rake rswag:specs:swaggerize

# Or run specific specs
SWAGGER_DRY_RUN=0 rspec spec/requests/api/v1/tasks_spec.rb --format Rswag::Specs::SwaggerFormatter --order defined
```

This generates:
- `swagger/v1/swagger.yaml`

### Regenerate on Test Run

Add to `.rspec`:
```
--format Rswag::Specs::SwaggerFormatter
```

Or in `spec/rails_helper.rb`:
```ruby
RSpec.configure do |config|
  config.after(:suite) do
    # Generate swagger docs after running all specs
    Rswag::Specs::SwaggerFormatter.write_to_file if ENV['SWAGGER_DRY_RUN'] != '1'
  end
end
```

---

## Swagger UI

### Accessing Documentation

**Development:**
```
http://localhost:3000/api-docs
```

**Staging:**
```
https://staging-api.todoapp.com/api-docs
```

**Production:**
```
https://api.todoapp.com/api-docs
(Requires authentication)
```

### Features

1. **Interactive API Explorer**
   - Try out API calls directly
   - See request/response examples
   - Test authentication

2. **Schema Validation**
   - Validates requests against schema
   - Shows required fields
   - Displays data types

3. **Code Generation**
   - Generate client SDKs
   - Export OpenAPI spec
   - Import to Postman

### Screenshots

```
┌──────────────────────────────────────────────────┐
│  TodoApp API V1                        v1.0      │
├──────────────────────────────────────────────────┤
│  Servers: ▼ http://localhost:3000               │
│                                                  │
│  ▼ Authentication                                │
│    POST /api/v1/auth/login     Login user       │
│    POST /api/v1/auth/refresh   Refresh token    │
│                                                  │
│  ▼ Tasks                                         │
│    GET    /api/v1/tasks        List tasks       │
│    POST   /api/v1/tasks        Create task      │
│    GET    /api/v1/tasks/{id}   Get task         │
│    PATCH  /api/v1/tasks/{id}   Update task      │
│    DELETE /api/v1/tasks/{id}   Delete task      │
│                                                  │
│  ▼ Users                                         │
│    GET    /api/v1/users/me     Get current user │
│    PATCH  /api/v1/users/me     Update profile   │
└──────────────────────────────────────────────────┘
```

---

## Best Practices

### 1. Document All Endpoints

Every API endpoint should have:
- Description
- Parameters (with types and examples)
- Request body schema
- Response schemas (all status codes)
- Authentication requirements
- Examples

### 2. Use Shared Schemas

Define common schemas in `swagger_helper.rb`:
```ruby
components: {
  schemas: {
    User: { ... },
    Task: { ... },
    Error: { ... },
    PaginationMeta: { ... }
  }
}
```

Reference them:
```ruby
schema '$ref' => '#/components/schemas/Task'
```

### 3. Include Examples

```ruby
parameter name: :email, in: :query, type: :string,
          example: 'user@example.com',
          description: 'User email address'
```

### 4. Document Error Responses

```ruby
response '422', 'validation error' do
  schema type: :object,
         properties: {
           errors: {
             type: :object,
             properties: {
               title: { type: :array, items: { type: :string } },
               email: { type: :array, items: { type: :string } }
             }
           }
         }
  run_test!
end
```

### 5. Use Tags for Organization

```ruby
tags 'Tasks', 'Users', 'Authentication', 'Accounts'
```

### 6. Version Your API

```ruby
path '/api/v1/tasks' do
  # v1 implementation
end

path '/api/v2/tasks' do
  # v2 implementation
end
```

### 7. Keep Tests and Docs in Sync

- Run `rake rswag:specs:swaggerize` before committing
- Add to CI pipeline
- Review docs in PRs

---

## Examples

### Authentication Endpoint

```ruby
path '/api/v1/auth/login' do
  post 'Login user' do
    tags 'Authentication'
    description 'Authenticates user and returns JWT tokens'
    consumes 'application/json'
    produces 'application/json'

    parameter name: :credentials, in: :body, schema: {
      type: :object,
      properties: {
        email: { type: :string, example: 'user@example.com' },
        password: { type: :string, example: 'password123' }
      },
      required: ['email', 'password']
    }

    response '200', 'login successful' do
      schema type: :object,
             properties: {
               access_token: { type: :string },
               refresh_token: { type: :string },
               expires_in: { type: :integer, example: 900 },
               user: { '$ref' => '#/components/schemas/User' }
             }

      let(:credentials) { { email: user.email, password: 'password' } }
      run_test!
    end

    response '401', 'invalid credentials' do
      let(:credentials) { { email: 'wrong@email.com', password: 'wrong' } }
      schema '$ref' => '#/components/schemas/Error'
      run_test!
    end
  end
end
```

### Pagination Example

```ruby
response '200', 'paginated tasks' do
  schema type: :object,
         properties: {
           tasks: {
             type: :array,
             items: { '$ref' => '#/components/schemas/Task' }
           },
           meta: {
             type: :object,
             properties: {
               current_page: { type: :integer, example: 1 },
               total_pages: { type: :integer, example: 5 },
               total_count: { type: :integer, example: 95 },
               per_page: { type: :integer, example: 20 }
             }
           },
           links: {
             type: :object,
             properties: {
               self: { type: :string },
               first: { type: :string },
               prev: { type: :string, nullable: true },
               next: { type: :string, nullable: true },
               last: { type: :string }
             }
           }
         }
  run_test!
end
```

---

## CI/CD Integration

### Add to CI Pipeline

**File:** `.github/workflows/ci.yml`

```yaml
- name: Generate API Documentation
  run: |
    bundle exec rake rswag:specs:swaggerize

- name: Upload Swagger Spec
  uses: actions/upload-artifact@v4
  with:
    name: swagger-spec
    path: swagger/v1/swagger.yaml
```

### Validate in PR

```yaml
- name: Validate Swagger Spec
  run: |
    npm install -g @apidevtools/swagger-cli
    swagger-cli validate swagger/v1/swagger.yaml
```

---

## Hosting Documentation

### Options

1. **Self-hosted with Rails**
   - Already configured with rswag-ui
   - Available at `/api-docs`
   - Requires deployment

2. **Static hosting**
   - Export swagger.yaml
   - Host on GitHub Pages
   - Use Swagger UI static build

3. **Third-party services**
   - Readme.io
   - Stoplight.io
   - SwaggerHub

---

## Next Steps

1. ✅ rswag documentation created
2. ⬜ Add rswag gems to Gemfile
3. ⬜ Run `rails g rswag:install`
4. ⬜ Configure swagger_helper.rb
5. ⬜ Write API specs for existing endpoints
6. ⬜ Generate swagger.yaml
7. ⬜ Test Swagger UI locally
8. ⬜ Add to CI pipeline
9. ⬜ Deploy to staging
10. ⬜ Share docs with frontend team

---

**Document Version:** 1.0
**Last Updated:** 2025-11-04
**Maintained by:** Backend Team
