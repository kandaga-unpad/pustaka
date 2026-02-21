# Plugin User Guide

A guide for librarians, archivists, and staff on using plugins in Voile.

---

## What Are Plugins?

Plugins are optional add-ons that extend Voile's capabilities. They allow your institution to add specialized features without needing to modify the core system.

### Examples of Plugins

| Plugin | What It Does |
|--------|--------------|
| **Locker Management** | Track visitor locker assignments and availability |
| **ISBN Enrichment** | Automatically fetch book metadata from external databases |
| **Exhibit Scheduler** | Plan and schedule museum/gallery exhibitions |
| **Digitization Tracker** | Monitor digitization progress for archival materials |
| **Custom Reports** | Generate specialized reports for your institution |

---

## Accessing Plugin Management

1. Log in to Voile with an admin account
2. Navigate to **Settings → Plugins** 
3. Or go directly to: `/manage/plugins`

You'll see a list of all available plugins with their current status.

---

## Understanding Plugin Status

Each plugin displays a status badge indicating its current state:

| Status | Color | What It Means |
|--------|-------|---------------|
| **INSTALLED** | Blue | Plugin is installed but not yet active |
| **ACTIVE** | Green | Plugin is running and fully functional |
| **INACTIVE** | Gray | Plugin is deactivated but data is preserved |
| **ERROR** | Red | Something went wrong (contact IT) |
| **UNINSTALLED** | Gray | Plugin has been removed |

---

## Managing Plugins

### Installing a New Plugin

!!! warning "Deployment Required"
    Before a plugin appears in the management interface, your IT team must:
    
    1. Add the plugin to Voile's dependencies
    2. Rebuild and redeploy Voile (Docker/Podman container or mix release)
    3. Restart the server
    
    This is a one-time deployment step. After that, you can install, activate, and deactivate the plugin without server restarts.

Once a plugin has been deployed to the system:

1. Go to **Settings → Plugins**
2. Find the plugin in the list
3. Click **Install**
4. Wait for installation to complete
5. Click **Activate** to enable the plugin

### Activating a Plugin

Activation makes a plugin functional:

1. Find the installed plugin
2. Click **Activate**
3. The plugin's features become available immediately

!!! tip
    Plugins automatically reactivate after server restarts. You only need to activate once.

### Deactivating a Plugin

Deactivation temporarily disables a plugin while keeping its data:

1. Find the active plugin
2. Click **Deactivate**
3. The plugin stops working but all data is preserved

Use deactivation when:
- You want to temporarily stop using a feature
- You're troubleshooting an issue
- You need to perform maintenance

### Uninstalling a Plugin

Uninstalling removes a plugin from the system:

1. Deactivate the plugin first (if active)
2. Click **Uninstall**
3. Confirm the action

!!! warning "Data Preservation"
    By default, uninstalling preserves all plugin data. If you want to completely remove all data, check with your IT team first.

---

## Configuring Plugin Settings

Many plugins have configurable settings that you can adjust.

### Accessing Settings

1. Go to **Settings → Plugins**
2. Find the active plugin
3. Click **Settings**

### Common Setting Types

| Setting Type | Description |
|--------------|-------------|
| **Text Field** | Enter text (e.g., API keys, URLs) |
| **Number** | Enter a numeric value |
| **Checkbox** | Enable or disable a feature |
| **Dropdown** | Select from predefined options |

### Saving Settings

1. Make your changes
2. Click **Save Settings**
3. Changes take effect immediately

!!! tip "Sensitive Information"
    Settings marked as "sensitive" (like API keys) are stored securely. They won't be displayed in plain text after saving.

---

## Using Plugin Features

### Dashboard Widgets

Active plugins can add widgets to your main dashboard. These appear as additional cards showing plugin-specific information.

### Navigation Menu Items

Plugins can add items to the sidebar navigation under **Plugins**. Look for new menu items after activating a plugin.

### Plugin Pages

Each plugin has its own section at:

```
/manage/plugins/[plugin-name]/
```

Access these pages through:
- The sidebar menu (if the plugin adds navigation)
- The **Settings** link on the plugin management page

---

## Troubleshooting

### Plugin Shows Error Status

If a plugin shows a red **ERROR** status:

1. Click on the plugin to see the error message
2. Contact your IT support team
3. Provide them with the error message

### Plugin Features Not Working

1. Verify the plugin is in **ACTIVE** status
2. Check that settings are configured correctly
3. Try deactivating and reactivating the plugin
4. Contact IT support if issues persist

### Missing Plugin You Expected

If you heard about a plugin but don't see it:

- It may not be installed in your system yet
- Contact your IT team to request installation
- Plugins must be added by technical staff

---

## Best Practices

### For Librarians

1. **Test First**: When a new plugin is installed, test it thoroughly before relying on it for critical workflows
2. **Document Settings**: Keep a record of your plugin settings for backup purposes
3. **Regular Review**: Periodically review active plugins and deactivate any you're not using
4. **Report Issues**: Report any problems to IT support promptly

### For Department Heads

1. **Evaluate Needs**: Before requesting plugins, clearly define what functionality you need
2. **Training**: Ensure staff are trained on new plugin features before deployment
3. **Data Backup**: Understand what data plugins store and ensure it's included in regular backups
4. **Access Control**: Work with IT to ensure appropriate staff have access to plugin management

---

## Frequently Asked Questions

### Can I install any plugin I find?

No. Plugins must be specifically developed for Voile and installed by your IT team. Only use plugins from trusted sources.

### Will plugins slow down Voile?

Well-designed plugins have minimal impact. The plugin system is built to be efficient. If you notice performance issues, report them to IT.

### What happens to plugin data if I deactivate?

All data is preserved when you deactivate a plugin. When you reactivate, everything will be as you left it.

### Can I export plugin data?

This depends on the specific plugin. Check the plugin's documentation or ask your IT team about data export options.

### Who do I contact for plugin support?

- **Technical issues**: Contact your IT support team
- **Feature requests**: Contact your IT team or the plugin developer
- **Training**: Check with your department head or IT for training resources

---

## Quick Reference Card

| Action | Where | Result |
|--------|-------|--------|
| View all plugins | Settings → Plugins | See installed and available plugins |
| Activate | Click "Activate" button | Plugin becomes functional |
| Deactivate | Click "Deactivate" button | Plugin stops but data is kept |
| Configure | Click "Settings" button | Adjust plugin options |
| View plugin pages | Sidebar or /manage/plugins/[name] | Access plugin features |

---

## Getting Help

If you need assistance with plugins:

1. **Check this documentation** for answers
2. **Contact your IT support team** for technical issues
3. **Check plugin-specific documentation** if available
4. **Report bugs** to help improve the system
