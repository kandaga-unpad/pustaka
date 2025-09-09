alias Voile.Repo
alias Voile.Schema.Accounts
alias Voile.Schema.Accounts.UserRole
alias Voile.Schema.Master.MemberType

# First, create comprehensive user roles from seeds.exs
user_roles = [
  %{
    name: "Super Administrator Dev",
    description: "Super Administrator",
    permissions: %{
      "collection" => %{"create" => true, "read" => true, "update" => true, "delete" => true},
      "item" => %{"create" => true, "read" => true, "update" => true, "delete" => true},
      "media" => %{"create" => true, "read" => true, "update" => true, "delete" => true},
      "system" => %{"create" => true, "read" => true, "update" => true, "delete" => true},
      "users" => %{"create" => true, "read" => true, "update" => true, "delete" => true},
      "roles" => %{"create" => true, "read" => true, "update" => true, "delete" => true}
    }
  },
  %{
    name: "Admin Node",
    description: "Full administrative access to node operations",
    permissions: %{
      "users" => %{"create" => true, "read" => true, "update" => true, "delete" => true},
      "roles" => %{"create" => true, "read" => true, "update" => true, "delete" => true},
      "collections" => %{"create" => true, "read" => true, "update" => true, "delete" => true},
      "system" => %{"create" => true, "read" => true, "update" => true, "delete" => true}
    }
  },
  %{
    name: "Koordinator Koleksi",
    description: "Collection coordinator with management access",
    permissions: %{
      "collections" => %{"create" => true, "read" => true, "update" => true, "delete" => true},
      "users" => %{"create" => false, "read" => true, "update" => false, "delete" => false}
    }
  },
  %{
    name: "Pustakawan (Koordinator)",
    description: "Lead librarian with coordination responsibilities",
    permissions: %{
      "collections" => %{"create" => true, "read" => true, "update" => true, "delete" => false},
      "circulation" => %{"create" => true, "read" => true, "update" => true, "delete" => false},
      "users" => %{"create" => false, "read" => true, "update" => false, "delete" => false}
    }
  },
  %{
    name: "Pustakawan Sirkulasi",
    description: "Circulation librarian",
    permissions: %{
      "circulation" => %{"create" => true, "read" => true, "update" => true, "delete" => false},
      "collections" => %{"create" => false, "read" => true, "update" => false, "delete" => false}
    }
  },
  %{
    name: "Pustakawan Pengolahan (Buku)",
    description: "Book processing librarian",
    permissions: %{
      "books" => %{"create" => true, "read" => true, "update" => true, "delete" => false},
      "cataloging" => %{"create" => true, "read" => true, "update" => true, "delete" => false}
    }
  },
  %{
    name: "Pustakawan Referensi",
    description: "Reference librarian",
    permissions: %{
      "reference" => %{"create" => true, "read" => true, "update" => true, "delete" => false},
      "collections" => %{"create" => false, "read" => true, "update" => false, "delete" => false}
    }
  },
  %{
    name: "Pustakawan Sistem (TI)",
    description: "IT systems librarian",
    permissions: %{
      "system" => %{"create" => true, "read" => true, "update" => true, "delete" => false},
      "users" => %{"create" => false, "read" => true, "update" => true, "delete" => false}
    }
  },
  %{
    name: "Pustakawan Pengolahan (ETD)",
    description: "Electronic thesis and dissertation processing librarian",
    permissions: %{
      "etd" => %{"create" => true, "read" => true, "update" => true, "delete" => false},
      "cataloging" => %{"create" => true, "read" => true, "update" => true, "delete" => false}
    }
  },
  %{
    name: "Pustakawan (General)",
    description: "General librarian",
    permissions: %{
      "collections" => %{"create" => false, "read" => true, "update" => false, "delete" => false},
      "circulation" => %{"create" => true, "read" => true, "update" => true, "delete" => false}
    }
  },
  %{
    name: "Pustakawan Koleksi Populer",
    description: "Popular collection librarian",
    permissions: %{
      "popular_collections" => %{
        "create" => true,
        "read" => true,
        "update" => true,
        "delete" => false
      },
      "circulation" => %{"create" => true, "read" => true, "update" => true, "delete" => false}
    }
  },
  %{
    name: "Arsiparis (Koordinator)",
    description: "Head archivist",
    permissions: %{
      "archives" => %{"create" => true, "read" => true, "update" => true, "delete" => true},
      "users" => %{"create" => false, "read" => true, "update" => false, "delete" => false}
    }
  },
  %{
    name: "Arsiparis",
    description: "Archivist",
    permissions: %{
      "archives" => %{"create" => true, "read" => true, "update" => true, "delete" => false}
    }
  },
  %{
    name: "Kurator Museum",
    description: "Museum curator",
    permissions: %{
      "museum" => %{"create" => true, "read" => true, "update" => true, "delete" => false},
      "exhibitions" => %{"create" => true, "read" => true, "update" => true, "delete" => false}
    }
  },
  %{
    name: "Kurator Galeri",
    description: "Gallery curator",
    permissions: %{
      "gallery" => %{"create" => true, "read" => true, "update" => true, "delete" => false},
      "exhibitions" => %{"create" => true, "read" => true, "update" => true, "delete" => false}
    }
  }
]

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

# Create all user roles and store the Super Administrator Dev role for admin user
created_roles =
  Enum.map(user_roles, fn role ->
    case Repo.get_by(UserRole, name: role.name) do
      nil ->
        Repo.insert!(%UserRole{
          name: role.name,
          description: role.description,
          permissions: role.permissions
        })

      existing_role ->
        existing_role
    end
  end)

# Get the Super Administrator Dev role for the admin user
super_admin_role = Enum.find(created_roles, fn role -> role.name == "Super Administrator Dev" end)

# Get the Administrator member type for the admin user
admin_member_type = Enum.find(created_member_types, fn mt -> mt.slug == "administrator" end)

# Create the admin user using proper changeset validation
admin_user_attrs = %{
  email: "admin@voile.id",
  fullname: "Voile Administrator",
  username: "admin",
  password: "super_long_password",
  user_role_id: super_admin_role.id,
  user_type_id: admin_member_type.id,
  confirmed_at: Voile.Migration.Common.utc_now_db()
}

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
