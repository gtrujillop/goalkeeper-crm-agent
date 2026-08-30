# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :store_crm,
  namespace: StoreCRM,
  ecto_repos: [StoreCRM.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true],
  start_oban: true

config :store_crm, Oban,
  repo: StoreCRM.Repo,
  queues: [
    inbound_messages: 5,
    agent_runs: 3,
    outbound_messages: 5,
    integrations: 3,
    lifecycle: 1
  ]

# Configure the endpoint
config :store_crm, StoreCRMWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: StoreCRMWeb.ErrorHTML, json: StoreCRMWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: StoreCRM.PubSub,
  live_view: [signing_salt: "AoDIFerX"]

# Configure LiveView
config :phoenix_live_view,
  # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
  root_tag_attribute: "phx-r"

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  store_crm: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.3.0",
  store_crm: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :store_crm, :whatsapp, adapter: StoreCRM.Messaging.Fake, graph_api_version: "v26.0"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
