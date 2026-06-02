# 🦕 Deno Edge Function - VS Code Setup

## TypeScript Errors in Editor?

If you see TypeScript errors like "Cannot find module 'https://deno.land/std@0.168.0/http/server.ts'" or "Cannot find name 'Deno'", don't worry - **these are false positives**. The code will work perfectly when deployed to Supabase.

## Why the Errors?

VS Code's default TypeScript checker doesn't know about Deno's runtime environment. Deno is different from Node.js and has built-in support for:
- Importing from URLs (https://deno.land/...)
- Global `Deno` namespace for environment variables
- Web-standard APIs (Request, Response, fetch, etc.)

## Solution: Install Deno Extension

### Step 1: Install Deno Extension
1. Open VS Code Extensions (Ctrl+Shift+X / Cmd+Shift+X)
2. Search for "Deno"
3. Install **"Deno" by denoland** (official extension)
4. Reload VS Code

### Step 2: Enable Deno for This Workspace
The configuration is already set up in `.vscode/settings.json`:
```json
{
  "deno.enable": true,
  "deno.lint": true,
  "deno.unstable": true
}
```

### Step 3: Verify
After installing the extension and reloading:
- Open `supabase/functions/notify-activation-request/index.ts`
- TypeScript errors should disappear
- You'll see Deno-specific IntelliSense

## Alternative: Ignore the Errors

If you don't want to install the Deno extension:
- The errors are **cosmetic only** - your code is correct
- When you deploy via `supabase functions deploy`, it will work perfectly
- Supabase uses Deno runtime which has all the required types

## Testing Locally (Optional)

If you want to test the Edge Function locally:

```bash
# Install Deno CLI
# Windows (PowerShell):
irm https://deno.land/install.ps1 | iex

# macOS/Linux:
curl -fsSL https://deno.land/install.sh | sh

# Test the function locally
cd supabase/functions/notify-activation-request
deno run --allow-net --allow-env index.ts
```

## Deploying to Supabase

The TypeScript errors **do not affect deployment**:

```bash
# Deploy the function (no Deno extension needed)
supabase functions deploy notify-activation-request

# The function will run perfectly in Supabase's Deno runtime
```

## Summary

| Scenario | Action Needed |
|----------|---------------|
| **Just want to deploy** | Nothing - ignore VS Code errors and deploy normally |
| **Want clean editor** | Install Deno extension from VS Code marketplace |
| **Want to test locally** | Install Deno CLI and run with `deno run` |

---

**TL;DR:** The TypeScript errors are harmless. Install the Deno extension if you want them to go away, or just ignore them and deploy as usual.
