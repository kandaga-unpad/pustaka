defmodule Mix.Tasks.Voile.GenToken do
  use Mix.Task

  @shortdoc "Generates an API token for a user"
  def run([email]) do
    Mix.Task.run("app.start")

    user = Voile.Schema.Accounts.get_user_by_email(email)

    if user do
      {:ok, _token, plain_token} =
        Voile.Schema.System.create_api_token(user, %{
          name: "CLI Generated",
          scopes: ["read", "write", "admin"],
          expires_at: DateTime.utc_now() |> DateTime.add(365, :day)
        })

      IO.puts("\n✅ Token generated successfully!")
      IO.puts("Token: #{plain_token}")
      IO.puts("\nUse it like this:")

      IO.puts(
        "curl http://localhost:4000/api/v1/collections -H 'Authorization: Bearer #{plain_token}'"
      )
    else
      IO.puts("❌ User not found: #{email}")
    end
  end
end
