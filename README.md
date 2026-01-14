## Overview

Welcome to the Patchwork. Developed and maintained by The Newsmast Foundation.

Patchwork is a plugin dashboard designed to enhance your Mastodon server with advanced features and a streamlined admin experience, making stewardship of a Mastodon server easier, safer and more fun.

## Features

#### Opt users in to search 

By default, Mastodon users have to opt-in to allowing their profile and public posts to be indexed during searches. Patchwork enables the admin to choose whether all new users are opted-in to Search when they join. Users can always opt out if they choose.
#### Custom post length

Choose the maximum number of characters you want a post to be.
#### Auto-Bluesky bridge

Automatically bridge new users to Bluesky via Bridgy Fed. Users can always opt out if they choose. Please note, bridging takes place two weeks after the account has been created.
#### Spam block

Block spam posts arriving on your server from the federated network. Filters identify keywords or phrases associated with spam in a post. Create your own list for customised filters.
#### Content filters

Block harmful content arriving on your server from the federated network. Filters identify keywords or phrases in lists of words for specific harms eg. NSFW, Hate speech etc. Each list can be toggled on or off. Create your own list for customised filters.
#### Channel Management

Channel Types: Support for multiple channel types including Channels, Channel Feeds, Hubs, and Newsmast channels.
Content Types: Configure channels as hashtag-based, contributor-based, group channels, or custom channels with flexible content rules.
Community Rules: Define and display community guidelines and rules for each channel.
Additional Information: Add custom headings and text blocks to provide context for channel visitors.
Social & General Links: Configure sidebar links to external resources, social media profiles, and related content.
#### Channel Content Curation

Hashtag-Based Content: Populate channels with content from specific hashtags across the Fediverse.
Contributor Management: Add, search, and manage contributors who can post to channels.
Mute Contributors: Mute specific accounts from appearing in channel feeds.
Relay Integration: Connect to relay services like relay.fedi.buzz for hashtag content distribution.
Post Boosting: Automatic boosting of posts through designated boost bot accounts.
#### Customise email branding

Replace the Mastodon logo in automatic emails with your own. This feature allows you to add your own header image, footer image and accent colour.

## Installing Patchwork

Find full instructions on how to install Patchwork on your Mastodon server [here](https://github.com/patchwork-hub/patchwork_dashboard/wiki/Installation-guide).

Patchwork works as a plugin dashboard for existing Mastodon servers. If you have not already installed Mastodon, please do so now.

Before running Patchwork, please ensure you have set up a Mastodon server and it is running properly.

You can find the instructions to set up a Mastodon server [here](https://docs.joinmastodon.org/admin/install/).

## Development

### Prerequisites
- Ruby (check `.ruby-version` for required version)
- PostgreSQL
- Redis

### Setup

1. Clone the repository and install dependencies:
```bash
git clone https://github.com/patchwork-hub/patchwork_dashboard.git
cd patchwork_dashboard
bin/setup
```

2. Configure environment variables:
```bash
cp .env.sample .env
# Edit .env with your configuration
```

3. Set up the database:
```bash
bundle exec rails db:create
bundle exec rails db:migrate
bundle exec rails db:seed
```

4. Start the development server:
```bash
bundle exec rails server
```

### Code Quality Tools

The project includes several development tools:
- **Bullet**: N+1 query detection
- **Rack Mini Profiler**: Request profiling
- **RuboCop**: Ruby style guide enforcement
- **AnnotateRB**: Schema annotation for models

## The Newsmast Foundation

The Newsmast Foundation is a UK based charity, building digital infrastructure to empower communities with social media they control.

We’ve built apps for news publishers, place based communities and NGO activists to create meaningful online connections.

Visit our website to learn [more](https://www.newsmastfoundation.org/).

For support in installing Patchwork, or for more information on our partnerships, please contact us at support@newsmastfoundation.org

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/patchwork-hub/patchwork_dashboard. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the code of conduct.

## Licenses

Patchwork is an open source project, licensed under AGPL-3.0. Have fun!

## Code of Conduct
Everyone interacting in the Patchwork Dashboard project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the code of conduct.

