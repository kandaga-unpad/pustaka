defmodule VoileWeb.Users.ManageLive.Show do
  use VoileWeb, :live_view_dashboard

  alias Voile.Schema.Accounts
  alias VoileWeb.Utils.FormatIndonesiaTime

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = Accounts.get_user!(id)

    # do not assume edit modal is open yet; basic assigns for show
    socket =
      socket
      |> assign(user: user)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white dark:bg-gray-700 p-6 rounded-lg">
      <.header>
        User Profile
        <:subtitle>Personal and account information</:subtitle>
      </.header>
      
      <div class="flex items-center justify-between px-4">
        <.back navigate={~p"/manage/settings/users"}>Back to Users</.back>
        
        <div class="text-right">
          <.link patch={~p"/manage/settings/users/#{@user.id}/show/edit"} class="primary-btn">
            Edit
          </.link>
        </div>
      </div>
      
      <div class="w-full mx-auto mt-8">
        <div class="bg-white dark:bg-gray-900 shadow-xl rounded-xl p-8 flex flex-col items-center">
          <div class="mb-4">
            <%= if @user.user_image do %>
              <img
                src={@user.user_image}
                alt={@user.fullname || @user.username}
                class="w-32 h-32 rounded-full object-cover border-4 border-indigo-200 shadow"
                referrerpolicy="no-referrer"
              />
            <% else %>
              <div class="w-32 h-32 rounded-full bg-gray-200 flex items-center justify-center text-4xl font-bold text-gray-500 border-4 border-indigo-100">
                {String.first(@user.fullname || @user.username) |> String.upcase()}
              </div>
            <% end %>
          </div>
          
          <h2 class="text-2xl font-bold mb-1">{@user.fullname || @user.username}</h2>
          
          <div class="flex gap-2 mb-4">
            <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold bg-indigo-100 text-indigo-800">
              {if Ecto.assoc_loaded?(@user.user_role), do: @user.user_role.name, else: "-"}
            </span>
            <%= if @user.confirmed_at do %>
              <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold bg-green-100 text-green-800">
                Active
              </span>
            <% else %>
              <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold bg-yellow-100 text-yellow-800">
                Pending
              </span>
            <% end %>
          </div>
          
          <div class="w-full mt-4 grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <div class="text-gray-500 text-xs uppercase mb-1">Email</div>
              
              <div class="font-medium">{@user.email}</div>
            </div>
            
            <div>
              <div class="text-gray-500 text-xs uppercase mb-1">Username</div>
              
              <div class="font-medium">{@user.username}</div>
            </div>
            
            <%= if @user.identifier do %>
              <div>
                <div class="text-gray-500 text-xs uppercase mb-1">Identifier</div>
                
                <div class="font-medium">{@user.identifier}</div>
              </div>
            <% end %>
            
            <%= if Ecto.assoc_loaded?(@user.user_type) do %>
              <div>
                <div class="text-gray-500 text-xs uppercase mb-1">User Type</div>
                
                <div class="font-medium">{@user.user_type.name}</div>
              </div>
            <% end %>
            
            <%= if @user.groups && @user.groups != [] do %>
              <div class="col-span-2">
                <div class="text-gray-500 text-xs uppercase mb-1">Groups</div>
                
                <div class="flex flex-wrap gap-2">
                  <%= for group <- @user.groups do %>
                    <span class="inline-block bg-blue-100 text-blue-800 text-xs px-2 py-1 rounded">
                      {group}
                    </span>
                  <% end %>
                </div>
              </div>
            <% end %>
            
            <%= if @user.node_id do %>
              <div>
                <div class="text-gray-500 text-xs uppercase mb-1">Node ID</div>
                
                <div class="font-medium">{@user.node_id}</div>
              </div>
            <% end %>
            
            <div>
              <div class="text-gray-500 text-xs uppercase mb-1">Last Login</div>
              
              <div class="font-medium">
                <%= if @user.last_login do %>
                  {FormatIndonesiaTime.format_utc_to_jakarta(@user.last_login)}
                <% else %>
                  <span class="text-gray-400">Never</span>
                <% end %>
              </div>
            </div>
            
            <div>
              <div class="text-gray-500 text-xs uppercase mb-1">Last Login IP</div>
              
              <div class="font-medium">{@user.last_login_ip || "-"}</div>
            </div>
          </div>
          
          <div class="w-full mt-8">
            <div class="text-gray-500 text-xs uppercase mb-2">Social & Links</div>
            
            <div class="flex flex-wrap gap-4">
              <%= if @user.twitter do %>
                <a href={@user.twitter} class="text-blue-400 hover:underline" target="_blank">
                  Twitter
                </a>
              <% end %>
              
              <%= if @user.facebook do %>
                <a href={@user.facebook} class="text-blue-600 hover:underline" target="_blank">
                  Facebook
                </a>
              <% end %>
              
              <%= if @user.linkedin do %>
                <a href={@user.linkedin} class="text-blue-700 hover:underline" target="_blank">
                  LinkedIn
                </a>
              <% end %>
              
              <%= if @user.instagram do %>
                <a href={@user.instagram} class="text-pink-500 hover:underline" target="_blank">
                  Instagram
                </a>
              <% end %>
              
              <%= if @user.website do %>
                <a href={@user.website} class="text-gray-700 hover:underline" target="_blank">
                  Website
                </a>
              <% end %>
            </div>
          </div>
          
          <div class="w-full mt-8 text-xs text-gray-400 text-center">
            User ID: {@user.id} &middot; Created: {Calendar.strftime(
              @user.inserted_at,
              "%Y-%m-%d %H:%M"
            )} &middot; Updated: {Calendar.strftime(@user.updated_at, "%Y-%m-%d %H:%M")}
          </div>
        </div>
      </div>
      
      <.modal
        :if={@live_action in [:new, :edit]}
        id="user-modal"
        show
        on_cancel={JS.patch(~p"/manage/settings/users/#{@user.id}")}
      >
        <.live_component
          module={VoileWeb.Users.ManageLive.FormComponent}
          id={@user.id || :new}
          title={@page_title}
          action={@live_action}
          node_list={@node_list}
          user_type_options={@user_type_options}
          user={@user}
          patch={~p"/manage/settings/users/#{@user.id}"}
        />
      </.modal>
    </div>
    """
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    user = Accounts.get_user!(id)

    # When the live action is :edit or :new (modal open), ensure the
    # component props expected by the modal are present in assigns so
    # rendering doesn't crash with missing keys like :page_title.
    socket =
      case socket.assigns.live_action do
        :edit ->
          node_list = Voile.Schema.System.list_nodes()
          user_type_options = Voile.Schema.Master.list_mst_member_types()

          socket
          |> assign(user: user)
          |> assign(:page_title, "Edit User")
          |> assign(:node_list, node_list)
          |> assign(:user_type_options, user_type_options)

        :new ->
          node_list = Voile.Schema.System.list_nodes()
          user_type_options = Voile.Schema.Master.list_mst_member_types()

          socket
          |> assign(user: user)
          |> assign(:page_title, "New User")
          |> assign(:node_list, node_list)
          |> assign(:user_type_options, user_type_options)

        _ ->
          assign(socket, user: user)
      end

    {:noreply, socket}
  end
end
