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
    plug VoileWeb.Plugs.Locale
    plug VoileWeb.Plugs.GetCurrentPath
    plug VoileWeb.Utils.SideBarMenuMaster
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :api_authenticated do
    plug :accepts, ["json"]
    plug VoileWeb.Plugs.APIAuthorization
    plug VoileWeb.Plugs.APIRateLimiter, limit: 100, scale_ms: 60_000, authenticated_limit: 1000
  end

  scope "/", VoileWeb do
    pipe_through :browser
    # Convert home and about pages to LiveView for better UX

    # OAI-PMH Viewer routes (human-friendly interfaces)
    get "/oai", OaiViewerController, :viewer
    get "/oai-demo", OaiViewerController, :demo

    # Search routes
    get "/search", SearchController, :index
    post "/search", SearchController, :index
    get "/search/advanced", SearchController, :advanced
    post "/search/advanced", SearchController, :advanced
    get "/search/suggestions", SearchController, :suggestions
    get "/api/search", SearchController, :api_search

    live_session :public_with_scope,
      session: {__MODULE__, :put_current_path_session, []},
      on_mount: [
        {VoileWeb.Live.Hooks.LocaleHook, :set_locale},
        {VoileWeb.UserAuth, :mount_current_scope},
        {VoileWeb.Live.Hooks.CurrentPath, :default}
      ] do
      # Search dashboard (admin only)
      live "/", PageLive.Home, :index

      live "/about", PageLive.About, :index
      live "/ebook", PageLive.Ebook, :index

      # LiveView search (optional alternative)
      live "/search/live", SearchLive, :index

      # Frontend member routes
      live "/collections", Frontend.Collections.Index, :index
      live "/collections/:id", Frontend.Collections.Show, :show
      live "/items", Frontend.Items.Index, :index
      live "/items/:id", Frontend.Items.Show, :show
      # E-Book reader - accepts query param `url` (local path or public S3 URL)
      live "/ebooks/view", Frontend.EbookReader.Show, :view

      # Public visitor routes
      live "/visitor", Visitor.CheckIn, :index
      live "/visitor/checkout", Visitor.CheckOut, :index
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
      session: {__MODULE__, :put_current_path_session, []},
      on_mount: [
        {VoileWeb.Live.Hooks.LocaleHook, :set_locale},
        {VoileWeb.UserAuth, :mount_current_scope},
        {VoileWeb.Live.Hooks.CurrentPath, :default}
      ] do
      live "/register", UserRegistrationLive, :new
      live "/login", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
      live "/users/set_initial_password/:token", UserInitialPasswordLive, :edit
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
      live "/users/pending_confirmation", UserPendingConfirmationLive, :index
    end

    post "/users/log_in", UserSessionController, :create
    get "/users/login/:token", MagicLinkController, :login
    delete "/users/log_out", UserSessionController, :delete
  end

  scope "/", VoileWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_for_onboarding,
      session: {__MODULE__, :put_current_path_session, []},
      on_mount: [
        {VoileWeb.Live.Hooks.LocaleHook, :set_locale},
        {VoileWeb.UserAuth, :require_authenticated},
        {VoileWeb.Live.Hooks.CurrentPath, :default}
      ] do
      live "/users/onboarding", UserOnboardingLive, :edit
    end
  end

  scope "/", VoileWeb do
    pipe_through [:browser, :require_authenticated_user, :require_onboarding_complete]

    live_session :require_authenticated_and_verified_member,
      session: {__MODULE__, :put_current_path_session, []},
      on_mount: [
        {VoileWeb.Live.Hooks.LocaleHook, :set_locale},
        {VoileWeb.UserAuth, :require_authenticated_and_verified_member},
        {VoileWeb.UserAuth, :require_onboarding_complete},
        {VoileWeb.Utils.SaveRequestUri, :save_request_uri},
        {VoileWeb.UserAuth, :mount_current_scope},
        {VoileWeb.Live.Hooks.CurrentPath, :default}
      ] do
      # Frontend member routes that require authentication
      live "/atrium", Frontend.Atrium.Index, :index
      live "/atrium/fine_detail/:id", Frontend.Atrium.FineDetail.Show, :show
      live "/atrium/requisitions", Frontend.Atrium.Requisition.Index, :index
      live "/atrium/requisitions/new", Frontend.Atrium.Requisition.New, :new
    end
  end

  scope "/", VoileWeb do
    pipe_through [:browser, :require_authenticated_user, :require_onboarding_complete]

    live_session :require_authenticated_user_and_verified_staff_user,
      session: {__MODULE__, :put_current_path_session, []},
      on_mount: [
        {VoileWeb.Live.Hooks.LocaleHook, :set_locale},
        {VoileWeb.UserAuth, :require_authenticated_and_verified_staff_user},
        {VoileWeb.UserAuth, :require_onboarding_complete},
        {VoileWeb.Utils.SaveRequestUri, :save_request_uri},
        {VoileWeb.Utils.SideBarMenuMaster, :master_menu},
        {VoileWeb.Live.Hooks.NotificationHook, :default},
        {VoileWeb.Live.Hooks.CurrentPath, :default}
      ] do
      scope "/manage" do
        live "/", DashboardLive, :index

        # Visitor statistics (staff/admin)
        scope "/visitor" do
          live "/statistics", Dashboard.Visitor.Statistics, :index
          live "/logs", Dashboard.Visitor.Logs, :index
          live "/surveys", Dashboard.Visitor.Surveys, :index
        end

        scope "/catalog" do
          live "/", Dashboard.Catalog.Index, :index
          live "/labels", Dashboard.Catalog.ItemLive.Labels, :index

          scope "/collections" do
            live "/", Dashboard.Catalog.CollectionLive.Index, :index
            live "/new", Dashboard.Catalog.CollectionLive.Index, :new
            live "/search", Dashboard.Catalog.CollectionLive.Index, :search_collection

            live "/add-item/:collection_id",
                 Dashboard.Catalog.CollectionLive.Index,
                 :add_item_to_collection

            live "/import", Dashboard.Catalog.CollectionLive.ImportExport, :import
            live "/review", Dashboard.Catalog.CollectionLive.Review, :index
            live "/review/:id", Dashboard.Catalog.CollectionLive.Review, :review
            live "/submitted", Dashboard.Catalog.CollectionLive.Submitted, :index
            live "/submitted/:id", Dashboard.Catalog.CollectionLive.Submitted, :edit
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

          scope "/attachments" do
            live "/", Dashboard.Catalog.Attachment.Index, :index
            live "/:id/access", Dashboard.Catalog.Attachment.Index, :manage_access
          end

          scope "/asset-vault" do
            live "/", Dashboard.Catalog.AssetVault.Index, :index
          end

          scope "/transfers" do
            live "/", Dashboard.Catalog.TransferRequestLive.Index, :index
            live "/:id", Dashboard.Catalog.TransferRequestLive.Show, :show
          end

          scope "/stock_opname" do
            live "/", Dashboard.StockOpnameLive.Index, :index
            live "/new", Dashboard.StockOpnameLive.New, :new
            live "/report", Dashboard.StockOpnameLive.Report, :report
            live "/:id", Dashboard.StockOpnameLive.Show, :show
            live "/:id/scan", Dashboard.StockOpnameLive.Scan, :scan
            live "/:id/review", Dashboard.StockOpnameLive.Review, :review
          end
        end

        scope "/glam" do
          live "/", Dashboard.Glam.Index, :index

          scope "/gallery" do
            live "/", Dashboard.Glam.Gallery.Index, :index
          end

          scope "/library" do
            # Library index (overview) — mirrors gallery, archive, museum dashboards
            live "/", Dashboard.Glam.Library.Index, :index

            scope "/circulation" do
              live "/", Dashboard.Glam.Library.Circulation.Index, :index
              live "/report", Dashboard.Glam.Library.Circulation.Report, :report

              live "/loan_reminders",
                   Dashboard.Glam.Library.Circulation.LoanReminderLive,
                   :index

              scope "/transactions" do
                live "/", Dashboard.Glam.Library.Circulation.Transaction.Index, :index
                live "/checkout", Dashboard.Glam.Library.Circulation.Transaction.Index, :checkout
                live "/:id/return", Dashboard.Glam.Library.Circulation.Transaction.Index, :return
                live "/:id/renew", Dashboard.Glam.Library.Circulation.Transaction.Index, :renew
                live "/:id", Dashboard.Glam.Library.Circulation.Transaction.Show, :show
              end

              scope "/reservations" do
                live "/", Dashboard.Glam.Library.Circulation.Reservation.Index, :index
                live "/new", Dashboard.Glam.Library.Circulation.Reservation.Index, :new
                live "/:id", Dashboard.Glam.Library.Circulation.Reservation.Show, :show
              end

              scope "/requisitions" do
                live "/", Dashboard.Glam.Library.Circulation.Requisition.Index, :index
                live "/new", Dashboard.Glam.Library.Circulation.Requisition.Index, :new
                live "/:id", Dashboard.Glam.Library.Circulation.Requisition.Show, :show
                live "/:id/edit", Dashboard.Glam.Library.Circulation.Requisition.Index, :edit
              end

              scope "/fines" do
                live "/", Dashboard.Glam.Library.Circulation.Fine.Index, :index
                live "/new", Dashboard.Glam.Library.Circulation.Fine.Index, :new
                live "/:id", Dashboard.Glam.Library.Circulation.Fine.Show, :show
                live "/:id/payment", Dashboard.Glam.Library.Circulation.Fine.Show, :payment
                live "/:id/waive", Dashboard.Glam.Library.Circulation.Fine.Show, :waive
              end

              scope "/circulation_history" do
                live "/", Dashboard.Glam.Library.Circulation.CirculationHistory.Index, :index
                live "/:id", Dashboard.Glam.Library.Circulation.CirculationHistory.Show, :show
              end
            end

            scope "/ledger" do
              live "/", Dashboard.Glam.Library.Ledger.Index, :index
              live "/transact/:id", Dashboard.Glam.Library.Ledger.Transact, :transact
            end

            scope "/requisitions" do
              live "/", Dashboard.Glam.Library.Requisition.Index, :index
              live "/:id", Dashboard.Glam.Library.Requisition.Show, :show
            end
          end

          scope "/archive" do
            live "/", Dashboard.Glam.Archive.Index, :index
          end

          scope "/museum" do
            live "/", Dashboard.Glam.Museum.Index, :index
          end
        end

        scope "/members" do
          live "/", Dashboard.Members.Index, :index

          scope "/management" do
            live "/", Dashboard.Members.Management.Index, :index
            live "/new", Dashboard.Members.Management.Index, :new

            scope "/roles" do
              live "/", Users.Role.ManageLive, :index
              live "/new", Users.Role.ManageLive, :new
              live "/:id", Users.Role.ManageLive.Show, :show
              live "/:id/show/edit", Users.Role.ManageLive.Show, :edit
              live "/:id/show/permissions", Users.Role.ManageLive.Show, :manage_permissions
              live "/:id/edit", Users.Role.ManageLive.Edit, :edit
            end

            live "/:id/edit", Dashboard.Members.Management.Index, :edit
            live "/:id", Dashboard.Members.Management.Show, :show
            live "/:id/show/edit", Dashboard.Members.Management.Show, :edit
          end

          scope "/reports" do
            live "/", Dashboard.Members.Reports.Index, :index
            live "/expiring", Dashboard.Members.Reports.Expiring, :index
            live "/overdue", Dashboard.Members.Reports.Overdue, :index
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

          live "/apps", Dashboard.Settings.AppProfileSettingsLive, :index

          scope "/roles" do
            live "/", Users.Role.ManageLive, :index
            live "/new", Users.Role.ManageLive, :new
            live "/:id", Users.Role.ManageLive.Show, :show
            live "/:id/show/edit", Users.Role.ManageLive.Show, :edit
            live "/:id/show/permissions", Users.Role.ManageLive.Show, :manage_permissions
            live "/:id/edit", Users.Role.ManageLive.Edit, :edit
          end

          scope "/permissions" do
            live "/", Users.Permission.ManageLive, :index
            live "/new", Users.Permission.ManageLive, :new
            live "/:id", Users.Permission.ManageLive.Show, :show
            live "/:id/edit", Users.Permission.ManageLive.Edit, :edit
          end

          live "/user_profile", UserSettingsLive, :edit
          live "/confirm_email/:token", UserSettingsLive, :confirm_email
          live "/holidays", Dashboard.Settings.HolidayLive, :index
          live "/nodes", Dashboard.Settings.SystemNodeLive, :index
          live "/nodes/rules", Dashboard.Settings.SystemNodeRulesLive, :index

          live "/api_manager", Dashboard.Settings.ApiManager, :index

          live "/reservation_notifications",
               Dashboard.Settings.ReservationNotificationLive,
               :index
        end

        # Plugin management routes
        scope "/plugins" do
          live "/", Dashboard.Plugins.Index, :index
          live "/:plugin_id/settings", Dashboard.Plugins.Settings, :settings
          live "/:plugin_id", PluginRouterLive, :index
          live "/:plugin_id/*path", PluginRouterLive, :index
        end
      end
    end

    get "/attachments/:id/download", Collection.AttachmentController.Download, :download
    get "/manage/visitor/logs/export", Dashboard.Visitor.LogsExportController, :export
  end

  scope "/api", VoileWeb do
    pipe_through :api

    get "/", API.InfoController, :info

    # OAI-PMH endpoint (public, no authentication required)
    get "/oai", OaiPmhController, :index
    post "/oai", OaiPmhController, :index

    scope "/v1" do
      pipe_through :api_authenticated

      resources "/collections", API.V1.Collections.CollectionApiController, except: [:new, :edit]
      resources "/items", API.V1.Items.ItemApiController, except: [:new, :edit]
      resources "/fines", API.V1.Fines.FineApiController, except: [:new, :edit]
      resources "/users", API.V1.Users.UserApiController, only: [:index, :show]

      get "/circulation/:identifier", API.V1.Circulation.CirculationApiController, :show

      get "/circulation/:identifier/transactions",
          API.V1.Circulation.CirculationApiController,
          :transactions

      get "/circulation/:identifier/history",
          API.V1.Circulation.CirculationApiController,
          :history

      get "/circulation/:identifier/fines", API.V1.Circulation.CirculationApiController, :fines

      resources "/circulation_history", API.V1.CirculationHistory.CirculationHistoryApiController,
        except: [:new, :edit]

      get "/collection_types", API.V1.CollectionTypes.CollectionTypeApiController, :index

      get "/collection_types/details",
          API.V1.CollectionTypes.CollectionTypeApiController,
          :details

      get "/units", API.V1.Unit.UnitApiController, :index

      resources "/tokens", API.V1.UserApiTokenController,
        only: [:index, :create, :show, :update, :delete] do
        post "/rotate", API.V1.UserApiTokenController, :rotate, as: :rotate
      end
    end
  end

  scope "/auth/google", VoileWeb do
    pipe_through [:browser]
    get "/", GoogleAuthController, :request
    get "/callback", GoogleAuthController, :callback
  end

  scope "/auth/paus", VoileWeb do
    pipe_through [:browser]

    get "/", PausAuthController, :request
    get "/callback", PausAuthController, :callback
  end

  # Gmail API OAuth callback (for email sending setup, NOT user login)
  scope "/auth/gmail", VoileWeb do
    pipe_through [:browser]
    get "/callback", GmailCallbackController, :callback
  end

  # Webhook endpoints (no CSRF protection needed)
  scope "/webhooks", VoileWeb do
    pipe_through :api

    post "/xendit/payment", XenditWebhookController, :payment_callback
  end

  if Mix.env() == :dev do
    scope "/api/swagger" do
      pipe_through :api

      forward "/", PhoenixSwagger.Plug.SwaggerUI,
        otp_app: :voile,
        swagger_file: "swagger.json",
        disable_validator: true,
        config: %{
          tagsSorter: false,
          operationsSorter: false
        }
    end

    scope "/api" do
      pipe_through :api
      get "/swagger.json", PhoenixSwagger.Plug.Validate, []
    end
  end

  def swagger_info do
    %{
      basePath: "/api",
      info: %{
        version: "1.0",
        title: "Voile",
        description: "Voile API Documentation",
        contact: %{
          name: "Chrisna Adhi Pranoto",
          email: "chrisna.adhi@unpad.ac.id"
        }
      },
      # host: "10.92.53.245:4000",
      schemes: ["http"],
      tags: [
        %{name: "Collections", description: "Collection management endpoints"},
        %{name: "Items", description: "Item management endpoints"},
        %{name: "Users", description: "User management endpoints"},
        %{name: "Circulation", description: "Circulation management endpoints"},
        %{name: "CirculationHistory", description: "Circulation history endpoints"},
        %{name: "Fines", description: "Fine management endpoints"},
        %{name: "API Tokens", description: "Managing API Token endpoints"},
        %{name: "Units", description: "Unit / Faculty / Node endpoints"},
        %{name: "Collection Types", description: "Collection Type endpoints"}
      ],
      securityDefinitions: %{
        Bearer: %{
          type: "apiKey",
          name: "token",
          description:
            "API Token can be provided via `token` query parameter or `Authorization: Bearer <token>` header",
          in: "query"
        }
      },
      consumes: ["application/json"],
      produces: ["application/json"]
    }
  end

  @doc false
  def put_current_path_session(conn) do
    %{
      "current_path" => Plug.Conn.get_session(conn, :current_path),
      "current_uri" => Plug.Conn.get_session(conn, :current_uri)
    }
  end
end
