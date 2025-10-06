defmodule VoileWeb.Router do
  use VoileWeb, :router

  import VoileWeb.UserAuth
  # import VoileWeb.UserAuthGoogle

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {VoileWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
    plug VoileWeb.Plugs.GetCurrentPath
    plug VoileWeb.Utils.SideBarMenuMaster
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", VoileWeb do
    pipe_through :browser
    # Convert home and about pages to LiveView for better UX

    # Search routes
    get "/search", SearchController, :index
    post "/search", SearchController, :index
    get "/search/advanced", SearchController, :advanced
    post "/search/advanced", SearchController, :advanced
    get "/search/suggestions", SearchController, :suggestions
    get "/api/search", SearchController, :api_search

    live_session :public_with_scope,
      on_mount: [{VoileWeb.UserAuth, :mount_current_scope}] do
      # Search dashboard (admin only)
      live "/", PageLive.Home, :index

      live "/about", PageLive.About, :index
      live "/search/dashboard", SearchDashboardLive, :index

      # LiveView search (optional alternative)
      live "/search/live", SearchLive, :index

      # Frontend member routes
      live "/collections", Frontend.Collections.Index, :index
      live "/collections/:id", Frontend.Collections.Show, :show
      live "/items", Frontend.Items.Index, :index
      live "/items/:id", Frontend.Items.Show, :show
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", VoileWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:voile, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: VoileWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", VoileWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{VoileWeb.UserAuth, :mount_current_scope}] do
      live "/register", UserRegistrationLive, :new
      live "/login", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end

    post "/users/log_in", UserSessionController, :create
    get "/users/login/:token", MagicLinkController, :login
    delete "/users/log_out", UserSessionController, :delete
  end

  scope "/", VoileWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_and_verified_member,
      on_mount: [
        {VoileWeb.UserAuth, :require_authenticated_and_verified_member},
        {VoileWeb.Utils.SaveRequestUri, :save_request_uri},
        {VoileWeb.UserAuth, :mount_current_scope}
      ] do
      # Frontend member routes that require authentication
      live "/atrium", Frontend.Atrium.Index, :index
    end
  end

  scope "/", VoileWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user_and_verified_staff_user,
      on_mount: [
        {VoileWeb.UserAuth, :require_authenticated_and_verified_staff_user},
        {VoileWeb.Utils.SaveRequestUri, :save_request_uri},
        {VoileWeb.Utils.SideBarMenuMaster, :master_menu}
      ] do
      scope "/manage" do
        live "/", DashboardLive, :index

        scope "/catalog" do
          live "/", Dashboard.Catalog.Index, :index

          scope "/collections" do
            live "/", Dashboard.Catalog.CollectionLive.Index, :index
            live "/new", Dashboard.Catalog.CollectionLive.Index, :new
            live "/:id/edit", Dashboard.Catalog.CollectionLive.Index, :edit

            live "/:id", Dashboard.Catalog.CollectionLive.Show, :show
            live "/:id/show/edit", Dashboard.Catalog.CollectionLive.Show, :edit
            live "/:id/attachments", Dashboard.Catalog.CollectionLive.Attachments, :attachments
          end

          scope "/items" do
            live "/", Dashboard.Catalog.ItemLive.Index, :index
            live "/new", Dashboard.Catalog.ItemLive.Index, :new
            live "/:id/edit", Dashboard.Catalog.ItemLive.Index, :edit

            live "/:id", Dashboard.Catalog.ItemLive.Show, :show
            live "/:id/show/edit", Dashboard.Catalog.ItemLive.Show, :edit
          end
        end

        scope "/circulation" do
          live "/", Dashboard.Circulation.Index, :index

          scope "/transactions" do
            live "/", Dashboard.Circulation.Transaction.Index, :index
            live "/checkout", Dashboard.Circulation.Transaction.Index, :checkout
            live "/:id/return", Dashboard.Circulation.Transaction.Index, :return
            live "/:id/renew", Dashboard.Circulation.Transaction.Index, :renew
            live "/:id", Dashboard.Circulation.Transaction.Show, :show
          end

          scope "/reservations" do
            live "/", Dashboard.Circulation.Reservation.Index, :index
            live "/new", Dashboard.Circulation.Reservation.Index, :new
            live "/:id", Dashboard.Circulation.Reservation.Show, :show
          end

          scope "/requisitions" do
            live "/", Dashboard.Circulation.Requisition.Index, :index
            live "/new", Dashboard.Circulation.Requisition.Index, :new
            live "/:id", Dashboard.Circulation.Requisition.Show, :show
            live "/:id/edit", Dashboard.Circulation.Requisition.Index, :edit
          end

          scope "/fines" do
            live "/", Dashboard.Circulation.Fine.Index, :index
            live "/new", Dashboard.Circulation.Fine.Index, :new
            live "/:id", Dashboard.Circulation.Fine.Show, :show
            live "/:id/payment", Dashboard.Circulation.Fine.Show, :payment
            live "/:id/waive", Dashboard.Circulation.Fine.Show, :waive
          end

          scope "/circulation_history" do
            live "/", Dashboard.Circulation.CirculationHistory.Index, :index
            live "/:id", Dashboard.Circulation.CirculationHistory.Show, :show
          end
        end

        scope "/master" do
          live "/", Dashboard.Master.MasterLive

          scope "/creators" do
            live "/", Dashboard.Master.CreatorLive.Index, :index
            live "/new", Dashboard.Master.CreatorLive.Index, :new
            live "/:id/edit", Dashboard.Master.CreatorLive.Index, :edit

            live "/:id", Dashboard.Master.CreatorLive.Show, :show
            live "/:id/show/edit", Dashboard.Master.CreatorLive.Show, :edit
          end

          scope "/publishers" do
            live "/", Dashboard.Master.PublisherLive.Index, :index
            live "/new", Dashboard.Master.PublisherLive.Index, :new
            live "/:id/edit", Dashboard.Master.PublisherLive.Index, :edit

            live "/:id", Dashboard.Master.PublisherLive.Show, :show
            live "/:id/show/edit", Dashboard.Master.PublisherLive.Show, :edit
          end

          scope "/member_types" do
            live "/", Dashboard.Master.MemberTypeLive.Index, :index
            live "/new", Dashboard.Master.MemberTypeLive.Index, :new
            live "/:id/edit", Dashboard.Master.MemberTypeLive.Index, :edit

            # We don't have a separate Show module for MemberType yet; map
            # the detail route to the Edit LiveView so row navigation works.
            live "/:id", Dashboard.Master.MemberTypeLive.Edit, :edit
            live "/:id/show/edit", Dashboard.Master.MemberTypeLive.Edit, :edit
          end

          scope "/frequencies" do
            live "/", Dashboard.Master.FrequencyLive.Index, :index
            live "/new", Dashboard.Master.FrequencyLive.Index, :new
            live "/:id/edit", Dashboard.Master.FrequencyLive.Index, :edit

            # Map detail route to Edit liveview
            live "/:id", Dashboard.Master.FrequencyLive.Edit, :edit
            live "/:id/show/edit", Dashboard.Master.FrequencyLive.Edit, :edit
          end

          scope "/locations" do
            live "/", Dashboard.Master.LocationsLive.Index, :index
            live "/new", Dashboard.Master.LocationsLive.Index, :new
            live "/:id/edit", Dashboard.Master.LocationsLive.Index, :edit

            live "/:id", Dashboard.Master.LocationsLive.Edit, :edit
            live "/:id/show/edit", Dashboard.Master.LocationsLive.Edit, :edit
          end

          scope "/places" do
            live "/", Dashboard.Master.PlacesLive.Index, :index
            live "/new", Dashboard.Master.PlacesLive.Index, :new
            live "/:id/edit", Dashboard.Master.PlacesLive.Index, :edit

            live "/:id", Dashboard.Master.PlacesLive.Edit, :edit
            live "/:id/show/edit", Dashboard.Master.PlacesLive.Edit, :edit
          end

          scope "/topics" do
            live "/", Dashboard.Master.TopicLive.Index, :index
            live "/new", Dashboard.Master.TopicLive.Index, :new
            live "/:id/edit", Dashboard.Master.TopicLive.Index, :edit

            live "/:id", Dashboard.Master.TopicLive.Edit, :edit
            live "/:id/show/edit", Dashboard.Master.TopicLive.Edit, :edit
          end
        end

        scope "/metaresource" do
          live "/", Dashboard.Metaresource.MetaresourceLive
          resources "/metadata_vocabularies", VocabularyController
          resources "/metadata_properties", PropertyController
          resources "/resource_class", ResourceClassController

          scope "/resource_template" do
            live "/new", Dashboard.MetaResource.ResourceTemplateLive.New, :new
            live "/:id/edit", Dashboard.MetaResource.ResourceTemplateLive.Edit, :edit
            resources "/", ResourceTemplateController, except: [:new, :edit]
          end

          resources "/resource_templ_property", ResourceTemplatePropertyController
        end

        scope "/settings" do
          live "/", Dashboard.Settings.SettingLive, :index

          live "/user_dashboard", Users.Manage.Dashboard, :index

          scope "/users" do
            live "/", Users.ManageLive, :index
            live "/new", Users.ManageLive, :new
            live "/:id", Users.ManageLive.Show, :show
            live "/:id/show/edit", Users.ManageLive.Show, :edit
            live "/:id/edit", Users.ManageLive, :edit
          end

          scope "/roles" do
            live "/", Users.Role.ManageLive, :index
            live "/new", Users.Role.ManageLive, :new
            live "/:id", Users.Role.ManageLive.Show, :show
            live "/:id/show/edit", Users.Role.ManageLive.Show, :edit
            live "/:id/show/permissions", Users.Role.ManageLive.Show, :manage_permissions
            live "/:id/edit", Users.Role.ManageLive.Edit, :edit
          end

          live "/user_profile", UserSettingsLive, :edit
          live "/confirm_email/:token", UserSettingsLive, :confirm_email
          live "/holidays", Dashboard.Settings.HolidayLive, :index
        end
      end
    end

    get "/attachments/:id/download", Collection.AttachmentController.Download, :download
  end

  scope "/auth/google", VoileWeb do
    pipe_through [:browser]
    get "/", GoogleAuthController, :request
    get "/callback", GoogleAuthController, :callback
  end
end
