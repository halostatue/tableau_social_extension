# TableauSocialExtension Usage Rules

TableauSocialExtension is a Tableau extension that replaces HTML tags with
social media profile links.

## Core Behavior

Processes two tag types in HTML content:

1. `<dl social-block></dl>` - Generates a definition list with all configured
   social accounts
2. `<a social-{platform}>` - Generates individual social links

Configuration comes from site config merged with page frontmatter overrides.

## Configuration Format

```elixir
config :tableau, TableauSocialExtension,
  accounts: [
    # Simple username
    github: "username",
    twitter: "username",
    
    # Email-style for federated platforms
    mastodon: "user@instance.social",
    pixelfed: "user@pixelfed.social",
    
    # Numeric ID with username
    stack_overflow: "12345/username",
    
    # Multiple accounts per platform
    github_work: "work-username",
    mastodon_alt: "alt@other.instance"
  ],
  css_prefix: "social",  # optional, default: "social"
  labels: %{             # optional, for social-block display
    github: "GitHub",
    mastodon: "Mastodon"
  }
```

## Account Format by Platform Type

- **Standard platforms** (GitHub, Twitter, LinkedIn, etc.): `"username"`
- **Federated platforms** (Mastodon, Pixelfed, PeerTube):
  `"user@instance.domain"`
- **Numeric ID platforms** (Stack Overflow): `"12345/username"`
- **Reddit**: `"username"` (just username)
- **Custom/unknown**: Full URL `"https://platform.com/user"`

## Tag Usage

### Social Block

```html
<dl social-block></dl>
```

Generates definition list with all configured accounts. Each platform gets:

- `<dt>` with platform label
- `<dd>` with links for all accounts of that platform

### Individual Links

```html
<!-- Uses first configured account -->
<a social-github>Custom Text</a>

<!-- Uses specific account identifier -->
<a social-github="different-user">Text</a>

<!-- Uses alternate account from config (github_work) -->
<a social-github-work>Work Profile</a>
```

**Important**: Attribute value is the account identifier itself, not a config
lookup key. `social-github="user"` uses "user" as the GitHub username directly.

## Frontmatter Overrides

```yaml
---
title: About
social:
  github: page-specific-username
  mastodon: different@instance.social
---
```

Frontmatter merges with site config. Only specified platforms are overridden.

## Generated HTML Structure

### Social Block Output

```html
<dl class="social-block">
  <dt class="social-platform-label social-platform-github">GitHub</dt>
  <dd class="social-links social-platform-github">
    <a
      href="https://github.com/username"
      class="social-link social-platform-github"
      rel="nofollow noopener noreferrer"
    >username</a>
  </dd>
</dl>
```

### Individual Link Output

```html
<a
  href="https://github.com/username"
  class="social-link social-platform-github"
  rel="nofollow noopener noreferrer"
>Custom Text</a>
```

## CSS Classes

All classes use configurable prefix (default `"social"`):

- Blocks: `{prefix}-block`
- Labels: `{prefix}-platform-label`, `{prefix}-platform-{name}`
- Link containers: `{prefix}-links`, `{prefix}-platform-{name}`
- Links: `{prefix}-link`, `{prefix}-platform-{name}`

## Privacy & Security

- `rel="nofollow noopener noreferrer"` is always added (cannot be disabled)
- Custom `rel` values are merged with required privacy attributes
- All URLs validated through platform handlers

## Common Issues

1. **Platform not configured**: Using `<a social-platform>` without
   corresponding account in config generates error in development mode

2. **Invalid account format**: Each platform requires specific format (username,
   email-style, numeric ID, etc.)

3. **Modifier syntax**: `<a social-github-work>` requires `github_work` key in
   config, not `github` with modifier

4. **Empty social blocks**: `<dl social-block>` with no configured accounts
   generates empty `<dl>` element

5. **CSS prefix changes all classes**: Changing `:css_prefix` updates every
   generated class name

## Resources

- [Platform Reference](guides/platform-reference.md) - All supported platforms
  and their account formats; includes section on extending for custom platforms
- [Styling Guide](guides/styling.md) - Complete HTML structure and CSS examples
- [HexDocs](https://hexdocs.pm/tableau_social_extension) - Full API
  documentation
