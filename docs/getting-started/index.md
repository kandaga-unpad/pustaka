# Getting Started

Welcome to VOILE! This section will guide you through setting up and configuring your development environment.

## Prerequisites

Before you begin, make sure you have the following installed:

- **Elixir** `v1.18.0` or later
- **Erlang/OTP** `27.1` or later
- **PostgreSQL** `14` or newer
- **Node.js** (for asset compilation)

## Setup Guides

### 1. Environment Setup

Set up your development environment with the correct configuration files and environment variables.

[Read the Environment Setup Guide →](environment-setup.md)

### 2. Admin User Setup

Create your first administrator account and understand the default credentials.

[Read the Admin User Guide →](admin-user.md)

### 3. Seeds Setup

Populate the database with initial data including permissions, roles, and sample content.

[Read the Seeds Setup Guide →](seeds-setup.md)

## Quick Start

For the fastest setup, run these commands:

```bash
# Clone the repository
git clone https://github.com/chrisnaadhi/voile.git
cd voile

# Install dependencies
mix deps.get

# Setup database (creates, migrates, and seeds)
mix ecto.setup

# Install Node.js dependencies and build assets
mix assets.setup
mix assets.build

# Start the Phoenix server
mix phx.server
```

Then visit [`http://localhost:4000`](http://localhost:4000) in your browser.

## Default Login Credentials

After running seeds, you can log in with:

- **Email**: `admin@voile.id`
- **Password**: `super_long_password`

!!! warning
    **Change the default password immediately** after your first login!

## Next Steps

After completing the setup:

1. [Explore the Architecture](../architecture/overview.md) to understand the system design
2. [Review the Catalog Module](../features/catalog/module-guide.md) to manage collections
3. [Configure Authentication](../authentication/auth-system.md) for proper access control

## Troubleshooting

If you encounter issues during setup:

1. Ensure all prerequisites are installed correctly
2. Check that PostgreSQL is running and accessible
3. Verify your environment variables are set correctly
4. Review the terminal output for specific error messages

For more help, check the [Reference](../reference/quick-reference.md) section.