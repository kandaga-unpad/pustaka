# Welcome to VOILE Documentation

**Virtual Organized Information & Library Ecosystem**

VOILE is a next-generation digital library management system designed to bridge the gap between traditional library heritage and modern information technology. Built with **Elixir** and **Phoenix**, VOILE leverages high concurrency, fault tolerance, and real-time performance to offer a robust, scalable platform for organizing, preserving, and accessing a vast range of literary, cultural, and artistic content.

---

## Quick Start

New to VOILE? Start here:

- [Environment Setup](getting-started/environment-setup.md) - Set up your development environment
- [Admin User Setup](getting-started/admin-user.md) - Create your first admin user
- [Seeds Setup](getting-started/seeds-setup.md) - Populate initial data

---

## Documentation Sections

### 🚀 Getting Started

Everything you need to get VOILE up and running.

- [Environment Setup](getting-started/environment-setup.md)
- [Admin User Setup](getting-started/admin-user.md)
- [Seeds Setup](getting-started/seeds-setup.md)

### 🏗️ Architecture

Understand the system design and data flow.

- [Architecture Overview](architecture/overview.md)
- [Data Flow Diagrams](architecture/data-flow.md)

### 📚 Features

Detailed documentation for each major feature.

#### Catalog & Circulation

- [Catalog Module Guide](features/catalog/module-guide.md)
- [Circulation Module Guide](features/circulation/module-guide.md)

#### GLAM (Gallery, Library, Archive, Museum)

- [GLAM Dashboard Guide](features/glam/dashboard-guide.md)
- [GLAM Manual](features/glam/manual.md)

#### Attachments

- [Attachment Access Control](features/attachments/index.md)
- [Quick Reference](features/attachments/quick-reference.md)
- [Manager Quickstart](features/attachments/manager-quickstart.md)

#### Inventory Management

- [Stock Opname Design](features/stock-opname/design.md)
- [Stock Opname Quick Reference](features/stock-opname/quick-reference.md)

#### Collection Review

- [Review Process](features/collection-review/process.md)
- [Quick Reference](features/collection-review/quick-reference.md)

#### Transfer Locations

- [Transfer Location Guide](features/transfers/location-guide.md)
- [Quick Reference](features/transfers/quick-reference.md)

#### Visitor Management

- [Visitor Management](features/visitor-management/index.md)
- [Quick Start](features/visitor-management/quick-start.md)

#### OAI-PMH (Metadata Harvesting)

- [OAI-PMH Overview](features/oai-pmh/index.md)
- [Quickstart](features/oai-pmh/quickstart.md)
- [Metadata Mapping](features/oai-pmh/metadata-mapping.md)

#### Plugin System

- [Plugin Overview](features/plugins/index.md)
- [Developer Guide](features/plugins/developer-guide.md)
- [User Guide](features/plugins/user-guide.md)

### 🔐 Authentication & Authorization

Security and access control documentation.

- [Auth System](authentication/auth-system.md)
- [RBAC Guide](authentication/rbac-complete-guide.md)
- [Role Management Guide](authentication/role-management-guide.md)
- [Permission Management Quick Reference](authentication/permission-management-quick-ref.md)

### 🔌 Integrations

Third-party service integrations.

#### Email

- [Gmail API Quickstart](integrations/email/gmail-api-quickstart.md)
- [Gmail API Complete Setup](integrations/email/gmail-api-complete.md)
- [Email Queue](integrations/email/email-queue.md)

#### Payments

- [Xendit Integration](integrations/payments/xendit-integration.md)
- [Xendit Quickstart](integrations/payments/xendit-quickstart.md)

### 🌐 Internationalization

Multi-language support documentation.

- [i18n Guide](internationalization/i18n-guide.md)
- [Quick Reference](internationalization/quick-reference.md)

### ⚙️ Configuration

System configuration guides.

- [Node Loan Rules](configuration/node-loan-rules.md)
- [Node Management](configuration/node-management.md)
- [Storage Auto Selection](configuration/storage-auto-selection.md)

### 🚢 Deployment

Deployment and CI/CD documentation.

- [CI Deployment](deployment/ci-deploy.md)
- [Podman Deployment](deployment/podman-deployment.md)

### 📖 Reference

Technical references and developer guides.

- [Quick Reference](reference/quick-reference.md)
- [Migration Guide](reference/migration-guide.md)
- [Database Enhancements](reference/database-enhancements.md)
 - [CSV Import Guide](reference/quick-reference.md)

### 🔮 Roadmap

Future plans and AI readiness.

- [AI Preparedness Review](roadmap/ai-preparedness.md)

---

## Technology Stack

**Server:**

- Elixir `v1.18.0`
- Phoenix `v1.8`
- Erlang (BEAM VM) `OTP 27.1`
- PostgreSQL `14 or newer`

**Client:**

- Phoenix LiveView
- Tailwind CSS

---

## License

VOILE is licensed under the **Apache License 2.0**.

---

## Contributing

For development guidelines, please refer to the `AGENTS.md` file in the repository root.