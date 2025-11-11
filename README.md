# Warranty Buddy - Iteration 1

Your Digital Memory for Every Purchase

## Team Members

- **Maria Aswad Janoo** - [maj2198]
- **Gilad Bregman** - [gb2862]
- **Danielle Reich** - [dr3368]
- **Kalei Ragland** - [kar2247]
  
## Heroku Deployment
https://safe-reef-46455-4dc844325c04.herokuapp.com/

## Project Description

Warranty Buddy is a Rails application that helps users track product warranties by automatically parsing Gmail receipts and managing warranty information. The application integrates with Google OAuth for Gmail access and uses AI to extract warranty details from receipts.

## Features

- 🔐 Google OAuth integration for Gmail access
- 📧 Automatic receipt parsing from Gmail
- 🤖 AI-powered warranty information extraction (Gemini AI)
- ✏️ Manual warranty entry with edit/delete functionality
- 🔍 Search and filter warranties by status, merchant, and product
- 📊 Sort warranties by expiry date, purchase date, product name, or merchant
- 📤 Export warranties to CSV or iCal format
- 📱 Progressive Web App (PWA) support
- ✅ Comprehensive test coverage (85.9% line coverage)

## Technology Stack

- **Ruby**: 3.2.2
- **Rails**: 8.1.0
- **Database**: PostgreSQL 14
- **AI**: Google Gemini API (gemini-2.0-flash)
- **OAuth**: OmniAuth Google OAuth2
- **Testing**: RSpec, Cucumber, SimpleCov
- **Browser Testing**: Capybara with Selenium WebDriver

## Prerequisites

Before running this application, ensure you have the following installed:

- Ruby 3.2.2
- PostgreSQL 14 or higher
- Bundler gem
- Node.js (for asset compilation)
- Tesseract

## Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/mariaaj03/warranty-buddy.git
cd warranty-buddy/warranty-buddy
```

### 2. Install Dependencies

```bash
bundle install
brew install tesseract
```

### 3. Configure Credentials

The application requires Google OAuth and Gemini AI credentials. Set up your credentials:

```bash
EDITOR="code --wait" rails credentials:edit
```

Add the following structure:

```yaml
google:
  .env will send separtly 
```

**To obtain credentials:**

- **Google OAuth**: Visit [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → Credentials
- **Gemini API**: Visit [Google AI Studio](https://makersuite.google.com/app/apikey)

### 4. Setup Database

```bash
rails db:create
rails db:migrate
```

### 5. Start the Application

```bash
bin/dev
```

Or use Rails server directly:

```bash
rails server
```

The application will be available at `http://localhost:3000`

## Running Tests

### Run All Tests (RSpec + Cucumber)

```bash
bundle exec rspec
bundle exec cucumber --strict
```

### Run Tests with Coverage Report

```bash
COVERAGE=true bundle exec rspec && bundle exec cucumber --strict
open coverage/index.html
```

### Run Individual Test Suites

**RSpec only:**
```bash
bundle exec rspec
```

**Cucumber only:**
```bash
bundle exec cucumber --strict
```

**Specific feature file:**
```bash
bundle exec cucumber features/dashboard.feature
```

**Specific scenario:**
```bash
bundle exec cucumber features/dashboard.feature:25
```

### Test Coverage

Current test coverage: **85.9% line coverage**, 69.97% branch coverage

- **37 Cucumber scenarios** (37 passing)
- **343 Cucumber steps** (343 passing)
- **RSpec tests** covering models, controllers, services, and views

## Usage Guide

### First-Time Setup

1. Visit `http://localhost:3000`
2. Click "Connect Gmail" to authenticate with Google
3. Grant Gmail read permissions to the application

### Adding Warranties

**Manual Entry:**
1. Expand "Add a product warranty" section
2. Fill in product details (product name required)
3. Click "Add warranty"

**Gmail Parsing:**
1. Ensure Gmail is connected
2. Click "Parse Gmail Receipts"
3. System will automatically extract warranty information from receipts

### Managing Warranties

**Edit:**
- Click the ✏️ (edit) button next to any warranty
- Update details in the modal
- Click "Save Changes"

**Delete:**
- Click the 🗑️ (delete) button next to any warranty
- Warranty will be removed immediately

**Filter/Search:**
- Use the filter bar to search by product/merchant name
- Filter by status (Active, Expired, Expiring Soon)
- Filter by merchant
- Sort by expiry date, product name, purchase date, or merchant
- Click "Apply" to apply filters
- Click "Reset" to clear all filters

**Export:**
- **CSV**: Click "⬇️ Export CSV" to download all warranties
- **iCal**: Click "📅 Export iCal" with optional reminder checkboxes

## Project Structure

```
warranty-buddy/
├── app/
│   ├── controllers/        # Application controllers
│   ├── models/            # ActiveRecord models
│   ├── services/          # Service layer (Gmail, AI, parsing)
│   ├── views/             # ERB templates
│   └── javascript/        # Frontend JavaScript
├── config/
│   ├── routes.rb          # Application routes
│   ├── database.yml       # Database configuration
│   └── initializers/      # App initializers (OmniAuth, etc.)
├── db/
│   ├── migrate/           # Database migrations
│   └── schema.rb          # Database schema
├── features/              # Cucumber feature files
│   ├── dashboard.feature  # Main dashboard scenarios
│   └── step_definitions/  # Cucumber step definitions
├── spec/                  # RSpec tests
│   ├── models/           # Model tests
│   ├── requests/         # Request/controller tests
│   ├── services/         # Service tests
│   └── views/            # View tests
└── README.md             # This file
```

## Key Services

### AiService
Interfaces with Google Gemini AI for:
- Receipt text parsing
- Warranty information lookup
- Warranty eligibility checking

### GmailService
Handles Gmail integration:
- Fetching receipt emails
- Parsing email content
- Extracting order information

### ReceiptProcessor
Processes receipt images using OCR (Tesseract) and extracts structured data.

### MerchantParsers
Specialized parsers for different merchants:
- Amazon
- Best Buy
- eBay
- Target
- Walmart

## API Endpoints

- `GET /` - Dashboard (main page)
- `POST /upload` - Add warranty manually
- `POST /parse_gmail_receipts` - Parse Gmail receipts
- `PATCH /warranties/:id` - Update warranty
- `DELETE /warranties/:id` - Delete warranty
- `GET /products/export.csv` - Export to CSV
- `GET /products/calendar` - Export to iCal
- `GET /auth/google_oauth2` - Initiate OAuth
- `GET /auth/google_oauth2/callback` - OAuth callback
- `POST /disconnect_gmail` - Disconnect Gmail
- `GET /dashboard/api_health` - API health check
- `GET /dashboard/api_warranties` - Get warranties as JSON

## Troubleshooting

### Database Connection Issues
```bash
# Ensure PostgreSQL is running
brew services start postgresql@14

# Recreate database
rails db:drop db:create db:migrate
```

### Test Failures
```bash
# Ensure test database is set up
RAILS_ENV=test rails db:create db:migrate

# Clear test cache
rm -rf tmp/cache/
```

### OAuth Issues
- Verify credentials are correctly set in `rails credentials:edit`
- Ensure redirect URI matches Google Cloud Console settings
- Check that OAuth consent screen is configured

## Development

### Running in Development Mode

```bash
bin/dev
```

This starts:
- Rails server
- Asset compilation (if configured)
- Background jobs (if configured)

### Code Quality Tools

```bash
# Run RuboCop (linter)
bin/rubocop

# Run Brakeman (security scanner)
bin/brakeman

# Run Bundler Audit (dependency security)
bin/bundler-audit
```

## Deployment

The application is configured for deployment with Kamal. See `config/deploy.yml` for deployment settings.

## Contributing

1. Create a feature branch from `maria` branch
2. Make your changes
3. Run tests: `bundle exec rspec && bundle exec cucumber --strict`
4. Ensure coverage remains above 85%
5. Push to your branch
6. Create a pull request

## License

This project is part of a university course assignment.

## Support

For issues or questions, please contact the team members listed above.
