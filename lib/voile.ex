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

  # ============================================================================
  # ACCOUNTS CONTEXT - Additional user functions
  # ============================================================================

  # User authentication and retrieval
  defdelegate get_user_by_email_and_password(email, password), to: Voile.Schema.Accounts
  defdelegate get_user_by_login_and_password(login, password), to: Voile.Schema.Accounts
  defdelegate get_user_by_identifier(identifier), to: Voile.Schema.Accounts
  defdelegate get_user_by_email_or_register(user), to: Voile.Schema.Accounts
  defdelegate create_user_from_oauth(attrs), to: Voile.Schema.Accounts
  defdelegate get_user(id), to: Voile.Schema.Accounts
  defdelegate list_users(), to: Voile.Schema.Accounts

  # User profile management
  defdelegate change_user_onboarding(user, attrs \\ %{}), to: Voile.Schema.Accounts
  defdelegate update_user_onboarding(user, attrs), to: Voile.Schema.Accounts
  defdelegate get_user_with_associations_by_identifier(identifier), to: Voile.Schema.Accounts

  # ============================================================================
  # CATALOG CONTEXT - Additional collection and item functions
  # ============================================================================

  defdelegate list_collections(), to: Voile.Schema.Catalog
  defdelegate barcode_prefix_exists(prefix, exclude_id \\ nil), to: Voile.Schema.Catalog
  defdelegate get_collections_by_barcode_prefix(prefix), to: Voile.Schema.Catalog

  defdelegate list_collections_for_user(
                user,
                page \\ 1,
                per_page \\ 10,
                search \\ nil,
                filters \\ %{}
              ),
              to: Voile.Schema.Catalog

  defdelegate apply_role_based_filters(user, filters), to: Voile.Schema.Catalog
  defdelegate is_user_admin?(user), to: Voile.Schema.Catalog

  # ============================================================================
  # SYSTEM CONTEXT - Additional node and system functions
  # ============================================================================

  defdelegate get_node_basic(node_id), to: Voile.Schema.System
  defdelegate get_default_node(), to: Voile.Schema.System
  defdelegate update_node_rules(node, attrs), to: Voile.Schema.System

  # System logs
  defdelegate list_system_logs(), to: Voile.Schema.System
  defdelegate get_system_log!(id), to: Voile.Schema.System
  defdelegate create_system_log(attrs \\ %{}), to: Voile.Schema.System
  defdelegate update_system_log(system_log, attrs), to: Voile.Schema.System
  defdelegate delete_system_log(system_log), to: Voile.Schema.System
  defdelegate change_system_log(system_log, attrs \\ %{}), to: Voile.Schema.System

  # Collection logs
  defdelegate list_collection_logs(), to: Voile.Schema.System
  defdelegate get_collection_log!(id), to: Voile.Schema.System
  defdelegate create_collection_log(attrs \\ %{}), to: Voile.Schema.System
  defdelegate update_collection_log(collection_log, attrs), to: Voile.Schema.System
  defdelegate delete_collection_log(collection_log), to: Voile.Schema.System
  defdelegate change_collection_log(collection_log, attrs \\ %{}), to: Voile.Schema.System

  # ============================================================================
  # MASTER DATA CONTEXT - Additional master data functions
  # ============================================================================

  defdelegate search_mst_creator(query, limit \\ 10), to: Voile.Schema.Master
  defdelegate search_mst_creator_names(query, limit \\ 10, offset \\ 0), to: Voile.Schema.Master
  defdelegate get_member_type_by_slug(slug), to: Voile.Schema.Master
  defdelegate list_mst_locations(), to: Voile.Schema.Master
  defdelegate list_locations(opts \\ []), to: Voile.Schema.Master
  defdelegate list_mst_locations_paginated(page \\ 1, per_page \\ 10), to: Voile.Schema.Master
  defdelegate get_locations!(id), to: Voile.Schema.Master
  defdelegate create_locations(attrs \\ %{}), to: Voile.Schema.Master
  defdelegate update_locations(location, attrs), to: Voile.Schema.Master
  defdelegate delete_locations(location), to: Voile.Schema.Master
  defdelegate change_locations(location, attrs \\ %{}), to: Voile.Schema.Master

  # ============================================================================
  # METADATA CONTEXT - Vocabularies, Properties, Resource Classes, Templates
  # ============================================================================

  # Vocabulary functions
  defdelegate list_metadata_vocabularies(), to: Voile.Schema.Metadata
  defdelegate get_vocabulary!(id), to: Voile.Schema.Metadata
  defdelegate create_vocabulary(attrs \\ %{}), to: Voile.Schema.Metadata
  defdelegate update_vocabulary(vocabulary, attrs), to: Voile.Schema.Metadata
  defdelegate delete_vocabulary(vocabulary), to: Voile.Schema.Metadata
  defdelegate change_vocabulary(vocabulary, attrs \\ %{}), to: Voile.Schema.Metadata

  # Property functions
  defdelegate list_metadata_properties(), to: Voile.Schema.Metadata
  defdelegate list_metadata_properties_by_vocabulary(), to: Voile.Schema.Metadata
  defdelegate list_metadata_properties_by_vocabulary(vocabulary_id), to: Voile.Schema.Metadata
  defdelegate list_metadata_properties_paginated(page, per_page), to: Voile.Schema.Metadata

  defdelegate list_metadata_properties_by_vocabulary_paginated(vocabulary_id, page, per_page),
    to: Voile.Schema.Metadata

  defdelegate get_property!(id), to: Voile.Schema.Metadata
  defdelegate create_property(attrs \\ %{}), to: Voile.Schema.Metadata
  defdelegate update_property(property, attrs), to: Voile.Schema.Metadata
  defdelegate delete_property(property), to: Voile.Schema.Metadata
  defdelegate change_property(property, attrs \\ %{}), to: Voile.Schema.Metadata
  defdelegate search_property(term), to: Voile.Schema.Metadata

  # Resource Class functions
  defdelegate list_resource_class(), to: Voile.Schema.Metadata

  defdelegate list_resource_classes_paginated(page, per_page, search_keyword),
    to: Voile.Schema.Metadata

  defdelegate list_glam_type_based_resource_classes(), to: Voile.Schema.Metadata

  defdelegate list_glam_type_based_resource_classes(glam_type, page, per_page),
    to: Voile.Schema.Metadata

  defdelegate get_resource_class!(id), to: Voile.Schema.Metadata
  defdelegate create_resource_class(attrs \\ %{}), to: Voile.Schema.Metadata
  defdelegate update_resource_class(resource_class, attrs), to: Voile.Schema.Metadata
  defdelegate delete_resource_class(resource_class), to: Voile.Schema.Metadata
  defdelegate change_resource_class(resource_class, attrs \\ %{}), to: Voile.Schema.Metadata

  # Resource Template functions
  defdelegate list_resource_template(), to: Voile.Schema.Metadata
  defdelegate list_resource_templates_paginated(page, per_page), to: Voile.Schema.Metadata
  defdelegate get_resource_template!(id), to: Voile.Schema.Metadata
  defdelegate create_resource_template(attrs \\ %{}), to: Voile.Schema.Metadata
  defdelegate update_resource_template(resource_template, attrs), to: Voile.Schema.Metadata
  defdelegate delete_resource_template(resource_template), to: Voile.Schema.Metadata
  defdelegate change_resource_template(resource_template, attrs \\ %{}), to: Voile.Schema.Metadata

  # Resource Template Property functions
  defdelegate list_resource_template_property(), to: Voile.Schema.Metadata
  defdelegate get_resource_template_property!(id), to: Voile.Schema.Metadata
  defdelegate create_resource_template_property(attrs \\ %{}), to: Voile.Schema.Metadata

  defdelegate update_resource_template_property(resource_template_property, attrs),
    to: Voile.Schema.Metadata

  defdelegate delete_resource_template_property(resource_template_property),
    to: Voile.Schema.Metadata

  defdelegate change_resource_template_property(resource_template_property, attrs \\ %{}),
    to: Voile.Schema.Metadata

  # Metadata page functions
  defdelegate list_metadata_page(type, page, per_page), to: Voile.Schema.Metadata

  # ============================================================================
  # SEARCH CONTEXT - Collection and item search
  # ============================================================================

  defdelegate search_collections(query_string, opts \\ %{}), to: Voile.Schema.Search
  defdelegate search_items(query_string, opts \\ %{}), to: Voile.Schema.Search
  defdelegate universal_search(query_string, opts \\ %{}), to: Voile.Schema.Search
  defdelegate advanced_search(search_params, opts \\ %{}), to: Voile.Schema.Search

  # ============================================================================
  # STOCK OPNAME CONTEXT - Inventory session management
  # ============================================================================

  # Session management
  defdelegate create_session(attrs \\ %{}, user), to: Voile.Schema.StockOpname

  defdelegate list_sessions(page \\ 1, per_page \\ 10, filters \\ %{}),
    to: Voile.Schema.StockOpname

  defdelegate get_session!(id), to: Voile.Schema.StockOpname
  defdelegate get_session_without_items!(id), to: Voile.Schema.StockOpname
  defdelegate update_session(session, attrs, user), to: Voile.Schema.StockOpname
  defdelegate start_session(session, admin_user), to: Voile.Schema.StockOpname
  defdelegate delete_session(session, user), to: Voile.Schema.StockOpname
  defdelegate cancel_session(session, admin_user), to: Voile.Schema.StockOpname

  # Librarian assignment
  defdelegate list_session_librarians(session), to: Voile.Schema.StockOpname
  defdelegate assign_librarians(session, user_ids, admin_user), to: Voile.Schema.StockOpname

  defdelegate assign_librarian(session, librarian_id, assigned_by_user),
    to: Voile.Schema.StockOpname

  defdelegate remove_librarian(assignment_id, removed_by_user), to: Voile.Schema.StockOpname

  defdelegate admin_complete_librarian_assignment(assignment_id, admin_user),
    to: Voile.Schema.StockOpname

  defdelegate list_available_librarians(session, current_user), to: Voile.Schema.StockOpname

  # Librarian work management
  defdelegate count_session_items(session), to: Voile.Schema.StockOpname
  defdelegate all_librarians_completed?(session), to: Voile.Schema.StockOpname
  defdelegate start_librarian_work(session, user), to: Voile.Schema.StockOpname
  defdelegate complete_librarian_work(session, user, notes \\ nil), to: Voile.Schema.StockOpname
  defdelegate cancel_librarian_completion(session, user), to: Voile.Schema.StockOpname

  defdelegate admin_complete_librarian_work(session, user, notes \\ nil),
    to: Voile.Schema.StockOpname

  defdelegate get_session_librarian_report(session), to: Voile.Schema.StockOpname
  defdelegate get_librarian_progress(session, user), to: Voile.Schema.StockOpname

  # Item scanning and checking
  defdelegate find_items_for_scanning(session, search_term), to: Voile.Schema.StockOpname
  defdelegate add_item_to_session(session, item_id, user), to: Voile.Schema.StockOpname

  defdelegate add_leftover_items_to_session(session_id, item_ids, user),
    to: Voile.Schema.StockOpname

  defdelegate check_item_with_collection(session, item_id, collection_id, changes, notes, user),
    to: Voile.Schema.StockOpname

  defdelegate check_item(session, opname_item_id, changes, notes, user),
    to: Voile.Schema.StockOpname

  # Session statistics and reporting
  defdelegate get_session_statistics(session), to: Voile.Schema.StockOpname
  defdelegate recalculate_session_counters(session), to: Voile.Schema.StockOpname
  defdelegate list_session_items(session, check_status \\ nil), to: Voile.Schema.StockOpname

  defdelegate list_recent_checked_items_by_user(session, user, limit \\ 10),
    to: Voile.Schema.StockOpname

  defdelegate list_items_with_changes(session), to: Voile.Schema.StockOpname

  defdelegate list_items_with_changes_paginated(session, page \\ 1, per_page \\ 20),
    to: Voile.Schema.StockOpname

  defdelegate list_missing_items(session), to: Voile.Schema.StockOpname

  defdelegate list_missing_items_paginated(session, page \\ 1, per_page \\ 20),
    to: Voile.Schema.StockOpname

  defdelegate list_session_items_paginated(session, page \\ 1, per_page \\ 20, filters \\ %{}),
    to: Voile.Schema.StockOpname

  # Session completion and review
  defdelegate complete_session(session, admin_user), to: Voile.Schema.StockOpname

  defdelegate list_sessions_pending_review(page \\ 1, per_page \\ 10),
    to: Voile.Schema.StockOpname

  defdelegate get_session_review_summary(session), to: Voile.Schema.StockOpname
  defdelegate approve_session(session, admin_user, notes \\ nil), to: Voile.Schema.StockOpname
  defdelegate reject_session(session, admin_user, reason), to: Voile.Schema.StockOpname
  defdelegate request_session_revision(session, admin_user, notes), to: Voile.Schema.StockOpname

  # ============================================================================
  # LIBRARY/CIRCULATION CONTEXT - Circulation, loans, reservations, fines
  # ============================================================================

  # Circulation History
  defdelegate list_circulation_history_paginated(page \\ 1, per_page \\ 10),
    to: Voile.Schema.Library.Circulation

  defdelegate list_circulation_history_paginated_with_filters(
                page \\ 1,
                per_page \\ 10,
                filters \\ %{}
              ),
              to: Voile.Schema.Library.Circulation

  defdelegate get_circulation_history!(id), to: Voile.Schema.Library.Circulation
  defdelegate get_circulation_history(id), to: Voile.Schema.Library.Circulation
  defdelegate create_circulation_history(attrs \\ %{}), to: Voile.Schema.Library.Circulation

  defdelegate update_circulation_history(circulation_history, attrs),
    to: Voile.Schema.Library.Circulation

  defdelegate delete_circulation_history(circulation_history),
    to: Voile.Schema.Library.Circulation

  defdelegate change_circulation_history(circulation_history, attrs \\ %{}),
    to: Voile.Schema.Library.Circulation

  # Fines
  defdelegate list_fines(), to: Voile.Schema.Library.Circulation

  defdelegate list_fines_paginated(page \\ 1, per_page \\ 10),
    to: Voile.Schema.Library.Circulation

  defdelegate list_fines_paginated_with_filters(page \\ 1, per_page \\ 10, filters \\ %{}),
    to: Voile.Schema.Library.Circulation

  defdelegate get_fine!(id), to: Voile.Schema.Library.Circulation
  defdelegate get_total_fine_by_user(user_id), to: Voile.Schema.Library.Circulation
  defdelegate count_active_fines_by_user(user_id), to: Voile.Schema.Library.Circulation
  defdelegate create_fine(attrs \\ %{}), to: Voile.Schema.Library.Circulation
  defdelegate update_fine(fine, attrs), to: Voile.Schema.Library.Circulation
  defdelegate delete_fine(fine), to: Voile.Schema.Library.Circulation
  defdelegate change_fine(fine, attrs \\ %{}), to: Voile.Schema.Library.Circulation

  # Requisitions
  defdelegate list_requisitions(), to: Voile.Schema.Library.Circulation

  defdelegate list_requisitions_paginated(page \\ 1, per_page \\ 10),
    to: Voile.Schema.Library.Circulation

  defdelegate get_requisition!(id), to: Voile.Schema.Library.Circulation
  defdelegate create_requisition(attrs), to: Voile.Schema.Library.Circulation
  defdelegate create_requisition(requested_by_id, attrs), to: Voile.Schema.Library.Circulation
  defdelegate update_requisition(requisition, attrs), to: Voile.Schema.Library.Circulation
  defdelegate delete_requisition(requisition), to: Voile.Schema.Library.Circulation
  defdelegate change_requisition(requisition, attrs \\ %{}), to: Voile.Schema.Library.Circulation

  defdelegate assign_requisition(requisition_id, assigned_to_id),
    to: Voile.Schema.Library.Circulation

  defdelegate fulfill_requisition(requisition_id), to: Voile.Schema.Library.Circulation

  defdelegate approve_requisition(requisition_id, staff_notes \\ nil),
    to: Voile.Schema.Library.Circulation

  defdelegate reject_requisition(requisition_id, staff_notes \\ nil),
    to: Voile.Schema.Library.Circulation

  # Reservations
  defdelegate list_reservations(), to: Voile.Schema.Library.Circulation

  defdelegate list_reservations_paginated(page \\ 1, per_page \\ 10),
    to: Voile.Schema.Library.Circulation

  defdelegate get_reservation!(id), to: Voile.Schema.Library.Circulation
  defdelegate create_reservation(attrs \\ %{}), to: Voile.Schema.Library.Circulation
  defdelegate create_reservation(member_id, item_id), to: Voile.Schema.Library.Circulation

  defdelegate create_collection_reservation(member_id, collection_id, attrs \\ %{}),
    to: Voile.Schema.Library.Circulation

  defdelegate update_reservation(reservation, attrs), to: Voile.Schema.Library.Circulation
  defdelegate delete_reservation(reservation), to: Voile.Schema.Library.Circulation
  defdelegate change_reservation(reservation, attrs \\ %{}), to: Voile.Schema.Library.Circulation

  defdelegate cancel_reservation(reservation_id, reason \\ nil),
    to: Voile.Schema.Library.Circulation

  defdelegate mark_reservation_available(reservation_id, processed_by_id),
    to: Voile.Schema.Library.Circulation

  defdelegate fulfill_reservation(reservation_id, librarian_id, attrs \\ %{}),
    to: Voile.Schema.Library.Circulation

  defdelegate list_member_reservations(member_id), to: Voile.Schema.Library.Circulation
  defdelegate list_expired_reservations(), to: Voile.Schema.Library.Circulation

  # Transactions
  defdelegate list_transactions(), to: Voile.Schema.Library.Circulation
  defdelegate count_list_active_transactions(id), to: Voile.Schema.Library.Circulation

  defdelegate list_transactions_paginated(page \\ 1, per_page \\ 10),
    to: Voile.Schema.Library.Circulation

  defdelegate list_transaction_paginated_with_filter(page \\ 1, per_page \\ 10, filters \\ %{}),
    to: Voile.Schema.Library.Circulation

  defdelegate get_transaction!(id), to: Voile.Schema.Library.Circulation
  defdelegate get_transaction(id), to: Voile.Schema.Library.Circulation
  defdelegate get_active_transaction_by_item(item_id), to: Voile.Schema.Library.Circulation
  defdelegate create_transaction(attrs \\ %{}), to: Voile.Schema.Library.Circulation
  defdelegate update_transaction(transaction, attrs), to: Voile.Schema.Library.Circulation
  defdelegate delete_transaction(transaction), to: Voile.Schema.Library.Circulation
  defdelegate change_transaction(transaction, attrs \\ %{}), to: Voile.Schema.Library.Circulation

  # Checkout and return
  defdelegate checkout_item(member_id, item_id, librarian_id, attrs \\ %{}),
    to: Voile.Schema.Library.Circulation

  defdelegate return_item(transaction_id, librarian_id, attrs \\ %{}),
    to: Voile.Schema.Library.Circulation

  defdelegate renew_transaction(transaction_id, librarian_id, attrs \\ %{}),
    to: Voile.Schema.Library.Circulation

  # Member transactions and reservations
  defdelegate list_member_active_transactions(member_id), to: Voile.Schema.Library.Circulation

  defdelegate list_member_active_transactions_paginated(member_id, page \\ 1, per_page \\ 10),
    to: Voile.Schema.Library.Circulation

  defdelegate list_overdue_transactions(), to: Voile.Schema.Library.Circulation
  defdelegate list_transactions_due_soon(days \\ 3), to: Voile.Schema.Library.Circulation

  defdelegate list_members_with_active_loans_paginated(page \\ 1, per_page \\ 10, filters \\ %{}),
    to: Voile.Schema.Library.Circulation

  # Fine management
  defdelegate pay_fine(
                fine_id,
                payment_amount,
                payment_method,
                processed_by_id,
                receipt_number \\ nil
              ),
              to: Voile.Schema.Library.Circulation

  defdelegate waive_fine(fine_id, reason, waived_by_id), to: Voile.Schema.Library.Circulation
  defdelegate list_member_unpaid_fines(member_id), to: Voile.Schema.Library.Circulation
  defdelegate count_member_unpaid_fines(member_id), to: Voile.Schema.Library.Circulation
  defdelegate sum_member_unpaid_fines(member_id), to: Voile.Schema.Library.Circulation

  defdelegate list_member_unpaid_fines_paginated(member_id, page \\ 1, per_page \\ 10),
    to: Voile.Schema.Library.Circulation

  defdelegate list_member_all_fines(member_id), to: Voile.Schema.Library.Circulation

  defdelegate list_member_paid_fines_paginated(member_id, page \\ 1, per_page \\ 10),
    to: Voile.Schema.Library.Circulation

  defdelegate list_member_transaction_history_paginated(member_id, page \\ 1, per_page \\ 10),
    to: Voile.Schema.Library.Circulation

  defdelegate get_fine_by_transaction(transaction_id), to: Voile.Schema.Library.Circulation
  defdelegate get_fine_with_details(fine_id), to: Voile.Schema.Library.Circulation
  defdelegate get_member_outstanding_fine_amount(member_id), to: Voile.Schema.Library.Circulation

  # Circulation history
  defdelegate list_circulation_history(limit \\ 100), to: Voile.Schema.Library.Circulation
  defdelegate get_item_history(item_id), to: Voile.Schema.Library.Circulation
  defdelegate get_member_history(member_id), to: Voile.Schema.Library.Circulation

  defdelegate list_circulation_history_paginated_with_filters_by_member(
                member_id,
                page \\ 1,
                per_page \\ 10,
                opts \\ []
              ),
              to: Voile.Schema.Library.Circulation

  # Member type and privileges
  defdelegate list_active_member_types(), to: Voile.Schema.Library.Circulation

  defdelegate calculate_membership_expiry(member_type, start_date \\ nil),
    to: Voile.Schema.Library.Circulation

  defdelegate member_privileges_suspended?(member_id), to: Voile.Schema.Library.Circulation

  # Recommendations
  defdelegate get_member_recommendations(member_id, limit \\ 10),
    to: Voile.Schema.Library.Circulation

  # Background jobs
  defdelegate process_overdue_items(), to: Voile.Schema.Library.Circulation
  defdelegate expire_old_reservations(), to: Voile.Schema.Library.Circulation
  defdelegate process_auto_renewals(), to: Voile.Schema.Library.Circulation

  # Item suggestions
  defdelegate suggest_items_by_code_or_collection(query, opts \\ []),
    to: Voile.Schema.Library.Circulation

  # Payment functions
  defdelegate get_payment!(id), to: Voile.Schema.Library.Circulation
  defdelegate get_payment_by_external_id(external_id), to: Voile.Schema.Library.Circulation
  defdelegate list_fine_payments(fine_id), to: Voile.Schema.Library.Circulation
  defdelegate list_member_payments(member_id, opts \\ []), to: Voile.Schema.Library.Circulation
  defdelegate handle_payment_webhook(webhook_payload), to: Voile.Schema.Library.Circulation

  defdelegate mark_payment_as_paid(payment_id, processed_by_id),
    to: Voile.Schema.Library.Circulation

  defdelegate cancel_payment(payment_id, reason \\ nil), to: Voile.Schema.Library.Circulation
  defdelegate get_pending_payment_for_fine(fine_id), to: Voile.Schema.Library.Circulation

  defdelegate create_payment_link_for_fine(fine_id, processed_by_id, opts \\ []),
    to: Voile.Schema.Library.Circulation

  # Circulation stats - reusable dashboard stats
  defdelegate get_circulation_stats(node_id \\ nil), to: Voile.Schema.Library.Circulation
  defdelegate count_active_transactions(node_id), to: Voile.Schema.Library.Circulation
  defdelegate count_overdue_transactions(node_id), to: Voile.Schema.Library.Circulation
  defdelegate count_active_reservations(node_id), to: Voile.Schema.Library.Circulation
  defdelegate sum_outstanding_fines(node_id), to: Voile.Schema.Library.Circulation
end
