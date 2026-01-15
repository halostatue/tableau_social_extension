# TableauSocialExtension

[![Hex.pm][shield-hex]][hexpm] [![Hex Docs][shield-docs]][docs]
[![Apache 2.0][shield-licence]][licence] ![Coveralls][shield-coveralls]

- code :: <https://github.com/halostatue/tableau_social_extension>
- issues :: <https://github.com/halostatue/tableau_social_extension/issues>

A [Tableau][tableau] extension that replaces HTML tags containing specific
attributes with rendered social profile links based on site extension
configuration and content frontmatter.

## Overview

The Social Extension processes `<dl social-block>` and `<a social-{platform}>`
tags in your HTML content and replaces them with properly formatted social media
links.

## Configuration

Basic configuration uses simple string values for usernames:

```elixir
config :tableau, TableauSocialExtension,
  accounts: [
    github: "username",
    mastodon: "user@mastodon.social",
    stack_overflow: "12345/username"
  ]
```

For advanced configuration, see the
[Platform Reference](guides/platform-reference.md).

## Installation

TableauSocialExtension can be installed by adding `tableau_social_extension` to
your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tableau_social_extension, "~> 1.0"}
  ]
end
```

Documentation is found on [HexDocs][docs].

## Semantic Versioning

TableauSocialExtension follows [Semantic Versioning 2.0][semver].

[docs]: https://hexdocs.pm/tableau_social_extension
[hexpm]: https://hex.pm/packages/tableau_social_extension
[licence]: https://github.com/halostatue/tableau_social_extension/blob/main/LICENCE.md
[semver]: https://semver.org/
[shield-coveralls]: https://img.shields.io/coverallsCoverage/github/halostatue/tableau_social_extension?style=for-the-badge
[shield-docs]: https://img.shields.io/badge/hex-docs-lightgreen.svg?style=for-the-badge "Hex Docs"
[shield-hex]: https://img.shields.io/hexpm/v/tableau_social_extension?style=for-the-badge "Hex Version"
[shield-licence]: https://img.shields.io/hexpm/l/tableau_social_extension?style=for-the-badge&label=licence "Apache 2.0"
[tableau]: https://hex.pm/packages/tableau
