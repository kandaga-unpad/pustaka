alias Voile.Repo
alias Voile.Schema.Accounts

first_admin = %Accounts.User{
  email: "admin@voile.id",
  password: "password",
  fullname: "Admin User",
  username: "admin",
  user_type: "Administrator",
  user_role_id: 1,
  confirmed_at: DateTime.utc_now()
}

Repo.insert!(first_admin)
