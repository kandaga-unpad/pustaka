# Authentication & Authorization

This section covers the security and access control systems in VOILE, including authentication, role-based access control (RBAC), and permission management.

## Overview

VOILE uses a comprehensive Role-Based Access Control (RBAC) system that provides:

- **Role-Based Permissions**: Assign permissions to roles, then assign roles to users
- **Direct User Permissions**: Grant or deny specific permissions to individual users
- **Scoped Permissions**: Apply permissions globally or to specific resources
- **Permission Hierarchy**: Explicit denials override role-based grants
- **Time-Based Permissions**: Support for expiring permissions and role assignments
- **Collection-Level Permissions**: Fine-grained control over collection access

## Core Documentation

### Authentication System

Understand how the authentication system works, including user sessions, login flows, and security measures.

[Read the Auth System Guide →](auth-system.md)

### RBAC Guide

Learn about the Role-Based Access Control system, including how to check permissions in LiveViews and controllers.

[Read the RBAC Guide →](rbac-complete-guide.md)

### Quick Reference

A quick reference for common permission checks and authorization patterns.

[View Quick Reference →](rbac-quick-reference.md)

## Role Management

Guides for managing user roles:

- [Role Management Guide](role-management-guide.md) - Complete guide for role management
- [Role Management Quick Reference](role-management-quick-ref.md) - Quick reference card
 - [Role Management Quick Reference](role-management-quick-ref.md) - Quick reference card

## Permission Management

Guides for managing permissions:

- [Permission Management Quick Reference](permission-management-quick-ref.md) - Quick reference card
 

## RBAC Implementation Details

Technical documentation for RBAC implementation:

 - [RBAC Implementation Summary](rbac-implementation-summary.md) - Summary of what was built

## Additional Topics

- [Custom Unauthorized Redirects](custom-redirects.md) - Customize redirect behavior for unauthorized access

## Default Roles

VOILE comes with 5 pre-configured roles:

| Role | Description | Permission Count |
|------|-------------|------------------|
| `super_admin` | Full system access | 27 permissions |
| `admin` | Administrative access (no system settings) | 16 permissions |
| `editor` | Can manage collections and items | 11 permissions |
| `contributor` | Can create and edit own content | 5 permissions |
| `viewer` | Read-only access | 3 permissions |

## Quick Usage Examples

### Checking Permissions in LiveView

```elixir
defmodule VoileWeb.CollectionLive.Show do
  use VoileWeb, :live_view

  def mount(%{"id" => id}, _session, socket) do
    # Check if user can read this collection
    if can?(socket, "collections.read", scope: {:collection, id}) do
      {:ok, assign(socket, collection: get_collection(id))}
    else
      {:ok, redirect(socket, to: "/")}
    end
  end
end
```

### Checking Permissions in Templates

```heex
<%= if can?(@socket, "collections.update") do %>
  <.button navigate={~p"/collections/#{@collection.id}/edit"}>
    Edit Collection
  </.button>
<% end %>
```

### Using Authorization Plug in Controllers

```elixir
defmodule VoileWeb.CollectionController do
  use VoileWeb, :controller

  plug VoileWeb.Plugs.Authorization,
    permission: "collections.read"

  plug VoileWeb.Plugs.Authorization,
    permission: "collections.delete"
    when action in [:delete]

  # ... actions
end
```

## Related Documentation

- [Admin User Setup](../getting-started/admin-user.md) - Setting up the first admin user
- [Seeds Setup](../getting-started/seeds-setup.md) - Seeding roles and permissions