alias Voile.Repo
alias Voile.Schema.Accounts
alias Voile.Schema.Master.MemberType

list_member_type = [
  %{
    name: "Administrator",
    slug: "administrator",
    description: "System administrator with unlimited access and no borrowing restrictions",
    max_items: 0,
    max_days: 0,
    max_renewals: 0,
    max_reserves: 0,
    max_concurrent_loans: 0,
    fine_per_day: Decimal.new("0.0"),
    max_fine: nil,
    membership_fee: Decimal.new("0.0"),
    currency: "IDR",
    can_reserve: false,
    can_renew: false,
    digital_access: true,
    exhibition_preview_access: true,
    ticket_discount_percent: 100,
    shop_discount_percent: 50,
    max_event_bookings_per_year: 0,
    membership_period_days: nil,
    auto_renew: false,
    recurrence_unit: nil,
    recurrence_interval: nil,
    priority_level: 10,
    is_active: true,
    publicly_listed: false,
    institutional: false,
    allowed_collections: %{},
    metadata: %{"role" => "system_admin"}
  },
  %{
    name: "Staff",
    slug: "staff",
    description: "Library staff with extended borrowing privileges",
    max_items: 10,
    max_days: 30,
    max_renewals: 2,
    max_reserves: 5,
    max_concurrent_loans: 10,
    fine_per_day: Decimal.new("1000.0"),
    max_fine: Decimal.new("50000.0"),
    membership_fee: Decimal.new("0.0"),
    currency: "IDR",
    can_reserve: true,
    can_renew: true,
    digital_access: true,
    exhibition_preview_access: true,
    ticket_discount_percent: 50,
    shop_discount_percent: 25,
    max_event_bookings_per_year: 20,
    membership_period_days: 365,
    auto_renew: true,
    recurrence_unit: "days",
    recurrence_interval: 365,
    priority_level: 8,
    is_active: true,
    publicly_listed: false,
    institutional: false,
    allowed_collections: %{},
    metadata: %{"role" => "staff", "grace_period_days" => 7}
  },
  %{
    name: "Member (Organization)",
    slug: "member_organization",
    description: "Institutional membership for organizations with extended privileges",
    max_items: 20,
    max_days: 60,
    max_renewals: 3,
    max_reserves: 10,
    max_concurrent_loans: 20,
    fine_per_day: Decimal.new("500.0"),
    max_fine: Decimal.new("100000.0"),
    membership_fee: Decimal.new("2500000.0"),
    currency: "IDR",
    can_reserve: true,
    can_renew: true,
    digital_access: true,
    exhibition_preview_access: true,
    ticket_discount_percent: 25,
    shop_discount_percent: 15,
    max_event_bookings_per_year: 50,
    membership_period_days: 365,
    auto_renew: false,
    recurrence_unit: "days",
    recurrence_interval: 365,
    priority_level: 6,
    is_active: true,
    publicly_listed: true,
    institutional: true,
    allowed_collections: %{},
    metadata: %{"type" => "organization", "grace_period_days" => 14}
  },
  %{
    name: "Member (Verified)",
    slug: "member_verified",
    description: "Verified individual member with standard privileges",
    max_items: 5,
    max_days: 21,
    max_renewals: 1,
    max_reserves: 3,
    max_concurrent_loans: 5,
    fine_per_day: Decimal.new("2000.0"),
    max_fine: Decimal.new("50000.0"),
    membership_fee: Decimal.new("150000.0"),
    currency: "IDR",
    can_reserve: true,
    can_renew: true,
    digital_access: true,
    exhibition_preview_access: false,
    ticket_discount_percent: 10,
    shop_discount_percent: 5,
    max_event_bookings_per_year: 12,
    membership_period_days: 365,
    auto_renew: false,
    recurrence_unit: "days",
    recurrence_interval: 365,
    priority_level: 4,
    is_active: true,
    publicly_listed: true,
    institutional: false,
    allowed_collections: %{},
    metadata: %{"type" => "verified", "grace_period_days" => 3}
  },
  %{
    name: "Member (Affirmation)",
    slug: "member_affirmation",
    description: "Self-declared member with limited privileges",
    max_items: 3,
    max_days: 14,
    max_renewals: 1,
    max_reserves: 2,
    max_concurrent_loans: 3,
    fine_per_day: Decimal.new("1000.0"),
    max_fine: Decimal.new("30000.0"),
    membership_fee: Decimal.new("50000.0"),
    currency: "IDR",
    can_reserve: false,
    can_renew: true,
    digital_access: false,
    exhibition_preview_access: false,
    ticket_discount_percent: 0,
    shop_discount_percent: 0,
    max_event_bookings_per_year: 6,
    membership_period_days: 180,
    auto_renew: false,
    recurrence_unit: "days",
    recurrence_interval: 180,
    priority_level: 2,
    is_active: true,
    publicly_listed: true,
    institutional: false,
    allowed_collections: %{},
    metadata: %{"type" => "affirmation", "grace_period_days" => 2}
  },
  %{
    name: "Guest",
    slug: "guest",
    description: "Temporary guest access with minimal privileges",
    max_items: 1,
    max_days: 7,
    max_renewals: 0,
    max_reserves: 0,
    max_concurrent_loans: 1,
    fine_per_day: Decimal.new("5000.0"),
    max_fine: Decimal.new("25000.0"),
    membership_fee: Decimal.new("0.0"),
    currency: "IDR",
    can_reserve: false,
    can_renew: false,
    digital_access: false,
    exhibition_preview_access: false,
    ticket_discount_percent: 0,
    shop_discount_percent: 0,
    max_event_bookings_per_year: 2,
    membership_period_days: 30,
    auto_renew: false,
    recurrence_unit: nil,
    recurrence_interval: nil,
    priority_level: 1,
    is_active: true,
    publicly_listed: true,
    institutional: false,
    allowed_collections: %{},
    metadata: %{"type" => "guest", "grace_period_days" => 0}
  }
]

# Create member types and store references for admin user
created_member_types =
  Enum.map(list_member_type, fn member_type ->
    case Repo.get_by(MemberType, slug: member_type.slug) do
      nil ->
        %MemberType{}
        |> MemberType.changeset(member_type)
        |> Repo.insert!()

      existing_member_type ->
        existing_member_type
    end
  end)

# Get the Administrator member type for the admin user
admin_member_type = Enum.find(created_member_types, fn mt -> mt.slug == "administrator" end)

# Create the admin user using proper changeset validation
admin_user_attrs = %{
  email: "admin@voile.id",
  fullname: "Voile Administrator",
  username: "admin",
  password: "super_long_password",
  user_type_id: admin_member_type.id,
  confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_naive()
}

admin_user =
  case Repo.get_by(Accounts.User, email: "admin@voile.id") do
    nil ->
      %Accounts.User{}
      |> Accounts.User.registration_changeset(admin_user_attrs,
        hash_password: true,
        validate_email: false
      )
      |> Repo.insert!()

    existing_user ->
      existing_user
  end

# Assign super_admin role to the admin user
alias Voile.Schema.Accounts.Role
alias VoileWeb.Auth.Authorization

super_admin_role = Repo.get_by(Role, name: "super_admin")

if super_admin_role do
  case Authorization.assign_role(admin_user.id, super_admin_role.id) do
    {:ok, _assignment} ->
      IO.puts("✅ Assigned super_admin role to #{admin_user.email}")

    {:error, %Ecto.Changeset{errors: [role_id: {"has already been taken", _}]}} ->
      IO.puts("ℹ️  Admin user already has super_admin role")

    {:error, reason} ->
      IO.puts("⚠️  Failed to assign super_admin role: #{inspect(reason)}")
  end
else
  IO.puts("⚠️  super_admin role not found. Please run authorization seeds first.")
end

# Add Master Location for each items
alias Voile.Schema.Master.Location

list_locations = [
  %{
    location_code: "kandaga-sirkulasi",
    location_name: "Ruang Sirkulasi, Kandaga",
    location_place: "Gd. Grha Kandaga Lantai 3 Universitas Padjadjaran",
    location_type: "circulation",
    description: "Lokasi utama untuk sirkulasi koleksi fisik di Kandaga",
    notes: "Hanya untuk koleksi fisik",
    is_active: true,
    node_id: 20
  },
  %{
    location_code: "kandaga-referensi",
    location_name: "Ruang Referensi, Kandaga",
    location_place: "Gd. Grha Kandaga Lantai 4 Universitas Padjadjaran",
    location_type: "reference",
    description: "Lokasi untuk koleksi referensi di Kandaga",
    notes: "Koleksi tidak boleh dipinjamkan",
    is_active: true,
    node_id: 20
  },
  %{
    location_code: "kandaga-populer",
    location_name: "Ruang Koleksi Populer, Kandaga",
    location_place: "Gd. Grha Kandaga Lantai 4 Universitas Padjadjaran",
    location_type: "popular",
    description: "Lokasi untuk koleksi populer di Kandaga",
    notes: "Koleksi populer untuk peminjaman cepat",
    is_active: true,
    node_id: 20
  },
  %{
    location_code: "kandaga-lama",
    location_name: "Ruang Koleksi Lama, Kandaga",
    location_place: "Gd. Grha Kandaga Lantai 3 Universitas Padjadjaran",
    location_type: "rare_collection",
    description: "Lokasi untuk koleksi lama dan langka di Kandaga",
    notes: "Akses terbatas, hubungi staf untuk bantuan",
    is_active: true,
    node_id: 20
  }
]

Enum.each(list_locations, fn location_attrs ->
  case Repo.get_by(Location, location_code: location_attrs.location_code) do
    nil ->
      %Location{}
      |> Location.changeset(location_attrs)
      |> Repo.insert!()
      |> (fn _ -> IO.puts("✅ Created location #{location_attrs.location_code}") end).()

    _existing_location ->
      IO.puts("ℹ️  Location #{location_attrs.location_code} already exists")
  end
end)
