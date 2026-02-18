# Copyright 2024 - Present © Chrisna Adhi Pranoto
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule Voile.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Build children list conditionally based on configuration
    base_children = [
      VoileWeb.Telemetry,
      Voile.Repo,
      {DNSCluster, query: Application.get_env(:voile, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Voile.PubSub},
      # Hammer 7.x rate limiter with ETS backend
      {Voile.RateLimiter, clean_period: :timer.minutes(10)},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Voile.Finch},
      # Supervisor for short-lived tasks (used by LiveViews for async work)
      {Task.Supervisor, name: Voile.TaskSupervisor}
    ]

    # Conditionally add email queue (disabled in dev if configured)
    email_queue_children =
      if Application.get_env(:voile, :disable_email_queue, false) do
        []
      else
        [
          # Start the email queue for rate-limited email sending
          Voile.Notifications.EmailQueue,
          # Start the loan reminder scheduler
          Voile.Task.LoanReminderScheduler,
          # Start the suspension expiry scheduler
          Voile.Task.SuspensionExpiryScheduler
        ]
      end

    children =
      base_children ++
        email_queue_children ++
        [
          # Start a worker by calling: Voile.Worker.start_link(arg)
          # {Voile.Worker, arg},
          # Start to serve requests, typically the last entry
          VoileWeb.Endpoint
        ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Voile.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    VoileWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
