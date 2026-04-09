defmodule VoileWeb.Frontend.Atrium.Requisition.New do
  use VoileWeb, :live_view
  use Gettext, backend: VoileWeb.Gettext

  alias Voile.Schema.Library.Circulation
  alias Voile.Schema.Library.Requisition
  alias Voile.Schema.System

  @impl true
  def mount(_params, _session, socket) do
    changeset = Circulation.change_requisition(%Requisition{}, %{})
    nodes = System.list_nodes()

    {:ok,
     assign(socket,
       form: to_form(changeset, as: :requisition),
       page_title: gettext("New Request"),
       submitting: false,
       nodes: nodes
     )}
  end

  @impl true
  def handle_event("validate", %{"requisition" => params}, socket) do
    changeset =
      %Requisition{}
      |> Circulation.change_requisition(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset, as: :requisition))}
  end

  @impl true
  def handle_event("submit", params, socket) do
    case Turnstile.verify(params) do
      {:ok, _} ->
        user = socket.assigns.current_scope.user

        requisition_params =
          params
          |> Map.get("requisition", %{})

        case Circulation.create_requisition(user.id, requisition_params) do
          {:ok, _requisition} ->
            {:noreply,
             socket
             |> put_flash(:info, gettext("Your request has been submitted successfully."))
             |> push_navigate(to: ~p"/atrium/requisitions")}

          {:error, %Ecto.Changeset{} = changeset} ->
            socket =
              if connected?(socket) do
                Turnstile.refresh(socket)
              else
                socket
              end

            {:noreply,
             socket
             |> assign(form: to_form(changeset, as: :requisition))
             |> assign(submitting: false)}
        end

      {:error, _} ->
        socket =
          if connected?(socket) do
            Turnstile.refresh(socket)
          else
            socket
          end

        {:noreply,
         socket
         |> put_flash(:error, gettext("Captcha verification failed. Please try again."))
         |> assign(submitting: false)}
    end
  end

  @impl true
  def handle_event("go_back", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/atrium/requisitions")}
  end
end
