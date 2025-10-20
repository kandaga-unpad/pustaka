defmodule VoileWeb.Dashboard.Glam.Library.Ledger.Index do
  use VoileWeb, :live_view_dashboard

  alias Voile.Repo
  alias Voile.Schema.Accounts.User

  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Library Ledger")
      |> assign(:search_query, "")
      |> assign(:search_results, [])
      |> assign(:show_dropdown, false)
      |> assign(:selected_member, nil)
      |> assign(:search_error, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("search_input", %{"value" => query}, socket) do
    query = String.trim(query)

    if query == "" do
      socket =
        socket
        |> assign(:search_query, "")
        |> assign(:search_results, [])
        |> assign(:show_dropdown, false)
        |> assign(:selected_member, nil)
        |> assign(:search_error, nil)

      {:noreply, socket}
    else
      results = search_members(query)

      socket =
        socket
        |> assign(:search_query, query)
        |> assign(:search_results, results)
        |> assign(:show_dropdown, true)
        |> assign(:search_error, if(results == [], do: "No members found", else: nil))

      {:noreply, socket}
    end
  end

  def handle_event("select_member", %{"member_id" => member_id}, socket) do
    case Repo.get(User, member_id) |> Repo.preload([:user_type]) do
      nil ->
        {:noreply, put_flash(socket, :error, "Member not found")}

      member ->
        socket =
          socket
          |> assign(:selected_member, member)
          |> assign(:show_dropdown, false)
          |> assign(:search_error, nil)

        {:noreply, socket}
    end
  end

  def handle_event("clear_selection", _params, socket) do
    socket =
      socket
      |> assign(:selected_member, nil)
      |> assign(:search_query, "")
      |> assign(:search_results, [])
      |> assign(:show_dropdown, false)

    {:noreply, socket}
  end

  def handle_event("continue_transaction", %{"member_id" => member_id}, socket) do
    case Repo.get(User, member_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Member not found")}

      member ->
        if is_member_expired?(member) do
          {:noreply, put_flash(socket, :error, "Cannot continue: Member has expired")}
        else
          {:noreply,
           push_navigate(socket, to: ~p"/manage/glam/library/ledger/transact/#{member_id}")}
        end
    end
  end

  defp is_member_expired?(member) do
    case member.expiry_date do
      nil -> false
      expiry_date -> Date.compare(expiry_date, Date.utc_today()) == :lt
    end
  end

  defp search_members(query) do
    # Search by identifier, fullname, or email
    query_pattern = "%#{query}%"

    User
    |> where(
      [u],
      ilike(u.fullname, ^query_pattern) or
        ilike(u.email, ^query_pattern) or
        fragment("CAST(? AS TEXT) LIKE ?", u.identifier, ^query_pattern)
    )
    |> where([u], not is_nil(u.identifier))
    |> limit(10)
    |> order_by([u], asc: u.fullname)
    |> preload([:user_type])
    |> Repo.all()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.breadcrumb items={[
      %{label: "Manage", path: ~p"/manage"},
      %{label: "GLAM", path: ~p"/manage/glam"},
      %{label: "Library", path: ~p"/manage/glam/library"},
      %{label: "Ledgers", path: nil}
    ]} />
    <div class="sm:flex sm:items-center sm:justify-between mb-6">
      <.back navigate="/manage/glam/library">Back</.back>
      
      <div class="text-center flex-1">
        <h1 class="text-2xl font-bold">Start Library Transactions</h1>
        
        <p class="mt-2 text-sm text-gray-700 dark:text-gray-300">
          Search for a member to start circulation transactions
        </p>
      </div>
      
      <div class="w-24"></div>
    </div>

    <div class="max-w-4xl mx-auto mt-8">
      <%!-- Search Section --%>
      <%= if is_nil(@selected_member) do %>
        <div class="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-8">
          <div class="text-center mb-6">
            <.icon
              name="hero-magnifying-glass"
              class="w-16 h-16 mx-auto text-indigo-600 dark:text-indigo-400 mb-4"
            />
            <h2 class="text-xl font-semibold text-gray-900 dark:text-white">Find Member</h2>
            
            <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
              Search by identifier, name, or email
            </p>
          </div>
          
          <div class="space-y-4 relative">
            <div>
              <label
                for="member-search"
                class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2"
              >
                Search Member
              </label>
              <input
                type="text"
                id="member-search"
                value={@search_query}
                phx-keyup="search_input"
                phx-debounce="300"
                class="w-full px-4 py-3 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 dark:bg-gray-700 dark:text-white text-lg"
                placeholder="Type identifier, name, or email..."
                autocomplete="off"
                autofocus
              />
            </div>
             <%!-- Dropdown Results --%>
            <%= if @show_dropdown and @search_results != [] do %>
              <div class="absolute z-10 w-full mt-1 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg shadow-lg max-h-96 overflow-y-auto">
                <div class="py-2">
                  <div :for={member <- @search_results} class="relative">
                    <button
                      type="button"
                      phx-click="select_member"
                      phx-value-member_id={member.id}
                      class="w-full text-left px-4 py-3 hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
                    >
                      <div class="flex items-center justify-between">
                        <div class="flex-1">
                          <p class="font-medium text-gray-900 dark:text-white">
                            {member.fullname || "Unnamed Member"}
                          </p>
                          
                          <div class="flex items-center gap-3 mt-1 text-sm text-gray-500 dark:text-gray-400">
                            <span class="flex items-center gap-1">
                              <.icon name="hero-identification" class="w-4 h-4" /> {if member.identifier,
                                do: Decimal.to_string(member.identifier),
                                else: "No ID"}
                            </span>
                            <span class="flex items-center gap-1">
                              <.icon name="hero-envelope" class="w-4 h-4" /> {member.email}
                            </span>
                          </div>
                          
                          <%= if member.user_type do %>
                            <span class="inline-block mt-1 px-2 py-1 text-xs rounded-full bg-indigo-100 dark:bg-indigo-900 text-indigo-800 dark:text-indigo-200">
                              {member.user_type.name}
                            </span>
                          <% end %>
                        </div>
                         <.icon name="hero-chevron-right" class="w-5 h-5 text-gray-400" />
                      </div>
                    </button>
                  </div>
                </div>
              </div>
            <% end %>
            
            <%= if not is_nil(@search_error) and @search_query != "" and not @show_dropdown do %>
              <div class="rounded-md bg-yellow-50 dark:bg-yellow-900/20 p-4">
                <div class="flex">
                  <div class="flex-shrink-0">
                    <.icon name="hero-exclamation-triangle" class="h-5 w-5 text-yellow-400" />
                  </div>
                  
                  <div class="ml-3">
                    <p class="text-sm font-medium text-yellow-800 dark:text-yellow-200">
                      {@search_error}
                    </p>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
          
          <div class="mt-6 text-center text-sm text-gray-500 dark:text-gray-400">
            <p>
              <.icon name="hero-information-circle" class="w-4 h-4 inline mr-1" />
              Start typing to see matching members
            </p>
          </div>
        </div>
      <% else %>
        <%!-- Member Profile Preview --%>
        <div class="bg-white dark:bg-gray-800 rounded-lg shadow-lg overflow-hidden">
          <%!-- Header --%>
          <div class="bg-gradient-to-r from-indigo-600 to-blue-600 px-8 py-6">
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-4">
                <div class="w-20 h-20 rounded-full bg-white dark:bg-gray-700 flex items-center justify-center">
                  <.icon name="hero-user" class="w-10 h-10 text-indigo-600 dark:text-indigo-400" />
                </div>
                
                <div>
                  <h2 class="text-2xl font-bold text-white">
                    {@selected_member.fullname || "Unnamed Member"}
                  </h2>
                  
                  <p class="text-indigo-100 mt-1">
                    {if @selected_member.user_type,
                      do: @selected_member.user_type.name,
                      else: "No Member Type"}
                  </p>
                </div>
              </div>
              
              <button
                phx-click="clear_selection"
                class="text-white hover:text-indigo-100 transition-colors"
                title="Change member"
              >
                <.icon name="hero-x-mark" class="w-6 h-6" />
              </button>
            </div>
          </div>
           <%!-- Member Details --%>
          <div class="px-8 py-6">
            <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
              Member Information
            </h3>
            
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div class="flex items-start gap-3">
                <.icon name="hero-identification" class="w-5 h-5 text-gray-400 mt-0.5" />
                <div>
                  <p class="text-sm font-medium text-gray-500 dark:text-gray-400">Identifier</p>
                  
                  <p class="mt-1 text-base text-gray-900 dark:text-white">
                    {if @selected_member.identifier,
                      do: Decimal.to_string(@selected_member.identifier),
                      else: "N/A"}
                  </p>
                </div>
              </div>
              
              <div class="flex items-start gap-3">
                <.icon name="hero-envelope" class="w-5 h-5 text-gray-400 mt-0.5" />
                <div>
                  <p class="text-sm font-medium text-gray-500 dark:text-gray-400">Email</p>
                  
                  <p class="mt-1 text-base text-gray-900 dark:text-white">
                    {@selected_member.email || "N/A"}
                  </p>
                </div>
              </div>
              
              <div class="flex items-start gap-3">
                <.icon name="hero-phone" class="w-5 h-5 text-gray-400 mt-0.5" />
                <div>
                  <p class="text-sm font-medium text-gray-500 dark:text-gray-400">Phone</p>
                  
                  <p class="mt-1 text-base text-gray-900 dark:text-white">
                    {@selected_member.phone_number || "N/A"}
                  </p>
                </div>
              </div>
              
              <div class="flex items-start gap-3">
                <.icon name="hero-building-office" class="w-5 h-5 text-gray-400 mt-0.5" />
                <div>
                  <p class="text-sm font-medium text-gray-500 dark:text-gray-400">Organization</p>
                  
                  <p class="mt-1 text-base text-gray-900 dark:text-white">
                    {@selected_member.organization || "N/A"}
                  </p>
                </div>
              </div>
              
              <div class="flex items-start gap-3">
                <.icon name="hero-calendar" class="w-5 h-5 text-gray-400 mt-0.5" />
                <div>
                  <p class="text-sm font-medium text-gray-500 dark:text-gray-400">
                    Registration Date
                  </p>
                  
                  <p class="mt-1 text-base text-gray-900 dark:text-white">
                    {if @selected_member.registration_date,
                      do: Calendar.strftime(@selected_member.registration_date, "%B %d, %Y"),
                      else: "N/A"}
                  </p>
                </div>
              </div>
              
              <div class="flex items-start gap-3">
                <.icon name="hero-clock" class="w-5 h-5 text-gray-400 mt-0.5" />
                <div>
                  <p class="text-sm font-medium text-gray-500 dark:text-gray-400">Expiry Date</p>
                  
                  <p class="mt-1 text-base text-gray-900 dark:text-white">
                    <%= if @selected_member.expiry_date do %>
                      {Calendar.strftime(@selected_member.expiry_date, "%B %d, %Y")}
                      <%= if Date.compare(@selected_member.expiry_date, Date.utc_today()) == :lt do %>
                        <span class="ml-2 text-xs px-2 py-1 rounded-full bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200">
                          Expired
                        </span>
                      <% end %>
                    <% else %>
                      N/A
                    <% end %>
                  </p>
                </div>
              </div>
              
              <%= if @selected_member.address do %>
                <div class="flex items-start gap-3 md:col-span-2">
                  <.icon name="hero-map-pin" class="w-5 h-5 text-gray-400 mt-0.5" />
                  <div>
                    <p class="text-sm font-medium text-gray-500 dark:text-gray-400">Address</p>
                    
                    <p class="mt-1 text-base text-gray-900 dark:text-white">
                      {@selected_member.address}
                    </p>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
           <%!-- Action Buttons --%>
          <div class="px-8 py-6 bg-gray-50 dark:bg-gray-900 border-t border-gray-200 dark:border-gray-700">
            <%= if @selected_member.expiry_date && Date.compare(@selected_member.expiry_date, Date.utc_today()) == :lt do %>
              <div class="rounded-md bg-red-50 dark:bg-red-900/20 p-4 mb-4">
                <div class="flex">
                  <div class="flex-shrink-0">
                    <.icon name="hero-exclamation-triangle" class="h-5 w-5 text-red-400" />
                  </div>
                  
                  <div class="ml-3">
                    <h3 class="text-sm font-medium text-red-800 dark:text-red-200">Member Expired</h3>
                    
                    <p class="mt-1 text-sm text-red-700 dark:text-red-300">
                      This member's account expired on {Calendar.strftime(
                        @selected_member.expiry_date,
                        "%B %d, %Y"
                      )}.
                      You cannot continue with transactions for expired members.
                    </p>
                  </div>
                </div>
              </div>
            <% end %>
            
            <div class="flex gap-4 justify-end">
              <.button
                phx-click="clear_selection"
                class="bg-gray-500 hover:bg-gray-600 text-white px-6 py-3 rounded-lg font-semibold"
              >
                <.icon name="hero-arrow-left" class="w-5 h-5 mr-2" /> Change Member
              </.button>
              <.button
                phx-click="continue_transaction"
                phx-value-member_id={@selected_member.id}
                disabled={
                  @selected_member.expiry_date &&
                    Date.compare(@selected_member.expiry_date, Date.utc_today()) == :lt
                }
                class={[
                  "px-8 py-3 rounded-lg font-semibold shadow-lg",
                  if(
                    @selected_member.expiry_date &&
                      Date.compare(@selected_member.expiry_date, Date.utc_today()) == :lt,
                    do: "bg-gray-400 cursor-not-allowed text-gray-200",
                    else: "bg-green-600 hover:bg-green-700 text-white"
                  )
                ]}
              >
                <.icon name="hero-arrow-right" class="w-5 h-5 mr-2" /> Continue to Transaction
              </.button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
