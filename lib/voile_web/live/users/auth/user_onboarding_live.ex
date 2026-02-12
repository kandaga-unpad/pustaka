defmodule VoileWeb.UserOnboardingLive do
  use VoileWeb, :live_view

  alias Voile.Schema.Accounts

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-3xl px-4 py-12">
        <div class="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-8">
          <div class="text-center mb-8">
            <div class="inline-flex items-center justify-center w-16 h-16 bg-blue-100 dark:bg-blue-900 rounded-full mb-4">
              <.icon name="hero-user-circle" class="w-10 h-10 text-blue-600 dark:text-blue-400" />
            </div>

            <.header>
              {gettext("Complete Your Profile")}
              <:subtitle>
                {gettext("Tell us a bit about yourself to get started")}
              </:subtitle>
            </.header>
          </div>

          <.form
            for={@form}
            id="onboarding_form"
            phx-submit="save"
            phx-change="validate"
            class="space-y-6"
          >
            <%= if @user_type == :migrated_with_personal_email do %>
              <div class="bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg p-4 mb-6">
                <div class="flex items-start gap-3">
                  <.icon
                    name="hero-check-circle"
                    class="w-5 h-5 text-green-600 dark:text-green-400 flex-shrink-0 mt-0.5"
                  />
                  <div class="text-sm text-green-800 dark:text-green-300">
                    <p class="font-semibold mb-1">{gettext("Welcome Back!")}</p>
                    <p>
                      {gettext(
                        "Please fill these form with your personal details to complete your profile. We have accepted your registration, the last step is to complete your profile."
                      )}
                    </p>
                  </div>
                </div>
              </div>

              <.input
                field={@form[:email]}
                type="email"
                label={gettext("Email")}
                placeholder={gettext("your.email@example.com")}
                phx-debounce="300"
              />

              <.input
                field={@form[:identifier]}
                type="text"
                label={identifier_label(@form[:identifier].value)}
                readonly
                disabled
              />
            <% end %>

            <%= if @user_type == :institutional_new_user do %>
              <div class="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-4 mb-6">
                <div class="flex items-start gap-3">
                  <.icon
                    name="hero-academic-cap"
                    class="w-5 h-5 text-blue-600 dark:text-blue-400 flex-shrink-0 mt-0.5"
                  />
                  <div class="text-sm text-blue-800 dark:text-blue-300">
                    <p class="font-semibold mb-1">{gettext("Institutional Account Detected")}</p>
                    <p>
                      {gettext(
                        "Welcome! Please provide your Student ID (NPM) or Lecturer ID (NIP) to complete your profile."
                      )}
                    </p>
                  </div>
                </div>
              </div>

              <.input
                field={@form[:email]}
                type="email"
                label={gettext("Institutional Email")}
                readonly
                disabled
              />

              <.input
                field={@form[:identifier]}
                type="text"
                label={gettext("NPM (Student ID) / NIP (Lecturer ID)")}
                placeholder={gettext("Enter your 12-digit NPM or 15-16 digit NIP")}
                required
                phx-debounce="300"
              />
            <% end %>

            <%= if @user_type == :new_user do %>
              <div class="bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg p-4 mb-6">
                <div class="flex items-start gap-3">
                  <.icon
                    name="hero-check-circle"
                    class="w-5 h-5 text-green-600 dark:text-green-400 flex-shrink-0 mt-0.5"
                  />
                  <div class="text-sm text-green-800 dark:text-green-300">
                    <p class="font-semibold mb-1">{gettext("Welcome to Voile!")}</p>
                    <p>
                      {gettext(
                        "Complete your profile to unlock all features. A unique identifier has been assigned to you."
                      )}
                    </p>
                  </div>
                </div>
              </div>

              <.input
                field={@form[:email]}
                type="email"
                label={gettext("Email")}
                readonly
                disabled
                class="bg-gray-100 dark:bg-gray-700"
              />
            <% end %>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <.input
                field={@form[:fullname]}
                type="text"
                label={gettext("Full Name")}
                placeholder={gettext("Chrisna Adhi Pranoto")}
                required
              />

              <.input
                field={@form[:username]}
                type="text"
                label={gettext("Username")}
                placeholder={gettext("chrisnaadhi")}
                required
                disabled
              />
            </div>

            <.input
              field={@form[:phone_number]}
              type="tel"
              label={gettext("Phone Number")}
              placeholder={gettext("+62 812-3456-7890")}
              required
            />

            <.input
              field={@form[:address]}
              type="textarea"
              label={gettext("Address")}
              placeholder={gettext("Your complete address")}
              rows="3"
            />

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <.input
                field={@form[:birth_place]}
                type="text"
                label={gettext("Place of Birth")}
                placeholder={gettext("Jakarta")}
              />

              <.input
                field={@form[:birth_date]}
                type="date"
                label={gettext("Date of Birth")}
              />
            </div>

            <.input
              field={@form[:gender]}
              type="select"
              label={gettext("Gender")}
              options={[
                {gettext("Select Gender"), ""},
                {gettext("Male"), "male"},
                {gettext("Female"), "female"},
                {gettext("Other"), "other"}
              ]}
            />

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <.input
                field={@form[:organization]}
                type="text"
                label={gettext("Organization")}
                placeholder={gettext("Company or Institution")}
              />

              <.input
                field={@form[:department]}
                type="text"
                label={gettext("Department")}
                placeholder={gettext("Your department")}
              />
            </div>

            <.input
              field={@form[:position]}
              type="text"
              label={gettext("Position/Title")}
              placeholder={gettext("Your role or position")}
            />

            <div class="flex gap-4 pt-6">
              <.button
                type="submit"
                phx-disable-with={gettext("Saving...")}
                class="flex-1 bg-blue-600 hover:bg-blue-700 text-white font-semibold py-3 rounded-lg transition-colors"
              >
                <.icon name="hero-check" class="w-5 h-5 inline-block mr-2" /> {gettext(
                  "Complete Profile"
                )}
              </.button>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def mount(_params, session, socket) do
    user = socket.assigns.current_scope.user

    # Determine user type
    user_type = determine_user_type(user)

    # Generate identifier if needed
    user = maybe_generate_identifier(user, user_type)

    # Pre-fill from Google OAuth data if available
    google_user = session["google_user"]
    prefill_data = build_prefill_data(user, google_user)

    changeset = Accounts.change_user(user, prefill_data)

    {:ok,
     socket
     |> assign(user_type: user_type)
     |> assign_form(changeset)}
  end

  defp build_prefill_data(user, google_user) when is_map(google_user) do
    # Only pre-fill if user doesn't already have the data
    %{}
    |> maybe_add_fullname(user, google_user)
  end

  defp build_prefill_data(_user, _google_user), do: %{}

  defp maybe_add_fullname(prefill, user, google_user) do
    if (is_nil(user.fullname) and google_user["given_name"]) && google_user["family_name"] do
      fullname = "#{google_user["given_name"]} #{google_user["family_name"]}"
      Map.put(prefill, :fullname, fullname)
    else
      prefill
    end
  end

  defp determine_user_type(user) do
    is_institutional = is_institutional_email?(user.email)

    cond do
      # Institutional user needs to provide NPM/NIP (identifier)
      # This covers: Google OAuth with @unpad email OR registered with @unpad email
      is_institutional and is_nil(user.identifier) ->
        :institutional_new_user

      # User with identifier but using personal email (migrated user, alumni, etc.)
      # Allow them to keep personal email
      not is_nil(user.identifier) and not is_institutional ->
        :migrated_with_personal_email

      # User with identifier and institutional email (already complete)
      # This shouldn't reach onboarding, but handle gracefully
      not is_nil(user.identifier) and is_institutional ->
        :complete_profile

      # New user with personal email (Google OAuth or registration)
      true ->
        :new_user
    end
  end

  defp is_institutional_email?(email) when is_binary(email) do
    String.ends_with?(email, "@mail.unpad.ac.id") or String.ends_with?(email, "@unpad.ac.id")
  end

  defp is_institutional_email?(_), do: false

  defp identifier_label(nil), do: gettext("Identifier")

  defp identifier_label(value) when is_binary(value) do
    case String.length(value) do
      length when length >= 15 -> gettext("NIP (Lecturer ID)")
      length when length == 14 -> gettext("Number ID")
      length when length == 12 -> gettext("NPM (Student ID)")
      _ -> gettext("Identifier")
    end
  end

  defp identifier_label(value) do
    # Handle Decimal type
    str_value = to_string(value)

    case String.length(str_value) do
      length when length >= 15 -> gettext("NIP (Lecturer ID)")
      length when length == 14 -> gettext("Number ID")
      length when length == 12 -> gettext("NPM (Student ID)")
      _ -> gettext("Identifier")
    end
  end

  defp maybe_generate_identifier(user, user_type)
       when user_type in [:new_user] do
    if is_nil(user.identifier) do
      # Generate identifier: unix timestamp + random 4 digits
      timestamp = System.system_time(:second)
      random = :rand.uniform(9999) |> Integer.to_string() |> String.pad_leading(4, "0")
      identifier = "#{timestamp}#{random}" |> Decimal.new()

      # Update user with identifier
      case Accounts.update_profile_user(user, %{identifier: identifier}) do
        {:ok, updated_user} ->
          updated_user

        {:error, _changeset} ->
          # If update fails (e.g., password validation for OAuth users), just return user
          # The identifier will be set during onboarding completion
          user
      end
    else
      user
    end
  end

  defp maybe_generate_identifier(user, _user_type), do: user

  def handle_event("validate", %{"user" => user_params}, socket) do
    user = socket.assigns.current_scope.user

    changeset =
      user
      |> Accounts.change_user_onboarding(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    user = socket.assigns.current_scope.user
    user_type = socket.assigns.user_type

    # Validate email domain for migrated users with identifier
    user_params = validate_and_adjust_params(user_params, user_type, user)

    case Accounts.update_user_onboarding(user, user_params) do
      {:ok, updated_user} ->
        # Determine redirect path based on user type
        redirect_path =
          case updated_user.user_type do
            %{slug: slug} when slug in ["administrator", "staff"] -> "/manage"
            _ -> "/"
          end

        {:noreply,
         socket
         |> put_flash(:info, gettext("Profile completed successfully!"))
         |> push_navigate(to: redirect_path)}

      {:error, %Ecto.Changeset{} = changeset} ->
        require Logger
        Logger.error("Onboarding save failed: #{inspect(changeset.errors)}")

        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp validate_and_adjust_params(params, :migrated_with_personal_email, user) do
    # Allow email update but validate it's a valid email
    # User can keep personal email or switch to institutional
    case params["email"] do
      email when is_binary(email) and byte_size(email) > 0 ->
        params

      _ ->
        # Keep current email if empty
        Map.put(params, "email", user.email)
    end
  end

  defp validate_and_adjust_params(params, :institutional_new_user, _user) do
    # Validate identifier format for institutional users
    case params["identifier"] do
      identifier when is_binary(identifier) ->
        # Convert to Decimal for storage
        case Decimal.parse(identifier) do
          {decimal_value, ""} ->
            Map.put(params, "identifier", decimal_value)

          _ ->
            # Invalid number format, keep empty
            params
        end

      _ ->
        params
    end
  end

  defp validate_and_adjust_params(params, _user_type, _user), do: params

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, form: to_form(changeset))
  end
end
