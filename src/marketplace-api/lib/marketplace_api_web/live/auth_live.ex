defmodule MarketplaceApiWeb.AuthLive do
  use Phoenix.LiveView
  use SaladUI

  alias MarketplaceApi.Services.UserService

  def mount(_params, session, socket) do
    user_token = session["user_token"]
    username = session["username"]

    {:ok, assign(socket,
      # Auth state
      user_token: user_token,
      username: username,
      signed_in?: !is_nil(user_token),

      # UI state
      view: if(user_token, do: "dashboard", else: "login"),
      loading: false,
      message: nil,
      error: nil,

      # Form state
      login_username: "",
      login_password: "",
      signup_email: "",
      signup_username: "",
      signup_password: "",
      confirm_username: "",
      confirm_code: ""
    )}
  end

  # Sign Up
  def handle_event("signup", %{"email" => email, "username" => username, "password" => password}, socket) do
    socket = assign(socket, loading: true, error: nil)

    case UserService.sign_up(email, password, username) do
      {:ok, result} ->
        {:noreply, assign(socket,
          loading: false,
          view: "confirm",
          confirm_username: username,
          message: result.message,
          error: nil
        )}

      {:error, error} ->
        {:noreply, assign(socket,
          loading: false,
          error: error,
          message: nil
        )}
    end
  end

  # Confirm Sign Up
  def handle_event("confirm", %{"username" => username, "code" => code}, socket) do
    socket = assign(socket, loading: true, error: nil)

    case UserService.confirm_sign_up(username, code) do
      {:ok, message} ->
        {:noreply, assign(socket,
          loading: false,
          view: "login",
          message: message,
          error: nil
        )}

      {:error, error} ->
        {:noreply, assign(socket,
          loading: false,
          error: error,
          message: nil
        )}
    end
  end

  # Sign In
  def handle_event("login", %{"username" => username, "password" => password}, socket) do
    socket = assign(socket, loading: true, error: nil)

    case UserService.sign_in(username, password) do
      {:ok, auth} ->
        socket = assign(socket,
          user_token: auth.access_token,
          username: username,
          signed_in?: true,
          view: "dashboard",
          loading: false,
          message: "Welcome back, #{username}!",
          error: nil
        )

        {:noreply, socket}

      {:error, error} ->
        {:noreply, assign(socket,
          loading: false,
          error: error,
          message: nil
        )}
    end
  end

  # Logout
  def handle_event("logout", _params, socket) do
    socket = assign(socket,
      user_token: nil,
      username: nil,
      signed_in?: false,
      view: "login",
      message: "Signed out successfully"
    )

    {:noreply, socket}
  end

  # Switch views
  def handle_event("switch_view", %{"view" => view}, socket) do
    {:noreply, assign(socket, view: view, error: nil, message: nil)}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center p-4">
      <div class="w-full max-w-md">
        <!-- Logo/Header -->
        <div class="text-center mb-8">
          <h1 class="text-4xl font-bold text-gray-900 mb-2">🚀 Rukmer Commons</h1>
          <p class="text-gray-600">AWS Cognito Authentication</p>
        </div>

        <!-- Messages -->
        <%= if @message do %>
          <.alert class="mb-4">
            <.alert_title>Success</.alert_title>
            <.alert_description><%= @message %></.alert_description>
          </.alert>
        <% end %>

        <%= if @error do %>
          <.alert variant="destructive" class="mb-4">
            <.alert_title>Error</.alert_title>
            <.alert_description><%= @error %></.alert_description>
          </.alert>
        <% end %>

        <%= if @signed_in? do %>
          <!-- Dashboard (Logged In) -->
          <.card>
            <.card_header>
              <.card_title>Welcome, <%= @username %>!</.card_title>
              <.card_description>You are successfully logged in</.card_description>
            </.card_header>
            <.card_content class="space-y-4">
              <div class="p-4 bg-green-50 rounded-lg border border-green-200">
                <p class="text-sm font-medium text-green-900">✅ Authentication Successful</p>
                <p class="text-xs text-green-700 mt-1">Access token stored in session</p>
              </div>

              <div class="space-y-2">
                <div class="text-sm">
                  <span class="font-semibold">Username:</span> <%= @username %>
                </div>
                <div class="text-sm">
                  <span class="font-semibold">Token:</span>
                  <code class="text-xs bg-gray-100 px-2 py-1 rounded">
                    <%= String.slice(@user_token, 0, 20) %>...
                  </code>
                </div>
              </div>

              <.button phx-click="logout" variant="outline" class="w-full">
                Sign Out
              </.button>
            </.card_content>
          </.card>

        <% else %>
          <!-- Auth Forms (Not Logged In) -->
          <%= cond do %>
            <% @view == "login" -> %>
              <!-- Login Form -->
              <.card>
                <.card_header>
                  <.card_title>Sign In</.card_title>
                  <.card_description>Sign in to your account</.card_description>
                </.card_header>
                <.card_content>
                  <form phx-submit="login" class="space-y-4">
                    <div class="space-y-2">
                      <.label for="username">Username</.label>
                      <.input
                        type="text"
                        name="username"
                        placeholder="Enter your username"
                        value={@login_username}
                        required
                      />
                    </div>

                    <div class="space-y-2">
                      <.label for="password">Password</.label>
                      <.input
                        type="password"
                        name="password"
                        placeholder="Enter your password"
                        value={@login_password}
                        required
                      />
                    </div>

                    <.button type="submit" class="w-full" disabled={@loading}>
                      <%= if @loading, do: "Signing in...", else: "Sign In" %>
                    </.button>
                  </form>
                </.card_content>
                <.card_footer class="flex flex-col space-y-2">
                  <.button
                    phx-click="switch_view"
                    phx-value-view="signup"
                    variant="ghost"
                    class="w-full"
                  >
                    Don't have an account? Sign Up
                  </.button>
                  <.button
                    phx-click="switch_view"
                    phx-value-view="confirm"
                    variant="ghost"
                    class="w-full text-sm"
                  >
                    Have a confirmation code?
                  </.button>
                </.card_footer>
              </.card>

            <% @view == "signup" -> %>
              <!-- Sign Up Form -->
              <.card>
                <.card_header>
                  <.card_title>Sign Up</.card_title>
                  <.card_description>Create a new account</.card_description>
                </.card_header>
                <.card_content>
                  <form phx-submit="signup" class="space-y-4">
                    <div class="space-y-2">
                      <.label for="email">Email</.label>
                      <.input
                        type="email"
                        name="email"
                        placeholder="your.email@example.com"
                        value={@signup_email}
                        required
                      />
                    </div>

                    <div class="space-y-2">
                      <.label for="username">Username</.label>
                      <.input
                        type="text"
                        name="username"
                        placeholder="Choose a username"
                        value={@signup_username}
                        required
                      />
                    </div>

                    <div class="space-y-2">
                      <.label for="password">Password</.label>
                      <.input
                        type="password"
                        name="password"
                        placeholder="Choose a password (min 8 chars)"
                        value={@signup_password}
                        required
                      />
                      <p class="text-xs text-muted-foreground">
                        Must contain: uppercase, lowercase, number, and special character
                      </p>
                    </div>

                    <.button type="submit" class="w-full" disabled={@loading}>
                      <%= if @loading, do: "Creating account...", else: "Sign Up" %>
                    </.button>
                  </form>
                </.card_content>
                <.card_footer>
                  <.button
                    phx-click="switch_view"
                    phx-value-view="login"
                    variant="ghost"
                    class="w-full"
                  >
                    Already have an account? Sign In
                  </.button>
                </.card_footer>
              </.card>

            <% @view == "confirm" -> %>
              <!-- Confirm Email Form -->
              <.card>
                <.card_header>
                  <.card_title>Confirm Email</.card_title>
                  <.card_description>
                    Enter the confirmation code sent to your email
                  </.card_description>
                </.card_header>
                <.card_content>
                  <form phx-submit="confirm" class="space-y-4">
                    <div class="space-y-2">
                      <.label for="username">Username</.label>
                      <.input
                        type="text"
                        name="username"
                        placeholder="Your username"
                        value={@confirm_username}
                        required
                      />
                    </div>

                    <div class="space-y-2">
                      <.label for="code">Confirmation Code</.label>
                      <.input
                        type="text"
                        name="code"
                        placeholder="Enter 6-digit code"
                        required
                      />
                    </div>

                    <.button type="submit" class="w-full" disabled={@loading}>
                      <%= if @loading, do: "Confirming...", else: "Confirm Email" %>
                    </.button>
                  </form>
                </.card_content>
                <.card_footer>
                  <.button
                    phx-click="switch_view"
                    phx-value-view="login"
                    variant="ghost"
                    class="w-full"
                  >
                    Back to Sign In
                  </.button>
                </.card_footer>
              </.card>
          <% end %>
        <% end %>

        <!-- Loading Overlay -->
        <%= if @loading do %>
          <div class="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
            <.card class="w-auto">
              <.card_content class="py-8 px-12">
                <div class="flex flex-col items-center space-y-4">
                  <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-primary"></div>
                  <p class="text-sm text-muted-foreground">Processing...</p>
                </div>
              </.card_content>
            </.card>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
