# ex_bifrost

[![Hex.pm](https://img.shields.io/hexpm/v/ex_bifrost.svg)](https://hex.pm/packages/ex_bifrost)
[![Documentation](https://img.shields.io/badge/hexdocs-ex__bifrost-blue.svg)](https://hexdocs.pm/ex_bifrost)
[![CI](https://github.com/houllette/ex_bifrost/actions/workflows/test.yml/badge.svg)](https://github.com/houllette/ex_bifrost/actions/workflows/test.yml)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

Elixir SDK for Bifrost, the LLM gateway by Maxim

## Installation

Add `ex_bifrost` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_bifrost, "~> 0.1.0"}
  ]
end
```

## Configuration

```elixir
# config/runtime.exs
config :ex_bifrost,
  base_url: System.get_env("API_BASE_URL", "http://localhost:8080")
```

## Usage

```elixir
# Create a connection to your Bifrost gateway
conn = ExBifrost.Connection.new(base_url: "http://localhost:8080")

# Send a chat completion through the gateway — responses decode into
# typed model structs
request = %ExBifrost.Model.ChatCompletionRequest{
  model: "openai/gpt-4o-mini",
  messages: [%{role: "user", content: "Hello from Elixir!"}]
}

{:ok, %ExBifrost.Model.ChatCompletionResponse{choices: choices}} =
  ExBifrost.Api.ChatCompletions.create_chat_completion(conn, request)

# Other gateway features are available under ExBifrost.Api.*, e.g.
# Providers, Models, Embeddings, Files, Governance, and MCP
{:ok, models} = ExBifrost.Api.Models.list_models(conn)
```

## Development

```bash
./scripts/regenerate.sh   # regenerate from openapi-spec.yaml
mix check                 # full quality gate (mirrors CI)
mix dialyzer              # type check
```

## Documentation

- [API Documentation](https://hexdocs.pm/ex_bifrost)
- [Changelog](CHANGELOG.md)

## License

See [LICENSE](LICENSE) for details.

---

**Generated with ❤️ using the [Elixir SDK Generator](https://github.com/houllette/elixir-sdk-generator) template**
