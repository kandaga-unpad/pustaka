# SPDX-FileCopyrightText: 2024–present Chrisna Adhi Pranoto
# SPDX-License-Identifier: Apache-2.0

defmodule Voile do
  @moduledoc """
  Voile keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  defdelegate list_users_paginated(), to: Voile.Schema.Accounts
  defdelegate get_user!(id), to: Voile.Schema.Accounts
  defdelegate get_user_by_email(email), to: Voile.Schema.Accounts

  # Catalog context - core business logic
  defdelegate list_collections_paginated(
                page \\ 1,
                per_page \\ 10,
                search \\ nil,
                filters \\ %{}
              ),
              to: Voile.Schema.Catalog

  defdelegate get_collection!(id), to: Voile.Schema.Catalog
  defdelegate create_collection(attrs \\ %{}), to: Voile.Schema.Catalog
  defdelegate create_collection(attrs, user_id), to: Voile.Schema.Catalog
  defdelegate update_collection(collection, attrs), to: Voile.Schema.Catalog
  defdelegate update_collection(collection, attrs, user_id), to: Voile.Schema.Catalog

  defdelegate list_pending_collections_paginated(page \\ 1, per_page \\ 10, user \\ nil),
    to: Voile.Schema.Catalog

  # System context - nodes and settings
  defdelegate list_nodes(), to: Voile.Schema.System
  defdelegate get_node!(id), to: Voile.Schema.System

  # Master data context
  defdelegate list_mst_creator(), to: Voile.Schema.Master

  # Search context
  defdelegate search_collections_for_suggestions(query, opts \\ []), to: Voile.Search.Collections

  # OAI-PMH context for metadata harvesting
  defdelegate identify(base_url), to: Voile.OaiPmh

  # Email queue for notifications
  defdelegate enqueue_email(email_fn, opts \\ []),
    to: Voile.Notifications.EmailQueue,
    as: :enqueue

  # Additional user CRUD operations
  defdelegate create_user(attrs), to: Voile.Schema.Accounts
  defdelegate update_user(user, attrs), to: Voile.Schema.Accounts
  defdelegate delete_user(user), to: Voile.Schema.Accounts
  defdelegate change_user(user, attrs \\ %{}), to: Voile.Schema.Accounts

  # Additional collection CRUD operations
  defdelegate delete_collection(collection), to: Voile.Schema.Catalog
  defdelegate delete_collection(collection, user_id), to: Voile.Schema.Catalog
  defdelegate change_collection(collection, attrs \\ %{}), to: Voile.Schema.Catalog

  defdelegate approve_collection(collection, reviewer_user, notes \\ nil),
    to: Voile.Schema.Catalog

  defdelegate reject_collection(collection, reviewer_user, reason), to: Voile.Schema.Catalog

  # Item CRUD operations
  defdelegate list_items(), to: Voile.Schema.Catalog

  defdelegate list_items_paginated(page \\ 1, per_page \\ 10, search \\ nil, filters \\ %{}),
    to: Voile.Schema.Catalog

  defdelegate get_item!(id), to: Voile.Schema.Catalog
  defdelegate create_item(attrs \\ %{}), to: Voile.Schema.Catalog
  defdelegate create_item(attrs, user_id), to: Voile.Schema.Catalog
  defdelegate update_item(item, attrs), to: Voile.Schema.Catalog
  defdelegate update_item(item, attrs, user_id), to: Voile.Schema.Catalog
  defdelegate delete_item(item), to: Voile.Schema.Catalog
  defdelegate delete_item(item, user_id), to: Voile.Schema.Catalog
  defdelegate change_item(item, attrs \\ %{}), to: Voile.Schema.Catalog

  # Additional node CRUD operations
  defdelegate create_node(attrs \\ %{}), to: Voile.Schema.System
  defdelegate update_node(node, attrs), to: Voile.Schema.System
  defdelegate delete_node(node), to: Voile.Schema.System
  defdelegate change_node(node, attrs \\ %{}), to: Voile.Schema.System

  # Settings CRUD operations
  defdelegate list_settings(), to: Voile.Schema.System
  defdelegate get_setting!(id), to: Voile.Schema.System
  defdelegate create_setting(attrs \\ %{}), to: Voile.Schema.System
  defdelegate update_setting(setting, attrs), to: Voile.Schema.System
  defdelegate delete_setting(setting), to: Voile.Schema.System
  defdelegate change_setting(setting, attrs \\ %{}), to: Voile.Schema.System
  defdelegate get_setting_by_name(name), to: Voile.Schema.System
  defdelegate get_setting_value(name, default \\ nil), to: Voile.Schema.System
  defdelegate upsert_setting(name, value), to: Voile.Schema.System

  # Additional master data CRUD operations
  defdelegate list_mst_creator_paginated(page \\ 1, per_page \\ 10), to: Voile.Schema.Master
  defdelegate get_creator!(id), to: Voile.Schema.Master
  defdelegate get_or_create_creator(attrs \\ %{}), to: Voile.Schema.Master
  defdelegate update_creator(creator, attrs), to: Voile.Schema.Master
  defdelegate delete_creator(creator), to: Voile.Schema.Master
  defdelegate change_creator(creator, attrs \\ %{}), to: Voile.Schema.Master

  defdelegate list_mst_frequency(), to: Voile.Schema.Master
  defdelegate list_mst_frequency_paginated(page \\ 1, per_page \\ 10), to: Voile.Schema.Master
  defdelegate get_frequency!(id), to: Voile.Schema.Master
  defdelegate create_frequency(attrs \\ %{}), to: Voile.Schema.Master
  defdelegate update_frequency(frequency, attrs), to: Voile.Schema.Master
  defdelegate delete_frequency(frequency), to: Voile.Schema.Master
  defdelegate change_frequency(frequency, attrs \\ %{}), to: Voile.Schema.Master

  defdelegate list_mst_member_types(), to: Voile.Schema.Master
  defdelegate list_mst_member_types_paginated(page \\ 1, per_page \\ 10), to: Voile.Schema.Master
  defdelegate get_member_type!(id), to: Voile.Schema.Master
  defdelegate create_member_type(attrs \\ %{}), to: Voile.Schema.Master
  defdelegate update_member_type(member_type, attrs), to: Voile.Schema.Master
  defdelegate delete_member_type(member_type), to: Voile.Schema.Master
  defdelegate change_member_type(member_type, attrs \\ %{}), to: Voile.Schema.Master

  # Form collection helper functions
  defdelegate add_property_to_form(prop_id, socket),
    to: VoileWeb.Dashboard.Catalog.CollectionLive.FormCollectionHelper

  defdelegate add_item_to_form(socket),
    to: VoileWeb.Dashboard.Catalog.CollectionLive.FormCollectionHelper

  defdelegate assign_selected_creator(id, socket),
    to: VoileWeb.Dashboard.Catalog.CollectionLive.FormCollectionHelper

  defdelegate create_or_select_creator(creator_name, socket),
    to: VoileWeb.Dashboard.Catalog.CollectionLive.FormCollectionHelper

  defdelegate clear_selected_creator(socket),
    to: VoileWeb.Dashboard.Catalog.CollectionLive.FormCollectionHelper

  defdelegate delete_unsaved_field_at(index_str, socket),
    to: VoileWeb.Dashboard.Catalog.CollectionLive.FormCollectionHelper

  defdelegate delete_unsaved_item_at(index_str, socket),
    to: VoileWeb.Dashboard.Catalog.CollectionLive.FormCollectionHelper

  defdelegate delete_existing_field(id, socket),
    to: VoileWeb.Dashboard.Catalog.CollectionLive.FormCollectionHelper

  defdelegate delete_existing_item(id, socket),
    to: VoileWeb.Dashboard.Catalog.CollectionLive.FormCollectionHelper

  defdelegate confirm_field_deletion(id, socket),
    to: VoileWeb.Dashboard.Catalog.CollectionLive.FormCollectionHelper

  defdelegate confirm_item_deletion(id, socket),
    to: VoileWeb.Dashboard.Catalog.CollectionLive.FormCollectionHelper

  defdelegate search_properties(query, socket),
    to: VoileWeb.Dashboard.Catalog.CollectionLive.FormCollectionHelper

  defdelegate handle_delete_thumbnail(params, socket),
    to: VoileWeb.Dashboard.Catalog.CollectionLive.FormCollectionHelper

  defdelegate handle_thumbnail_progress(type, entry, socket),
    to: VoileWeb.Dashboard.Catalog.CollectionLive.FormCollectionHelper

  defdelegate save_collection(socket, action, collection_params),
    to: VoileWeb.Dashboard.Catalog.CollectionLive.FormCollectionHelper

  defdelegate save_collection_as_draft(socket, action, collection_params),
    to: VoileWeb.Dashboard.Catalog.CollectionLive.FormCollectionHelper

  defdelegate handle_add_thumbnail_from_url(url, socket),
    to: VoileWeb.Dashboard.Catalog.CollectionLive.FormCollectionHelper
end
