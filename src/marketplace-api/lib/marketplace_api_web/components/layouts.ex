defmodule MarketplaceApiWeb.Layouts do
  use Phoenix.Component
  alias Plug.CSRFProtection

  def get_csrf_token, do: CSRFProtection.get_csrf_token()

  embed_templates "layouts/*"
end
