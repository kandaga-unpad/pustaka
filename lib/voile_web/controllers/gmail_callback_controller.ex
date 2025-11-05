defmodule VoileWeb.GmailCallbackController do
  use VoileWeb, :controller
  require Logger

  @doc """
  Handles the OAuth2 callback from Google for Gmail API authorization.
  This is ONLY for obtaining Gmail API tokens during setup, NOT for user authentication.
  """
  def callback(conn, %{"code" => code} = params) do
    Logger.info("Gmail API OAuth callback received")
    Logger.debug("Authorization code: #{String.slice(code, 0, 20)}...")
    Logger.debug("Full params: #{inspect(params)}")

    conn
    |> put_flash(:info, "Authorization successful! Check your terminal for the tokens.")
    |> put_resp_content_type("text/html")
    |> send_resp(
      200,
      """
      <!DOCTYPE html>
      <html>
      <head>
        <title>Gmail API Authorization</title>
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          }
          .container {
            background: white;
            padding: 3rem;
            border-radius: 1rem;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            max-width: 600px;
            text-align: center;
          }
          h1 {
            color: #2d3748;
            margin-bottom: 1rem;
          }
          .success-icon {
            font-size: 4rem;
            margin-bottom: 1rem;
          }
          .code-block {
            background: #f7fafc;
            border: 1px solid #e2e8f0;
            border-radius: 0.5rem;
            padding: 1rem;
            margin: 1.5rem 0;
            font-family: 'Courier New', monospace;
            font-size: 0.875rem;
            text-align: left;
            word-break: break-all;
          }
          .instructions {
            color: #4a5568;
            line-height: 1.6;
            margin-top: 1.5rem;
          }
          .important {
            background: #fef5e7;
            border-left: 4px solid #f39c12;
            padding: 1rem;
            margin: 1.5rem 0;
            text-align: left;
          }
          .button {
            display: inline-block;
            background: #667eea;
            color: white;
            padding: 0.75rem 1.5rem;
            border-radius: 0.5rem;
            text-decoration: none;
            margin-top: 1rem;
            font-weight: 600;
          }
          .button:hover {
            background: #5a67d8;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="success-icon">✅</div>
          <h1>Authorization Successful!</h1>

          <p class="instructions">
            Your Gmail API authorization was successful. The authorization code has been received.
          </p>

          <div class="code-block">
            <strong>Authorization Code:</strong><br>
            #{String.slice(code, 0, 40)}...
          </div>

          <div class="important">
            <strong>⚠️ Important:</strong> Check your terminal where you ran
            <code>Voile.Mailer.GmailAuth.interactive_setup()</code> to see the
            access and refresh tokens. Copy them to your <code>.env</code> file.
          </div>

          <p class="instructions">
            The tokens will be displayed in your IEx console. You can now close this window.
          </p>

          <a href="/" class="button">Return to Home</a>
        </div>
      </body>
      </html>
      """
    )
  end

  def callback(conn, params) do
    Logger.error("Gmail API callback received without code parameter")
    Logger.debug("Params: #{inspect(params)}")

    conn
    |> put_flash(:error, "Authorization failed: No authorization code received")
    |> put_resp_content_type("text/html")
    |> send_resp(
      400,
      """
      <!DOCTYPE html>
      <html>
      <head>
        <title>Gmail API Authorization Failed</title>
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
          }
          .container {
            background: white;
            padding: 3rem;
            border-radius: 1rem;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            max-width: 600px;
            text-align: center;
          }
          h1 {
            color: #e53e3e;
            margin-bottom: 1rem;
          }
          .error-icon {
            font-size: 4rem;
            margin-bottom: 1rem;
          }
          .instructions {
            color: #4a5568;
            line-height: 1.6;
            margin-top: 1.5rem;
          }
          .button {
            display: inline-block;
            background: #e53e3e;
            color: white;
            padding: 0.75rem 1.5rem;
            border-radius: 0.5rem;
            text-decoration: none;
            margin-top: 1rem;
            font-weight: 600;
          }
          .button:hover {
            background: #c53030;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="error-icon">❌</div>
          <h1>Authorization Failed</h1>

          <p class="instructions">
            The Gmail API authorization did not complete successfully.
            No authorization code was received.
          </p>

          <p class="instructions">
            Please try running <code>Voile.Mailer.GmailAuth.interactive_setup()</code>
            again in your terminal.
          </p>

          <a href="/" class="button">Return to Home</a>
        </div>
      </body>
      </html>
      """
    )
  end
end
