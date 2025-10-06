defmodule MarketplaceApi.Services.UserService do
  @moduledoc """
  Simple Cognito integration: signup, confirm, and login
  """

  @doc """
  Sign up a new user - returns confirmation code needed
  """
  def sign_up(email, password, username) do
    client = aws_client()
    client_id = cognito_config(:client_id)

    user_attributes = [
      %{"Name" => "email", "Value" => email}
    ]

    params = %{
      "ClientId" => client_id,
      "Username" => username,
      "Password" => password,
      "UserAttributes" => user_attributes
    }

    case AWS.CognitoIdentityProvider.sign_up(client, params) do
      {:ok, %{"UserConfirmed" => confirmed, "UserSub" => sub}, _response} ->
        {:ok, %{
          message: "User created. Check your email for confirmation code.",
          user_confirmed: confirmed,
          user_sub: sub
        }}

      {:error, {:http_error, 400, %{"__type" => "UsernameExistsException"}}} ->
        {:error, "Username or email already exists"}

      {:error, {:http_error, 400, %{"__type" => "InvalidPasswordException", "message" => message}}} ->
        {:error, "Invalid password: #{message}"}

      {:error, {:http_error, _status, %{"__type" => error_type, "message" => message}}} ->
        {:error, "#{error_type}: #{message}"}

      {:error, reason} ->
        {:error, "Failed to sign up: #{inspect(reason)}"}
    end
  end

  @doc """
  Confirm sign up with the code sent to email
  """
  def confirm_sign_up(username, confirmation_code) do
    client = aws_client()
    client_id = cognito_config(:client_id)

    params = %{
      "ClientId" => client_id,
      "Username" => username,
      "ConfirmationCode" => confirmation_code
    }

    case AWS.CognitoIdentityProvider.confirm_sign_up(client, params) do
      {:ok, _result, _response} ->
        {:ok, "Email confirmed successfully. You can now sign in."}

      {:error, {:http_error, 400, %{"__type" => "CodeMismatchException"}}} ->
        {:error, "Invalid confirmation code"}

      {:error, {:http_error, 400, %{"__type" => "ExpiredCodeException"}}} ->
        {:error, "Confirmation code has expired"}

      {:error, {:http_error, 400, %{"__type" => "NotAuthorizedException"}}} ->
        {:error, "User is already confirmed"}

      {:error, {:http_error, _status, %{"__type" => error_type, "message" => message}}} ->
        {:error, "#{error_type}: #{message}"}

      {:error, reason} ->
        {:error, "Failed to confirm sign up: #{inspect(reason)}"}
    end
  end

  @doc """
  Sign in and get access token
  """
  def sign_in(username, password) do
    client = aws_client()
    client_id = cognito_config(:client_id)

    params = %{
      "AuthFlow" => "USER_PASSWORD_AUTH",
      "ClientId" => client_id,
      "AuthParameters" => %{
        "USERNAME" => username,
        "PASSWORD" => password
      }
    }

    case AWS.CognitoIdentityProvider.initiate_auth(client, params) do
      {:ok, %{"AuthenticationResult" => auth}, _response} ->
        {:ok, %{
          access_token: auth["AccessToken"],
          id_token: auth["IdToken"],
          refresh_token: auth["RefreshToken"],
          expires_in: auth["ExpiresIn"],
          username: username
        }}

      {:error, {:http_error, 400, %{"__type" => "NotAuthorizedException"}}} ->
        {:error, "Incorrect username or password"}

      {:error, {:http_error, 400, %{"__type" => "UserNotConfirmedException"}}} ->
        {:error, "Please confirm your email first"}

      {:error, {:http_error, _status, %{"__type" => error_type, "message" => message}}} ->
        {:error, "#{error_type}: #{message}"}

      {:error, reason} ->
        {:error, "Failed to sign in: #{inspect(reason)}"}
    end
  end

  # Get Cognito configuration
  defp cognito_config(key) do
    Application.get_env(:marketplace_api, :cognito)[key]
  end

  # Create AWS client with credentials
  defp aws_client do
    region = cognito_config(:region)
    aws_config = Application.get_env(:marketplace_api, :aws, [])

    AWS.Client.create(
      aws_config[:access_key_id],
      aws_config[:secret_access_key],
      region
    )
  end
end
