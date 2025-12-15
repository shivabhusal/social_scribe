#!/usr/bin/env elixir

# Script to manually trigger bot status polling
# Usage: mix run scripts/trigger_bot_poll.exs

alias SocialScribe.Workers.BotStatusPoller

IO.puts("Triggering bot status polling...")

case BotStatusPoller.new(%{}) |> Oban.insert() do
  {:ok, job} ->
    IO.puts("✓ Successfully enqueued bot polling job (ID: #{job.id})")
    IO.puts("  Queue: #{job.queue}")
    IO.puts("  State: #{job.state}")
    IO.puts("\nThe job will be processed by Oban workers.")

  {:error, reason} ->
    IO.puts("✗ Failed to enqueue bot polling job: #{inspect(reason)}")
    System.halt(1)
end
