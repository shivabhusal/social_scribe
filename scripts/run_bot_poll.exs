#!/usr/bin/env elixir

# Script to immediately run bot status polling (not via Oban queue)
# Usage: mix run scripts/run_bot_poll.exs

alias SocialScribe.Workers.BotStatusPoller

IO.puts("Running bot status polling immediately...")

# Create a dummy job struct for the perform function
job = %Oban.Job{
  id: 0,
  args: %{},
  worker: "SocialScribe.Workers.BotStatusPoller",
  queue: "polling",
  state: "available"
}

case BotStatusPoller.perform(job) do
  :ok ->
    IO.puts("✓ Bot polling completed successfully")

  {:error, reason} ->
    IO.puts("✗ Bot polling failed: #{inspect(reason)}")
    System.halt(1)
end
