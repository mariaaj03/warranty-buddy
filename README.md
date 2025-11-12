# Warranty Buddy

Your Digital Memory for Every Purchase

## Team Members

- **Maria Aswad Janoo** - [maj2198]
- **Gilad Bregman** - [gb2862]
- **Danielle Reich** - [dr3368]
- **Kalei Ragland** - [kar2247]

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

- Ruby 3.2.2
- PostgreSQL 14 or higher
- Bundler (`gem install bundler` if not installed)

## Setup Instructions

### 1. Clone and Checkout Branch

```bash
git clone https://github.com/mariaaj03/warranty-buddy.git
cd warranty-buddy
git checkout iteration2
```

### 2. Install Dependencies

```bash
bundle install
```

### 3. Set Up Database

```bash
rails db:create
rails db:migrate
```

### 4. Get Master Key

You need the `config/master.key` file to decrypt credentials. Get this from a team member or create new credentials:

```bash
# If you have the master.key file, copy it to config/master.key
# Otherwise, create new credentials:
rm config/credentials.yml.enc
EDITOR="nano" rails credentials:edit
```

### 5. Set Up Google API Credentials

**You need to create your own Google Cloud project and API keys for local development.**

#### Step 5a: Create Google Cloud Project and Enable APIs

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project
3. Enable these APIs (APIs & Services → Library):
   - Gmail API
   - Cloud Vision API
   - Vision AI API
   - Google Calendar API
   - Google+ API
   - People API
   - Gemini API
   - AI Studio API

#### Step 5b: Create OAuth Credentials

1. Go to "APIs & Services" → "Credentials"
2. Click "Create Credentials" → "OAuth client ID"
3. Configure OAuth consent screen (if prompted):
   - User type: External
   - App name: Warranty Buddy
   - Add your email for support and developer contact
   - Save and continue through all steps
4. Create OAuth client:
   - Application type: Web application
   - **Authorized JavaScript origins** (add both):
     - `http://localhost:3000`
     - `https://safe-reef-46455-4dc844325c04.herokuapp.com`
   - **Authorized redirect URIs** (add both):
     - `http://localhost:3000/users/auth/google_oauth2/callback`
     - `https://safe-reef-46455-4dc844325c04.herokuapp.com/users/auth/google_oauth2/callback`
   - Click "Create"
   - **Copy Client ID and Client Secret**

#### Step 5c: Get API Key

1. In "APIs & Services" → "Credentials", create the API key 
2. Copy the API key - **this same key works for both Gemini and Vision APIs** (they're in the same Google Cloud project)

#### Step 5d: Add Credentials to Rails

```bash
EDITOR="nano" rails credentials:edit
```

Add this structure (replace with your actual keys):

```yaml
google:
  client_id: YOUR_CLIENT_ID_HERE
  client_secret: YOUR_CLIENT_SECRET_HERE
  gemini_api_key: YOUR_API_KEY_HERE
  vision_api_key: YOUR_API_KEY_HERE
```

**Note:** Use the same API key for both `gemini_api_key` and `vision_api_key` since they're from the same Google Cloud project.

Save and exit (Ctrl+X, Y, Enter in nano).

Verify it worked:
```bash
rails credentials:show
```

### 6. Start the Server

```bash
rails server
```

Visit **http://localhost:3000**

## Using the App

1. Sign up or sign in
2. Click "Connect Gmail" to link your Gmail account
3. Add warranties manually or upload receipt images
4. Use "Parse Gmail Receipts" to automatically extract warranties from emails

## Running Tests

```bash
bundle exec rspec
bundle exec cucumber
open coverage/index.html  # View coverage report
```

## Viewing the Deployed App

The app is deployed on Heroku and can be accessed at:
**https://safe-reef-46455-4dc844325c04.herokuapp.com**

## Troubleshooting

**Database errors?**
```bash
brew services start postgresql@14  # macOS
```

**Master key missing?**
- Get `config/master.key` from a team member, or create new credentials (see Step 4)

**Gmail not connecting?**
- Verify redirect URI in Google Cloud Console: `http://localhost:3000/users/auth/google_oauth2/callback`
- Make sure Gmail API is enabled
- Restart server after updating credentials

**API key errors?**
- Check keys in `rails credentials:show`
- Restart server after changes
