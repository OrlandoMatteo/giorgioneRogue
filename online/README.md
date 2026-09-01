# Online leaderboard setup

1. Create a Supabase project.
2. Open **SQL Editor**, paste `supabase_schema.sql`, and run it once.
3. In **Settings → API Keys**, copy the client-safe **Publishable key**. Never use a Secret or `service_role` key in this project.
4. Edit `leaderboard_config.json` with the project URL and publishable key.
5. Export the Web build again and push `docs/` to GitHub Pages.

The game creates a username if it is new and reuses the existing player when the normalized username already exists. This deliberately provides no account security: entering an existing username selects that player.

The local player ID and username are stored in `user://giorgiones_feast_save.json`. They survive normal game and PWA updates because the save path and website origin stay unchanged. **Dimentica giocatore** removes the identity manually. Clearing site data, changing the GitHub Pages domain/path, browser privacy cleanup, or uninstall behavior controlled by the OS can also remove it.

Failed score submissions remain queued locally and are retried the next time the game starts with a network connection.
