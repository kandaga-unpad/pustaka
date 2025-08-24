alias Voile.Repo
alias Voile.Schema.Accounts
alias Voile.Schema.Master.MemberType

hashed_pw =
  "super_long_password"
  |> Pbkdf2.hash_pwd_salt()

first_admin = %Accounts.User{
  email: "admin@voile.id",
  fullname: "Admin User",
  username: "admin",
  password: "super_long_password",
  user_role_id: 1,
  confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second),
  hashed_password: hashed_pw
}

first_admin
|> Accounts.change_user_registration()
|> Repo.insert!()

list_member_type = [
  %{
    name: "Administrator",
    loan_limit: 0,
    loan_period: 0,
    enable_reserve: false,
    membership_period: 0,
    reloan_limit: 0,
    loan_fine: 0,
    loan_grace_period: 0
  },
  %{
    name: "Staff",
    loan_limit: 10,
    loan_period: 30,
    enable_reserve: true,
    membership_period: 365,
    reloan_limit: 2,
    loan_fine: 1000,
    loan_grace_period: 7
  },
  %{
    name: "Member (Organization)",
    loan_limit: 20,
    loan_period: 60,
    enable_reserve: true,
    membership_period: 365,
    reloan_limit: 3,
    loan_fine: 500,
    loan_grace_period: 14
  },
  %{
    name: "Member (Verified)",
    loan_limit: 5,
    loan_period: 21,
    enable_reserve: true,
    membership_period: 365,
    reloan_limit: 1,
    loan_fine: 2000,
    loan_grace_period: 3
  },
  %{
    name: "Member (Affirmation)",
    loan_limit: 3,
    loan_period: 14,
    enable_reserve: false,
    membership_period: 180,
    reloan_limit: 1,
    loan_fine: 1000,
    loan_grace_period: 2
  },
  %{
    name: "Guest",
    loan_limit: 1,
    loan_period: 7,
    enable_reserve: false,
    membership_period: 30,
    reloan_limit: 0,
    loan_fine: 5000,
    loan_grace_period: 0
  }
]

for member_type <- list_member_type do
  Repo.insert!(%MemberType{
    name: member_type.name,
    loan_limit: member_type.loan_limit,
    loan_period: member_type.loan_period,
    enable_reserve: member_type.enable_reserve,
    membership_period: member_type.membership_period,
    reloan_limit: member_type.reloan_limit,
    loan_fine: member_type.loan_fine,
    loan_grace_period: member_type.loan_grace_period
  })
end
