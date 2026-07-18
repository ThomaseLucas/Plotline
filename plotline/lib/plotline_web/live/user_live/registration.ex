defmodule PlotlineWeb.UserLive.Registration do
  use PlotlineWeb, :live_view

  alias Plotline.Accounts
  alias Plotline.Accounts.User

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.auth_page flash={@flash} page_id="registration-page">
      <h1 class="text-center text-2xl font-bold text-[#212121]">Sign up</h1>

      <p class="mt-3 text-center text-sm leading-relaxed text-[#212121]/70">
        Create an account with your email and password to start using Plotline.
      </p>

      <.form
        for={@form}
        id="registration_form"
        phx-submit="save"
        phx-change="validate"
        phx-trigger-action={@trigger_submit}
        action={~p"/users/log-in"}
        method="post"
        class="mt-8 space-y-4"
      >
        <.input
          field={@form[:email]}
          type="email"
          placeholder="Email"
          autocomplete="username"
          required
          class="w-full rounded-lg border-0 bg-white px-4 py-3.5 text-[#212121] shadow-md placeholder:text-[#212121]/40 focus:outline-none focus:ring-2 focus:ring-[#74AC8D]"
        />
        <.input
          field={@form[:password]}
          type="password"
          placeholder="Password (at least 8 characters)"
          autocomplete="new-password"
          required
          class="w-full rounded-lg border-0 bg-white px-4 py-3.5 text-[#212121] shadow-md placeholder:text-[#212121]/40 focus:outline-none focus:ring-2 focus:ring-[#74AC8D]"
        />
        <input type="hidden" name="user[remember_me]" value="true" />
        <button
          type="submit"
          phx-disable-with="Creating account..."
          class="w-full rounded-lg bg-[#212121] px-4 py-3.5 text-base font-semibold text-[#F2E8CF] transition hover:bg-[#212121]/90"
        >
          Register
        </button>
      </.form>

      <p class="mt-6 text-center text-sm text-[#212121]/70">
        Already have an account?
        <.link
          navigate={~p"/users/log-in"}
          class="font-medium text-[#212121] underline underline-offset-2"
        >
          Log in
        </.link>
      </p>
    </Layouts.auth_page>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: PlotlineWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})

    {:ok,
     socket
     |> assign(:trigger_submit, false)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        # Keep plaintext password in the form so the browser can POST login credentials.
        form =
          Accounts.change_user_registration(
            user,
            %{
              "email" => user.email,
              "password" => user_params["password"]
            },
            hash_password: false
          )
          |> to_form(as: "user")

        {:noreply,
         socket
         |> put_flash(:info, "Welcome to Plotline!")
         |> assign(:form, form)
         |> assign(:trigger_submit, true)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :insert))}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, form: to_form(changeset, as: "user"))
  end
end
