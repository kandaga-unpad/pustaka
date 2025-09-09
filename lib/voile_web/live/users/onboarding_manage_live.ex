defmodule VoileWeb.Users.OnboardingManageLive do
  use VoileWeb, :live_view

  import Ecto.Query
  alias Voile.Schema.Accounts
  alias Voile.Repo

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <.header>
          Member Onboarding Management
          <:subtitle>
            Send onboarding emails to migrated members who need to set their passwords
          </:subtitle>
        </.header>
        
        <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <div class="flex">
            <.icon name="hero-exclamation-triangle" class="h-5 w-5 text-yellow-400" />
            <div class="ml-3">
              <h3 class="text-sm font-medium text-yellow-800">
                Migrated Members Requiring Onboarding
              </h3>
              
              <p class="mt-2 text-sm text-yellow-700">
                These members were migrated from the previous system and need to set up their passwords.
                They currently have the default password "changeme123" and need to confirm their accounts.
              </p>
            </div>
          </div>
        </div>
        
        <div class="flex justify-between items-center">
          <div class="text-sm text-gray-600">
            Found <strong>{length(@unconfirmed_users)}</strong> users needing onboarding
          </div>
          
          <div class="space-x-2">
            <.button
              phx-click="send_all_onboarding_emails"
              phx-disable-with="Sending emails..."
              class="bg-blue-600 hover:bg-blue-700"
              disabled={length(@unconfirmed_users) == 0}
            >
              Send All Onboarding Emails
            </.button>
            <.button
              phx-click="refresh_list"
              class="bg-gray-600 hover:bg-gray-700"
            >
              <.icon name="hero-arrow-path" class="w-4 h-4 mr-2" /> Refresh
            </.button>
          </div>
        </div>
        
        <div class="bg-white shadow rounded-lg">
          <div class="px-4 py-5 sm:p-6">
            <div class="flow-root">
              <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
                <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
                  <table class="min-w-full divide-y divide-gray-300">
                    <thead>
                      <tr>
                        <th class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900">
                          User Information
                        </th>
                        
                        <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                          Registration Date
                        </th>
                        
                        <th class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">
                          Status
                        </th>
                        
                        <th class="relative py-3.5 pl-3 pr-4 text-right text-sm font-semibold text-gray-900">
                          Actions
                        </th>
                      </tr>
                    </thead>
                    
                    <tbody class="divide-y divide-gray-200">
                      <%= for user <- @unconfirmed_users do %>
                        <tr>
                          <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm">
                            <div class="flex items-center">
                              <div class="h-10 w-10 flex-shrink-0">
                                <div class="h-10 w-10 rounded-full bg-gray-300 flex items-center justify-center">
                                  <span class="text-sm font-medium text-gray-700">
                                    {String.first(user.fullname || user.email) |> String.upcase()}
                                  </span>
                                </div>
                              </div>
                              
                              <div class="ml-4">
                                <div class="font-medium text-gray-900">{user.fullname || "N/A"}</div>
                                
                                <div class="text-gray-500">{user.email}</div>
                                
                                <div class="text-xs text-gray-400">@{user.username}</div>
                              </div>
                            </div>
                          </td>
                          
                          <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                            <%= if user.inserted_at do %>
                              {Calendar.strftime(user.inserted_at, "%Y-%m-%d")}
                            <% else %>
                              N/A
                            <% end %>
                          </td>
                          
                          <td class="whitespace-nowrap px-3 py-4 text-sm">
                            <span class="inline-flex rounded-full bg-red-100 px-2 text-xs font-semibold leading-5 text-red-800">
                              Needs Onboarding
                            </span>
                          </td>
                          
                          <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium">
                            <.button
                              phx-click="send_onboarding_email"
                              phx-value-user-id={user.id}
                              class="btn text-sm bg-blue-600 hover:bg-blue-700"
                            >
                              Send Email
                            </.button>
                          </td>
                        </tr>
                      <% end %>
                      
                      <%= if length(@unconfirmed_users) == 0 do %>
                        <tr>
                          <td colspan="4" class="px-6 py-12 text-center text-sm text-gray-500">
                            <.icon name="hero-check-circle" class="mx-auto h-12 w-12 text-green-400" />
                            <h3 class="mt-2 text-sm font-medium text-gray-900">
                              All members onboarded!
                            </h3>
                            
                            <p class="mt-1 text-sm text-gray-500">
                              All migrated members have completed their onboarding process.
                            </p>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    unconfirmed_users = get_unconfirmed_migrated_users()

    {:ok, assign(socket, :unconfirmed_users, unconfirmed_users)}
  end

  def handle_event("send_onboarding_email", %{"user-id" => user_id}, socket) do
    user = Accounts.get_user!(user_id)

    case Accounts.deliver_onboarding_instructions(user, &url(~p"/users/onboarding/#{&1}")) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Onboarding email sent successfully to #{user.email}")
         |> assign(:unconfirmed_users, get_unconfirmed_migrated_users())}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "Failed to send onboarding email to #{user.email}: #{inspect(reason)}"
         )}
    end
  end

  def handle_event("send_all_onboarding_emails", _params, socket) do
    users = socket.assigns.unconfirmed_users

    if length(users) == 0 do
      {:noreply, put_flash(socket, :info, "No users need onboarding emails.")}
    else
      # Send emails in batches to avoid overwhelming the email service
      {success_count, error_count} = send_batch_onboarding_emails(users)

      message =
        cond do
          error_count == 0 ->
            "Successfully sent #{success_count} onboarding emails!"

          success_count == 0 ->
            "Failed to send all #{error_count} emails. Please check your email configuration."

          true ->
            "Sent #{success_count} emails successfully, #{error_count} failed."
        end

      flash_type = if error_count > 0, do: :warning, else: :info

      {:noreply,
       socket
       |> put_flash(flash_type, message)
       |> assign(:unconfirmed_users, get_unconfirmed_migrated_users())}
    end
  end

  def handle_event("refresh_list", _params, socket) do
    {:noreply,
     socket
     |> assign(:unconfirmed_users, get_unconfirmed_migrated_users())
     |> put_flash(:info, "User list refreshed")}
  end

  # Get users who were migrated (confirmed_at is nil) and have the default hash
  defp get_unconfirmed_migrated_users do
    # This is the hash for "changeme123" from the member_importer.ex
    default_hash =
      "$pbkdf2-sha512$160000$OmHm5yQ4w.ZGpn7fvUcGzg$uBPzZQ2UOQ2oZFJt9JQZhVqJQa2wC9.XqBZQv1.2qHZqJQa2wC9.XqBZQv1.2qHZqJQa2wC9.XqBZQv1.2qHZqJQa2wC9.X"

    from(u in Accounts.User,
      where: is_nil(u.confirmed_at) and u.hashed_password == ^default_hash,
      order_by: [desc: u.inserted_at],
      limit: 100
    )
    |> Repo.all()
  end

  defp send_batch_onboarding_emails(users) do
    Enum.reduce(users, {0, 0}, fn user, {success_count, error_count} ->
      case Accounts.deliver_onboarding_instructions(user, &url(~p"/users/onboarding/#{&1}")) do
        {:ok, _} -> {success_count + 1, error_count}
        {:error, _} -> {success_count, error_count + 1}
      end
    end)
  end
end
