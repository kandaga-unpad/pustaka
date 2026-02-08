# AI Preparedness Review and Recommendations for Voile GLAM Management System

**Document Version:** 1.0  
**Date:** February 2026  
**Based on:** FLAME Project AI Preparedness Guidelines for Archivists (Colavizza & Jaillant, 2026)

---

## Executive Summary

This document provides a comprehensive review of the Voile GLAM Management System against the AI Preparedness Guidelines published by the Archives and Records Association (ARA) through the FLAME project. Voile is a next-generation digital library management system designed to support Galleries, Libraries, Archives, and Museums (GLAM institutions) with multi-node support.

The review evaluates Voile's current capabilities across four key pillars of AI readiness and provides actionable recommendations for making collections "AI-ready" in a way that supports responsible AI use while maintaining archival principles and ethical commitments.

**Key Finding:** Voile has a strong foundation for AI preparedness with its sophisticated metadata system, RBAC implementation, and multi-GLAM support. However, significant enhancements are needed to fully comply with AI preparedness guidelines, particularly in documentation of completeness, provenance tracking, format standardization for AI consumption, and evaluation metrics.

---

## Table of Contents

1. [Introduction](#introduction)
2. [Current System Overview](#current-system-overview)
3. [Pillar 1: Completeness and Excluded Data](#pillar-1-completeness-and-excluded-data)
4. [Pillar 2: Metadata and Access](#pillar-2-metadata-and-access)
5. [Pillar 3: Data Types, Formats and File Structures](#pillar-3-data-types-formats-and-file-structures)
6. [Pillar 4: Application-Specific Metrics and Evaluation](#pillar-4-application-specific-metrics-and-evaluation)
7. [AI-Assisted Workflows for GLAM](#ai-assisted-workflows-for-glam)
8. [Implementation Roadmap](#implementation-roadmap)
9. [References](#references)

---

## Introduction

### About AI Preparedness

AI Preparedness refers to the systematic preparation of archival and cultural heritage collections to enable responsible and effective use of artificial intelligence technologies. As defined by the FLAME project, AI can support GLAM work, but **only when collections are made "AI-ready"** through:

- Careful preparation
- Clear documentation
- Robust governance
- Respect for archival principles

### About This Review

This review examines the Voile system against the four pillars of AI preparedness:

1. **Completeness and excluded data** - Documentation of gaps and biases
2. **Metadata and access** - Quality, structure, and discoverability
3. **Data types, formats and file structures** - Technical readiness for AI consumption
4. **Application-specific metrics** - Evaluation frameworks for AI tools

### Types of AI Relevant to GLAM

**Task-Specific AI:**
- Classifying record types and formats
- Detecting names, places, dates (Named Entity Recognition)
- Flagging personal or sensitive information
- OCR and text extraction
- Image classification and object detection

**Generative AI:**
- Summarizing records or collections
- Proposing draft descriptions or keywords
- Answering questions about collections (RAG systems)
- Multilingual translation and access

---

## Current System Overview

### Strengths

Voile demonstrates several strengths that provide a foundation for AI preparedness:

1. **Sophisticated Metadata Architecture**
   - Vocabulary system with namespaces and prefixes
   - Flexible property definitions
   - Resource classes with GLAM type categorization
   - Resource templates for standardization
   - Custom collection fields for domain-specific metadata

2. **Multi-GLAM Support**
   - Native support for Gallery, Library, Archive, and Museum types
   - Differentiated resource classes by GLAM type
   - Flexible enough to handle varied collection types

3. **Comprehensive Access Control**
   - Three-tier access levels (public, limited, restricted)
   - Role-Based Access Control (RBAC)
   - Embargo functionality with date ranges
   - User and role-specific attachment permissions

4. **Multi-Node Architecture**
   - Support for distributed institutions
   - Node-specific collections and items
   - Organizational unit tracking

5. **Audit Logging**
   - User action tracking
   - Resource modification history
   - IP address and user agent capture

6. **Search Infrastructure**
   - Full-text search with PostgreSQL trigram indexes
   - GLAM-type filtered search
   - Advanced filtering capabilities

7. **Attachment Management**
   - Polymorphic attachment system
   - Multiple storage backends (local, S3-compatible)
   - Metadata storage for attachments

### Current Gaps

1. **No explicit completeness tracking**
2. **Limited provenance documentation**
3. **No AI-specific metadata fields**
4. **No derivative format generation for AI**
5. **No sensitivity flagging system**
6. **Limited multilingual documentation**
7. **No AI evaluation metrics framework**
8. **No API for AI/ML tool integration**

---

## Pillar 1: Completeness and Excluded Data

### Current State Assessment

**Status:** 🟡 Partially Addressed

**What Exists:**
- Collection status field (draft, pending, published, archived)
- Basic description fields
- Audit logs track creation and modification
- Node-based organizational tracking

**What's Missing:**
- No explicit completeness percentage or tracking
- No documentation of digitization gaps
- No tracking of excluded materials
- No bias or representation documentation
- No sampling methodology records
- No temporal or geographic coverage metadata

### Recommendations

#### 1.1 Add Completeness Tracking Fields

**Priority:** HIGH

Add the following fields to the `collections` table:

```elixir
# Migration: add_ai_preparedness_fields_to_collections.exs
add :completeness_status, :string # "complete", "partial", "sample", "unknown"
add :completeness_percentage, :integer # 0-100
add :completeness_notes, :text
add :digitization_status, :string # "fully_digitized", "partially_digitized", "born_digital", "mixed"
add :digitization_notes, :text
add :exclusion_criteria, :text # Document why certain items are excluded
add :known_gaps, :text # Document known gaps in the collection
add :sampling_methodology, :text # If sampled, describe methodology
add :temporal_coverage_start, :date
add :temporal_coverage_end, :date
add :geographic_coverage, :map # Store as JSON with structured location data
add :representation_notes, :text # Document biases, over/under-represented groups
```

**Implementation Example:**

```elixir
# lib/voile/schema/catalog/collection.ex
defmodule Voile.Schema.Catalog.Collection do
  # ...existing code...
  
  # AI Preparedness: Completeness tracking
  field :completeness_status, :string
  field :completeness_percentage, :integer
  field :completeness_notes, :string
  field :digitization_status, :string
  field :digitization_notes, :string
  field :exclusion_criteria, :string
  field :known_gaps, :string
  field :sampling_methodology, :string
  field :temporal_coverage_start, :date
  field :temporal_coverage_end, :date
  field :geographic_coverage, :map
  field :representation_notes, :string
  
  @completeness_statuses ~w(complete partial sample unknown)
  @digitization_statuses ~w(fully_digitized partially_digitized born_digital mixed)
end
```

#### 1.2 Create Completeness Documentation UI

**Priority:** HIGH

Create LiveView components for curators to document completeness:

- Collection completeness form section
- Visual completeness indicator (progress bar/badge)
- Gap analysis interface
- Exclusion criteria documentation
- Bias acknowledgment fields

#### 1.3 Implement Collection-Level Metadata Export

**Priority:** MEDIUM

Generate machine-readable completeness documentation that AI tools can consume:

```elixir
# lib/voile/schema/catalog/completeness.ex
defmodule Voile.Schema.Catalog.Completeness do
  @moduledoc """
  Generates AI-readable completeness documentation for collections.
  """
  
  def generate_completeness_report(collection) do
    %{
      collection_id: collection.id,
      collection_code: collection.collection_code,
      title: collection.title,
      completeness: %{
        status: collection.completeness_status,
        percentage: collection.completeness_percentage,
        notes: collection.completeness_notes,
        documented_at: DateTime.utc_now()
      },
      digitization: %{
        status: collection.digitization_status,
        notes: collection.digitization_notes
      },
      exclusions: %{
        criteria: collection.exclusion_criteria,
        known_gaps: collection.known_gaps
      },
      coverage: %{
        temporal: %{
          start: collection.temporal_coverage_start,
          end: collection.temporal_coverage_end
        },
        geographic: collection.geographic_coverage
      },
      biases: %{
        representation_notes: collection.representation_notes
      }
    }
  end
end
```

#### 1.4 Add Completeness Validation

**Priority:** MEDIUM

Before marking a collection as "published" or "AI-ready", validate that completeness documentation exists:

```elixir
def validate_ai_readiness(changeset) do
  if get_field(changeset, :ai_ready) == true do
    changeset
    |> validate_required([:completeness_status, :digitization_status])
    |> validate_inclusion(:completeness_status, @completeness_statuses)
    |> validate_completeness_notes()
  else
    changeset
  end
end
```

---

## Pillar 2: Metadata and Access

### Current State Assessment

**Status:** 🟢 Well Addressed (with improvements needed)

**What Exists:**
- Comprehensive metadata vocabulary system
- Flexible property definitions
- Resource templates for standardization
- Item-level and collection-level metadata
- Custom collection fields (dynamic metadata)
- Access control at collection and attachment levels
- Creator/provenance via `mst_creator` table
- Multi-node organizational context

**What's Missing:**
- Limited provenance chain documentation
- No curatorial narrative/contextual essay fields
- No sensitivity classification system
- Limited multilingual metadata support
- No relationship/linkage documentation between items
- No controlled vocabulary validation
- Limited historical context documentation

### Recommendations

#### 2.1 Enhance Provenance Tracking

**Priority:** HIGH

Add comprehensive provenance documentation:

```elixir
# Migration: add_provenance_fields.exs
create table(:provenance_events, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :collection_id, references(:collections, type: :binary_id), null: false
  add :item_id, references(:items, type: :binary_id)
  add :event_type, :string # "acquisition", "transfer", "digitization", "conservation", etc.
  add :event_date, :date
  add :event_description, :text
  add :agent_name, :string # Person or organization responsible
  add :agent_role, :string # "donor", "conservator", "digitizer", etc.
  add :location, :string
  add :source_documentation, :text # Reference to supporting documents
  add :metadata, :map # Flexible JSON storage
  add :sort_order, :integer
  
  timestamps(type: :utc_datetime)
end
```

**Schema Implementation:**

```elixir
# lib/voile/schema/catalog/provenance_event.ex
defmodule Voile.Schema.Catalog.ProvenanceEvent do
  use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "provenance_events" do
    belongs_to :collection, Voile.Schema.Catalog.Collection, type: :binary_id
    belongs_to :item, Voile.Schema.Catalog.Item, type: :binary_id
    
    field :event_type, :string
    field :event_date, :date
    field :event_description, :string
    field :agent_name, :string
    field :agent_role, :string
    field :location, :string
    field :source_documentation, :string
    field :metadata, :map
    field :sort_order, :integer, default: 0
    
    timestamps(type: :utc_datetime)
  end
  
  @event_types ~w(acquisition transfer donation purchase digitization conservation restoration exhibition loan return appraisal deaccession)
  @agent_roles ~w(donor seller curator conservator digitizer appraiser researcher)
  
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:collection_id, :item_id, :event_type, :event_date, 
                    :event_description, :agent_name, :agent_role, :location,
                    :source_documentation, :metadata, :sort_order])
    |> validate_required([:event_type, :event_date])
    |> validate_inclusion(:event_type, @event_types)
    |> foreign_key_constraint(:collection_id)
    |> foreign_key_constraint(:item_id)
  end
end
```

#### 2.2 Add Curatorial Narrative Fields

**Priority:** HIGH

Generative AI works effectively with unstructured text. Add fields for curatorial interpretation:

```elixir
# Add to collections table
add :curatorial_narrative, :text # Rich contextual essay about the collection
add :historical_context, :text # Historical background
add :cultural_significance, :text # Cultural and social significance
add :interpretation_notes, :text # Curatorial interpretation and analysis
add :related_collections, :text # Narrative about relationships to other collections
add :research_value, :text # Description of research and scholarly value
add :issues_and_silences, :text # Documentation of problematic aspects, silences, harms
```

**UI Component:**

Create a rich text editor component for narratives that supports:
- Markdown formatting
- Internal linking to other collections/items
- Citation formatting
- Multilingual content

#### 2.3 Implement Sensitivity Classification System

**Priority:** CRITICAL

Add structured sensitivity metadata to support AI flagging and access control:

```elixir
# Migration: create_sensitivity_classifications.exs
create table(:sensitivity_classifications, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :collection_id, references(:collections, type: :binary_id)
  add :item_id, references(:items, type: :binary_id)
  add :attachment_id, references(:attachments, type: :binary_id)
  
  add :classification_type, :string # "personal_data", "confidential", "culturally_sensitive", etc.
  add :sensitivity_level, :string # "low", "medium", "high", "critical"
  add :data_categories, {:array, :string} # ["names", "addresses", "medical", "financial"]
  add :legal_basis, :string # GDPR, copyright, cultural protocols, etc.
  add :access_restrictions, :text
  add :review_date, :date # When sensitivity should be reviewed
  add :flagged_by, :string # "manual", "ai_assisted", "automated"
  add :ai_confidence_score, :float # If flagged by AI
  add :verified_by_user_id, references(:users, type: :binary_id)
  add :verification_date, :utc_datetime
  add :notes, :text
  
  timestamps(type: :utc_datetime)
end

create index(:sensitivity_classifications, [:collection_id])
create index(:sensitivity_classifications, [:item_id])
create index(:sensitivity_classifications, [:attachment_id])
create index(:sensitivity_classifications, [:classification_type])
create index(:sensitivity_classifications, [:sensitivity_level])
create index(:sensitivity_classifications, [:review_date])
```

**Schema Implementation:**

```elixir
# lib/voile/schema/catalog/sensitivity_classification.ex
defmodule Voile.Schema.Catalog.SensitivityClassification do
  use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "sensitivity_classifications" do
    belongs_to :collection, Voile.Schema.Catalog.Collection, type: :binary_id
    belongs_to :item, Voile.Schema.Catalog.Item, type: :binary_id
    belongs_to :attachment, Voile.Schema.Catalog.Attachment, type: :binary_id
    belongs_to :verified_by_user, Voile.Schema.Accounts.User, type: :binary_id
    
    field :classification_type, :string
    field :sensitivity_level, :string
    field :data_categories, {:array, :string}
    field :legal_basis, :string
    field :access_restrictions, :string
    field :review_date, :date
    field :flagged_by, :string
    field :ai_confidence_score, :float
    field :verification_date, :utc_datetime
    field :notes, :string
    
    timestamps(type: :utc_datetime)
  end
  
  @classification_types ~w(personal_data confidential culturally_sensitive harmful_content intellectual_property security medical financial)
  @sensitivity_levels ~w(low medium high critical)
  @flagged_by_options ~w(manual ai_assisted automated)
  @data_categories ~w(names addresses emails phone_numbers medical_records financial_info biometric racial_ethnic religious political sexual_orientation indigenous_knowledge sacred_materials)
  
  def changeset(classification, attrs) do
    classification
    |> cast(attrs, [:collection_id, :item_id, :attachment_id, :classification_type,
                    :sensitivity_level, :data_categories, :legal_basis, 
                    :access_restrictions, :review_date, :flagged_by,
                    :ai_confidence_score, :verified_by_user_id, :verification_date, :notes])
    |> validate_required([:classification_type, :sensitivity_level, :flagged_by])
    |> validate_inclusion(:classification_type, @classification_types)
    |> validate_inclusion(:sensitivity_level, @sensitivity_levels)
    |> validate_inclusion(:flagged_by, @flagged_by_options)
    |> validate_ai_confidence()
    |> validate_one_parent()
  end
  
  defp validate_ai_confidence(changeset) do
    if get_field(changeset, :flagged_by) in ["ai_assisted", "automated"] do
      validate_required(changeset, [:ai_confidence_score])
      |> validate_number(:ai_confidence_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    else
      changeset
    end
  end
  
  defp validate_one_parent(changeset) do
    collection_id = get_field(changeset, :collection_id)
    item_id = get_field(changeset, :item_id)
    attachment_id = get_field(changeset, :attachment_id)
    
    count = Enum.count([collection_id, item_id, attachment_id], & !is_nil(&1))
    
    if count != 1 do
      add_error(changeset, :base, "Must specify exactly one of collection_id, item_id, or attachment_id")
    else
      changeset
    end
  end
end
```

#### 2.4 Enhance Multilingual Support

**Priority:** MEDIUM

Track and document languages present in collections:

```elixir
# Add to collections table
add :languages, {:array, :string} # ISO 639-1/639-3 language codes
add :primary_language, :string
add :script_systems, {:array, :string} # "latin", "arabic", "chinese", "devanagari", etc.
add :translation_status, :string # "untranslated", "partially_translated", "fully_translated"
add :translation_notes, :text
```

Update `item_field_values` to better support multilingual content:

```elixir
# Already has :locale field - enhance its usage
# Add language detection utilities
defmodule Voile.Schema.Catalog.ItemFieldValue do
  # ...existing code...
  
  def detect_language(text) do
    # Integration point for language detection library
    # For now, could use pattern matching or external service
    :en # placeholder
  end
end
```

#### 2.5 Add Relationship Documentation

**Priority:** MEDIUM

Document relationships between collections, items, and external resources:

```elixir
# Migration: create_relationships.exs
create table(:item_relationships, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :source_id, :binary_id, null: false # collection or item
  add :source_type, :string, null: false # "collection" or "item"
  add :target_id, :binary_id, null: false
  add :target_type, :string, null: false
  add :relationship_type, :string, null: false # "part_of", "related_to", "derived_from", etc.
  add :description, :text
  add :metadata, :map
  
  timestamps(type: :utc_datetime)
end

create index(:item_relationships, [:source_id, :source_type])
create index(:item_relationships, [:target_id, :target_type])
create index(:item_relationships, [:relationship_type])
```

#### 2.6 Create AI-Readable Metadata Export

**Priority:** HIGH

Generate standardized metadata exports for AI consumption:

```elixir
# lib/voile/schema/catalog/ai_metadata_export.ex
defmodule Voile.Schema.Catalog.AIMetadataExport do
  @moduledoc """
  Generates AI-ready metadata exports in standardized formats.
  Supports JSON-LD, Dublin Core, MARC, and custom formats.
  """
  
  def export_collection_for_ai(collection_id, format \\ :json_ld) do
    collection = Repo.get!(Collection, collection_id)
    |> Repo.preload([
      :resource_class,
      :resource_template,
      :mst_creator,
      :node,
      :collection_fields,
      :items,
      :attachments,
      provenance_events: [],
      sensitivity_classifications: []
    ])
    
    case format do
      :json_ld -> export_as_json_ld(collection)
      :dublin_core -> export_as_dublin_core(collection)
      :custom -> export_as_custom(collection)
    end
  end
  
  defp export_as_json_ld(collection) do
    %{
      "@context": "https://schema.org/",
      "@type": "Collection",
      "@id": collection.id,
      "identifier": collection.collection_code,
      "name": collection.title,
      "description": collection.description,
      "creator": %{
        "@type": "Organization",
        "name": collection.mst_creator.creator_name
      },
      "inLanguage": collection.languages || [],
      "temporalCoverage": format_temporal_coverage(collection),
      "spatialCoverage": collection.geographic_coverage,
      "isAccessibleForFree": collection.access_level == "public",
      "conditionsOfAccess": collection.access_level,
      "completeness": %{
        "status": collection.completeness_status,
        "percentage": collection.completeness_percentage,
        "notes": collection.completeness_notes
      },
      "provenance": format_provenance(collection),
      "hasPart": format_items(collection.items),
      "associatedMedia": format_attachments(collection.attachments),
      "sensitivityClassification": format_sensitivity(collection)
    }
  end
end
```

---

## Pillar 3: Data Types, Formats and File Structures

### Current State Assessment

**Status:** 🟡 Partially Addressed

**What Exists:**
- Flexible attachment system with mime type tracking
- Multiple storage backend support (local, S3-compatible)
- File metadata storage (size, type, mime type)
- Organized folder structure with unit_id support
- Original filename preservation

**What's Missing:**
- No derivative format generation for AI
- No standardized file naming convention for AI access
- No clear documentation of file structures
- No format normalization for mixed collections
- No OCR or text extraction pipeline
- No IIIF support for images
- Limited structured data export options

### Recommendations

#### 3.1 Implement Derivative Generation System

**Priority:** CRITICAL

Create standardized derivative files for AI consumption without modifying originals:

```elixir
# Migration: create_derivatives.exs
create table(:attachment_derivatives, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :attachment_id, references(:attachments, type: :binary_id, on_delete: :delete_all)
  add :derivative_type, :string # "ai_text", "ai_image", "thumbnail", "iiif", "normalized"
  add :format, :string # "txt", "tiff", "json", etc.
  add :file_path, :string
  add :file_key, :string
  add :file_size, :integer
  add :mime_type, :string
  add :generation_method, :string # "ocr", "extraction", "conversion", "transcription"
  add :generation_metadata, :map # Store processing details, confidence scores, etc.
  add :generated_at, :utc_datetime
  add :generated_by, :string # Tool/service used
  add :checksum, :string
  
  timestamps(type: :utc_datetime)
end

create index(:attachment_derivatives, [:attachment_id])
create index(:attachment_derivatives, [:derivative_type])
create index(:attachment_derivatives, [:format])
```

**Implementation:**

```elixir
# lib/voile/catalog/derivative_generator.ex
defmodule Voile.Catalog.DerivativeGenerator do
  @moduledoc """
  Generates AI-ready derivative files from original attachments.
  Preserves originals while creating standardized formats for AI consumption.
  """
  
  alias Voile.Schema.Catalog.{Attachment, AttachmentDerivative}
  alias Voile.Repo
  
  @doc """
  Generate all appropriate derivatives for an attachment.
  """
  def generate_derivatives(%Attachment{} = attachment) do
    case attachment.mime_type do
      "application/pdf" -> generate_pdf_derivatives(attachment)
      "image/" <> _ -> generate_image_derivatives(attachment)
      "text/" <> _ -> generate_text_derivatives(attachment)
      "audio/" <> _ -> generate_audio_derivatives(attachment)
      "video/" <> _ -> generate_video_derivatives(attachment)
      _ -> {:ok, []}
    end
  end
  
  defp generate_pdf_derivatives(attachment) do
    derivatives = []
    
    # Extract text for AI (OCR if needed)
    with {:ok, text_path} <- extract_text_from_pdf(attachment),
         {:ok, text_derivative} <- create_derivative_record(attachment, :ai_text, text_path) do
      derivatives = [text_derivative | derivatives]
    end
    
    # Generate normalized TIFF for image AI
    with {:ok, tiff_path} <- convert_to_tiff(attachment),
         {:ok, tiff_derivative} <- create_derivative_record(attachment, :ai_image, tiff_path) do
      derivatives = [tiff_derivative | derivatives]
    end
    
    # Generate JSON metadata extract
    with {:ok, json_path} <- extract_metadata_json(attachment),
         {:ok, json_derivative} <- create_derivative_record(attachment, :metadata, json_path) do
      derivatives = [json_derivative | derivatives]
    end
    
    {:ok, derivatives}
  end
  
  defp generate_image_derivatives(attachment) do
    derivatives = []
    
    # OCR for text extraction
    with {:ok, text_path} <- ocr_image(attachment),
         {:ok, text_derivative} <- create_derivative_record(attachment, :ai_text, text_path) do
      derivatives = [text_derivative | derivatives]
    end
    
    # Normalize to standard format (TIFF or JPEG)
    with {:ok, normalized_path} <- normalize_image(attachment),
         {:ok, norm_derivative} <- create_derivative_record(attachment, :normalized, normalized_path) do
      derivatives = [norm_derivative | derivatives]
    end
    
    # IIIF manifest for interoperability
    with {:ok, iiif_path} <- generate_iiif_manifest(attachment),
         {:ok, iiif_derivative} <- create_derivative_record(attachment, :iiif, iiif_path) do
      derivatives = [iiif_derivative | derivatives]
    end
    
    {:ok, derivatives}
  end
  
  defp generate_text_derivatives(attachment) do
    # Normalize encoding to UTF-8
    with {:ok, utf8_path} <- normalize_to_utf8(attachment),
         {:ok, derivative} <- create_derivative_record(attachment, :normalized, utf8_path) do
      {:ok, [derivative]}
    end
  end
  
  defp generate_audio_derivatives(attachment) do
    # Generate transcription if possible
    with {:ok, transcript_path} <- transcribe_audio(attachment),
         {:ok, derivative} <- create_derivative_record(attachment, :transcription, transcript_path) do
      {:ok, [derivative]}
    else
      _ -> {:ok, []}
    end
  end
  
  defp generate_video_derivatives(attachment) do
    derivatives = []
    
    # Extract keyframes
    with {:ok, frames_path} <- extract_keyframes(attachment),
         {:ok, frames_derivative} <- create_derivative_record(attachment, :keyframes, frames_path) do
      derivatives = [frames_derivative | derivatives]
    end
    
    # Generate transcript if audio track present
    with {:ok, transcript_path} <- transcribe_video_audio(attachment),
         {:ok, transcript_derivative} <- create_derivative_record(attachment, :transcription, transcript_path) do
      derivatives = [transcript_derivative | derivatives]
    end
    
    {:ok, derivatives}
  end
  
  # Placeholder implementations - integrate with actual tools
  defp extract_text_from_pdf(_attachment), do: {:error, :not_implemented}
  defp convert_to_tiff(_attachment), do: {:error, :not_implemented}
  defp extract_metadata_json(_attachment), do: {:error, :not_implemented}
  defp ocr_image(_attachment), do: {:error, :not_implemented}
  defp normalize_image(_attachment), do: {:error, :not_implemented}
  defp generate_iiif_manifest(_attachment), do: {:error, :not_implemented}
  defp normalize_to_utf8(_attachment), do: {:error, :not_implemented}
  defp transcribe_audio(_attachment), do: {:error, :not_implemented}
  defp extract_keyframes(_attachment), do: {:error, :not_implemented}
  defp transcribe_video_audio(_attachment), do: {:error, :not_implemented}
  
  defp create_derivative_record(attachment, derivative_type, file_path) do
    # Create derivative record in database
    %AttachmentDerivative{}
    |> AttachmentDerivative.changeset(%{
      attachment_id: attachment.id,
      derivative_type: to_string(derivative_type),
      file_path: file_path,
      generated_at: DateTime.utc_now()
    })
    |> Repo.insert()
  end
end
```

#### 3.2 Establish Consistent File Naming Convention

**Priority:** HIGH

Implement a predictable file naming system for AI access:

```elixir
# lib/voile/catalog/ai_file_naming.ex
defmodule Voile.Catalog.AIFileNaming do
  @moduledoc """
  Generates consistent, AI-friendly file paths and names.
  
  Format: {glam_type}/{node_abbr}/{collection_code}/{item_code}/{derivative_type}/{filename}
  Example: library/UNPAD/BK001/ITEM00123/ai_text/content.txt
  """
  
  def generate_ai_path(collection, item \\ nil, derivative_type) do
    glam_type = collection.resource_class.glam_type |> String.downcase()
    node_abbr = collection.node.abbr |> String.downcase()
    collection_code = collection.collection_code
    
    base_path = Path.join([glam_type, node_abbr, collection_code])
    
    if item do
      Path.join([base_path, item.item_code, derivative_type])
    else
      Path.join([base_path, derivative_type])
    end
  end
  
  def generate_ai_filename(original_name, derivative_type) do
    ext = Path.extname(original_name)
    base = Path.basename(original_name, ext)
    
    # Sanitize and normalize
    normalized = base
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_-]/, "_")
    
    case derivative_type do
      :ai_text -> "#{normalized}_text.txt"
      :ai_image -> "#{normalized}_normalized#{ext}"
      :metadata -> "#{normalized}_metadata.json"
      :transcription -> "#{normalized}_transcript.txt"
      _ -> "#{normalized}_derivative#{ext}"
    end
  end
end
```

#### 3.3 Create File Structure Documentation

**Priority:** MEDIUM

Generate machine-readable documentation of file organization:

```elixir
# lib/voile/catalog/structure_documentation.ex
defmodule Voile.Catalog.StructureDocumentation do
  @moduledoc """
  Generates documentation of file structure for AI systems.
  """
  
  def generate_structure_manifest(collection_id) do
    collection = Repo.get!(Collection, collection_id)
    |> Repo.preload([:items, attachments: :derivatives])
    
    %{
      manifest_version: "1.0",
      collection_id: collection.id,
      collection_code: collection.collection_code,
      generated_at: DateTime.utc_now(),
      structure: %{
        format: "hierarchical",
        description: "Collection organized by GLAM type > Node > Collection > Item",
        naming_convention: "See AI File Naming documentation"
      },
      files: %{
        originals: document_originals(collection),
        derivatives: document_derivatives(collection)
      },
      formats: %{
        text: list_text_formats(collection),
        images: list_image_formats(collection),
        audio: list_audio_formats(collection),
        video: list_video_formats(collection)
      },
      access: %{
        public_files: count_public_files(collection),
        restricted_files: count_restricted_files(collection),
        embargoed_files: count_embargoed_files(collection)
      }
    }
  end
end
```

#### 3.4 Implement Format Validation and Reporting

**Priority:** MEDIUM

Track and report on format diversity and standardization:

```elixir
# lib/voile/catalog/format_validator.ex
defmodule Voile.Catalog.FormatValidator do
  @moduledoc """
  Validates and reports on file format standardization for AI readiness.
  """
  
  @ai_preferred_formats %{
    text: ["text/plain", "application/xml", "text/xml"],
    images: ["image/tiff", "image/jpeg"],
    documents: ["application/pdf"]
  }
  
  def assess_collection_formats(collection_id) do
    attachments = Repo.all(
      from a in Attachment,
      where: a.attachable_id == ^collection_id and a.attachable_type == "collection"
    )
    
    %{
      total_files: length(attachments),
      format_distribution: analyze_format_distribution(attachments),
      ai_ready_percentage: calculate_ai_ready_percentage(attachments),
      recommendations: generate_format_recommendations(attachments)
    }
  end
  
  defp calculate_ai_ready_percentage(attachments) do
    ai_ready = Enum.count(attachments, &is_ai_ready_format?/1)
    total = length(attachments)
    
    if total > 0 do
      Float.round(ai_ready / total * 100, 2)
    else
      0.0
    end
  end
  
  defp is_ai_ready_format?(attachment) do
    Enum.any?(@ai_preferred_formats, fn {_type, mimes} ->
      attachment.mime_type in mimes
    end)
  end
end
```

---

## Pillar 4: Application-Specific Metrics and Evaluation

### Current State Assessment

**Status:** 🔴 Not Addressed

**What Exists:**
- Basic analytics dashboard for collections and items
- Search analytics tracking
- Audit logs for user actions

**What's Missing:**
- No AI-specific evaluation metrics
- No framework for measuring AI tool effectiveness
- No user satisfaction tracking for AI features
- No accuracy measurement for AI-generated content
- No cost-benefit analysis framework
- No bias detection in AI outputs

### Recommendations

#### 4.1 Create AI Metrics Framework

**Priority:** CRITICAL

Establish a comprehensive metrics system for AI tool evaluation:

```elixir
# Migration: create_ai_metrics.exs
create table(:ai_metrics, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :metric_type, :string # "accuracy", "efficiency", "user_satisfaction", "cost"
  add :ai_tool, :string # Name of AI tool/service used
  add :collection_id, references(:collections, type: :binary_id)
  add :item_id, references(:items, type: :binary_id)
  add :feature, :string # "description_generation", "sensitivity_flagging", "ocr", etc.
  add :metric_value, :float
  add :metric_unit, :string # "percentage", "minutes", "dollars", "count"
  add :sample_size, :integer
  add :measured_at, :utc_datetime
  add :measured_by_user_id, references(:users, type: :binary_id)
  add :metadata, :map # Additional context
  
  timestamps(type: :utc_datetime)
end

create index(:ai_metrics, [:metric_type])
create index(:ai_metrics, [:ai_tool])
create index(:ai_metrics, [:feature])
create index(:ai_metrics, [:collection_id])
create index(:ai_metrics, [:measured_at])
```

**Schema Implementation:**

```elixir
# lib/voile/schema/ai/metric.ex
defmodule Voile.Schema.AI.Metric do
  use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "ai_metrics" do
    field :metric_type, :string
    field :ai_tool, :string
    field :feature, :string
    field :metric_value, :float
    field :metric_unit, :string
    field :sample_size, :integer
    field :measured_at, :utc_datetime
    field :metadata, :map
    
    belongs_to :collection, Voile.Schema.Catalog.Collection, type: :binary_id
    belongs_to :item, Voile.Schema.Catalog.Item, type: :binary_id
    belongs_to :measured_by_user, Voile.Schema.Accounts.User, type: :binary_id
    
    timestamps(type: :utc_datetime)
  end
  
  @metric_types ~w(accuracy precision recall f1_score efficiency time_saved cost user_satisfaction false_positive_rate false_negative_rate)
  @metric_units ~w(percentage minutes hours dollars count ratio)
  
  def changeset(metric, attrs) do
    metric
    |> cast(attrs, [:metric_type, :ai_tool, :feature, :metric_value, :metric_unit,
                    :sample_size, :measured_at, :metadata, :collection_id, :item_id,
                    :measured_by_user_id])
    |> validate_required([:metric_type, :ai_tool, :feature, :metric_value, :metric_unit])
    |> validate_inclusion(:metric_type, @metric_types)
    |> validate_inclusion(:metric_unit, @metric_units)
    |> validate_number(:metric_value, greater_than_or_equal_to: 0)
    |> validate_number(:sample_size, greater_than: 0)
  end
end
```

#### 4.2 Implement Feature-Specific Evaluation

**Priority:** HIGH

Create evaluation protocols for each AI feature:

```elixir
# lib/voile/ai/evaluation.ex
defmodule Voile.AI.Evaluation do
  @moduledoc """
  Evaluation framework for AI-assisted features in Voile.
  """
  
  alias Voile.Schema.AI.Metric
  alias Voile.Repo
  
  @doc """
  Evaluate AI-drafted descriptions.
  Metrics: acceptance rate, edit distance, time saved, archivist rating
  """
  def evaluate_description_generation(collection_id, evaluation_params) do
    %{
      drafts_generated: evaluation_params.total_drafts,
      accepted_with_minor_edits: evaluation_params.minor_edits,
      accepted_as_is: evaluation_params.accepted,
      rejected: evaluation_params.rejected,
      avg_edit_distance: evaluation_params.avg_edits,
      avg_time_saved_minutes: evaluation_params.time_saved,
      archivist_ratings: evaluation_params.ratings
    }
    |> record_metrics(collection_id, "description_generation")
  end
  
  @doc """
  Evaluate sensitivity flagging accuracy.
  Metrics: true positives, false positives, false negatives, precision, recall
  """
  def evaluate_sensitivity_flagging(collection_id, evaluation_params) do
    true_positives = evaluation_params.true_positives
    false_positives = evaluation_params.false_positives
    false_negatives = evaluation_params.false_negatives
    
    precision = if (true_positives + false_positives) > 0 do
      true_positives / (true_positives + false_positives)
    else
      0.0
    end
    
    recall = if (true_positives + false_negatives) > 0 do
      true_positives / (true_positives + false_negatives)
    else
      0.0
    end
    
    f1 = if (precision + recall) > 0 do
      2 * (precision * recall) / (precision + recall)
    else
      0.0
    end
    
    [
      record_metric(collection_id, "sensitivity_flagging", "precision", precision, "ratio"),
      record_metric(collection_id, "sensitivity_flagging", "recall", recall, "ratio"),
      record_metric(collection_id, "sensitivity_flagging", "f1_score", f1, "ratio"),
      record_metric(collection_id, "sensitivity_flagging", "false_positive_rate", 
                   false_positives / evaluation_params.total, "ratio")
    ]
  end
  
  @doc """
  Evaluate RAG-based access system.
  Metrics: query precision, recall, user satisfaction, link quality
  """
  def evaluate_rag_access(collection_id, evaluation_params) do
    test_queries = evaluation_params.test_queries
    
    results = Enum.map(test_queries, fn query ->
      %{
        query: query.text,
        relevant_results: query.relevant_count,
        total_results: query.total_count,
        precision: query.relevant_count / max(query.total_count, 1),
        user_satisfied: query.user_rating >= 4,
        links_correct: query.correct_links / max(query.total_links, 1)
      }
    end)
    
    avg_precision = results |> Enum.map(& &1.precision) |> Enum.sum() / length(results)
    satisfaction_rate = results |> Enum.count(& &1.user_satisfied) / length(results)
    
    [
      record_metric(collection_id, "rag_access", "precision", avg_precision, "ratio"),
      record_metric(collection_id, "rag_access", "user_satisfaction", satisfaction_rate, "percentage"),
      record_metric(collection_id, "rag_access", "accuracy", 
                   Enum.sum(Enum.map(results, & &1.links_correct)) / length(results), "ratio")
    ]
  end
  
  defp record_metric(collection_id, feature, metric_type, value, unit) do
    %Metric{}
    |> Metric.changeset(%{
      metric_type: metric_type,
      ai_tool: "internal",
      feature: feature,
      metric_value: value,
      metric_unit: unit,
      collection_id: collection_id,
      measured_at: DateTime.utc_now()
    })
    |> Repo.insert()
  end
end
```

#### 4.3 Create Evaluation Dashboard

**Priority:** MEDIUM

Build a LiveView dashboard for monitoring AI metrics:

```elixir
# lib/voile_web/live/admin/ai_metrics_live.ex
defmodule VoileWeb.Admin.AIMetricsLive do
  use VoileWeb, :live_view
  
  alias Voile.AI.MetricsDashboard
  
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "AI Metrics Dashboard")
     |> load_metrics()}
  end
  
  defp load_metrics(socket) do
    socket
    |> assign(:description_metrics, MetricsDashboard.get_description_metrics())
    |> assign(:sensitivity_metrics, MetricsDashboard.get_sensitivity_metrics())
    |> assign(:rag_metrics, MetricsDashboard.get_rag_metrics())
    |> assign(:efficiency_metrics, MetricsDashboard.get_efficiency_metrics())
    |> assign(:cost_metrics, MetricsDashboard.get_cost_metrics())
  end
end
```

#### 4.4 Implement User Feedback System

**Priority:** HIGH

Create a system for collecting archivist/librarian feedback on AI outputs:

```elixir
# Migration: create_ai_feedback.exs
create table(:ai_feedback, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :user_id, references(:users, type: :binary_id), null: false
  add :feature, :string, null: false
  add :ai_output_id, :binary_id # Reference to the AI-generated content
  add :rating, :integer # 1-5 scale
  add :accepted, :boolean
  add :modifications_required, :string # "none", "minor", "major", "rejected"
  add :time_spent_minutes, :integer
  add :feedback_text, :text
  add :issues, {:array, :string} # ["inaccurate", "incomplete", "biased", "harmful"]
  add :metadata, :map
  
  timestamps(type: :utc_datetime)
end

create index(:ai_feedback, [:user_id])
create index(:ai_feedback, [:feature])
create index(:ai_feedback, [:rating])
create index(:ai_feedback, [:accepted])
```

---

## AI-Assisted Workflows for GLAM

### Recommended AI Workflows

Based on the FLAME guidelines and Voile's GLAM focus, implement these supervised AI workflows:

#### 5.1 Draft Descriptive Metadata Generation

**Status:** To Be Implemented  
**Priority:** HIGH

**Workflow:**
1. User selects collection/item for AI-assisted description
2. System generates draft description using:
   - Existing metadata
   - OCR text from attachments
   - Controlled vocabulary suggestions
   - Subject keyword extraction
3. Curator reviews and edits draft
4. System tracks acceptance rate and modifications
5. Final description explicitly marked as "human-verified"

**Implementation Approach:**

```elixir
# lib/voile/ai/description_generator.ex
defmodule Voile.AI.DescriptionGenerator do
  @moduledoc """
  Generates draft descriptions for collections using AI.
  All outputs require human review and are marked as drafts.
  """
  
  def generate_draft_description(collection_id, opts \\ []) do
    collection = load_collection_with_context(collection_id)
    
    # Gather all available context
    context = %{
      title: collection.title,
      existing_description: collection.description,
      creator: collection.mst_creator.creator_name,
      resource_class: collection.resource_class.label,
      node: collection.node.name,
      custom_fields: collection.collection_fields,
      items_sample: sample_items(collection, 5),
      attachments_text: extract_text_from_attachments(collection),
      provenance: collection.provenance_events
    }
    
    # Call AI service (placeholder - integrate with actual AI service)
    draft = call_description_generation_service(context, opts)
    
    # Store as draft with metadata
    %{
      draft_text: draft,
      generated_at: DateTime.utc_now(),
      generation_method: "ai_assisted",
      requires_review: true,
      reviewed: false,
      context_used: context,
      confidence_score: 0.0 # From AI service
    }
  end
  
  defp call_description_generation_service(_context, _opts) do
    # Integration point for OpenAI, Claude, or local LLM
    "AI-generated draft description (placeholder)"
  end
end
```

#### 5.2 Sensitivity Review and Flagging

**Status:** To Be Implemented  
**Priority:** CRITICAL

**Workflow:**
1. Automated scan of collections/items for sensitive content
2. AI flags potential issues with confidence scores
3. Curator reviews flagged items
4. Curator verifies or dismisses flags
5. Approved flags generate sensitivity classifications
6. Access controls automatically applied

**Implementation Approach:**

```elixir
# lib/voile/ai/sensitivity_detector.ex
defmodule Voile.AI.SensitivityDetector do
  @moduledoc """
  Detects potentially sensitive content in collections.
  Uses pattern matching, NER, and AI models to flag content.
  All flags require human verification.
  """
  
  def scan_collection(collection_id, opts \\ []) do
    collection = Repo.get!(Collection, collection_id)
    |> Repo.preload([:items, attachments: :derivatives])
    
    # Run multiple detection methods
    results = %{
      personal_data: detect_personal_data(collection),
      harmful_content: detect_harmful_content(collection),
      culturally_sensitive: detect_cultural_sensitivity(collection),
      confidential: detect_confidential_info(collection)
    }
    
    # Create sensitivity classification proposals
    Enum.flat_map(results, fn {type, detections} ->
      Enum.map(detections, fn detection ->
        create_sensitivity_proposal(collection.id, type, detection)
      end)
    end)
  end
  
  defp detect_personal_data(collection) do
    # Use regex, NER, and AI models to detect:
    # - Names
    # - Addresses
    # - Email addresses
    # - Phone numbers
    # - ID numbers
    # - Medical information
    # - Financial information
    
    # Placeholder
    []
  end
  
  defp detect_harmful_content(collection) do
    # Detect:
    # - Racist language
    # - Sexist language
    # - Discriminatory content
    # - Offensive material
    
    # Should use specialized AI models or services
    []
  end
  
  defp detect_cultural_sensitivity(collection) do
    # Detect:
    # - Sacred or ceremonial materials
    # - Indigenous knowledge
    # - Cultural protocols
    # - Restrictions from source communities
    
    # Requires specialized knowledge bases
    []
  end
  
  defp create_sensitivity_proposal(collection_id, classification_type, detection) do
    %{
      collection_id: collection_id,
      classification_type: classification_type,
      sensitivity_level: detection.severity,
      flagged_by: "ai_assisted",
      ai_confidence_score: detection.confidence,
      notes: detection.explanation,
      requires_verification: true
    }
  end
end
```

#### 5.3 RAG-Based Collection Access

**Status:** To Be Implemented  
**Priority:** HIGH

**Workflow:**
1. User submits natural language query
2. System retrieves relevant collections/items from prepared data
3. Generative AI drafts response based only on retrieved records
4. Response includes clear links to source records
5. System tracks query effectiveness

**Implementation Approach:**

```elixir
# lib/voile/ai/rag_query.ex
defmodule Voile.AI.RAGQuery do
  @moduledoc """
  Retrieval-Augmented Generation for collection access.
  Answers user questions by retrieving relevant records and generating
  grounded responses with source citations.
  """
  
  def query(question, user, opts \\ []) do
    # Step 1: Retrieve relevant collections and items
    relevant_records = retrieve_relevant_records(question, user, opts)
    
    # Step 2: Format context for AI
    context = format_records_for_ai(relevant_records)
    
    # Step 3: Generate response using retrieved context only
    response = generate_grounded_response(question, context, opts)
    
    # Step 4: Add source citations
    response_with_sources = add_source_citations(response, relevant_records)
    
    # Step 5: Track for evaluation
    track_rag_query(question, relevant_records, response_with_sources, user)
    
    response_with_sources
  end
  
  defp retrieve_relevant_records(question, user, opts) do
    # Use existing search infrastructure enhanced with:
    # - Semantic search (embeddings)
    # - Hybrid keyword + semantic search
    # - Access control filtering based on user permissions
    
    limit = Keyword.get(opts, :limit, 10)
    
    Voile.Search.Collections.search_collections(%{
      "q" => question,
      "per_page" => to_string(limit),
      "access_level" => determine_user_access_level(user)
    })
    |> Map.get(:results)
  end
  
  defp format_records_for_ai(records) do
    Enum.map(records, fn record ->
      """
      Collection: #{record.title}
      ID: #{record.collection_code}
      Description: #{record.description}
      Creator: #{record.mst_creator.creator_name}
      Type: #{record.resource_class.label}
      ---
      """
    end)
    |> Enum.join("\n")
  end
  
  defp generate_grounded_response(question, context, _opts) do
    # Call AI service with strict instruction to only use provided context
    # Placeholder - integrate with actual AI service
    
    prompt = """
    You are a knowledgeable archivist assistant. Answer the following question
    based ONLY on the provided collection records. If the answer is not in the
    records, say so clearly. Always cite which collection(s) you're referencing.
    
    Collections:
    #{context}
    
    Question: #{question}
    
    Answer:
    """
    
    # Call AI service
    "AI-generated response (placeholder)"
  end
  
  defp add_source_citations(response, records) do
    %{
      answer: response,
      sources: Enum.map(records, fn record ->
        %{
          collection_id: record.id,
          collection_code: record.collection_code,
          title: record.title,
          url: VoileWeb.Router.Helpers.collection_path(VoileWeb.Endpoint, :show, record.id)
        }
      end),
      disclaimer: "This response was generated by AI based on the collections listed. Please verify accuracy with the source records."
    }
  end
  
  defp track_rag_query(question, records, response, user) do
    # Store query for evaluation and improvement
    # (Implementation details)
  end
end
```

#### 5.4 Multilingual Access Enhancement

**Status:** To Be Implemented  
**Priority:** MEDIUM

**Workflow:**
1. Detect languages in collection metadata and content
2. Provide AI-assisted translation of descriptions
3. Generate multilingual search interfaces
4. Track language usage analytics

#### 5.5 OCR and Text Extraction Pipeline

**Status:** To Be Implemented  
**Priority:** HIGH

**Workflow:**
1. Automatically identify image and PDF attachments
2. Run OCR on images
3. Extract text from PDFs
4. Store as AI-ready derivatives
5. Index for full-text search
6. Human verification of critical content

---

## Implementation Roadmap

### Phase 1: Foundation (Months 1-3)

**Priority: Establish data preparedness infrastructure**

1. **Database Schema Updates**
   - [ ] Add completeness tracking fields to collections
   - [ ] Create provenance_events table
   - [ ] Create sensitivity_classifications table
   - [ ] Create attachment_derivatives table
   - [ ] Create ai_metrics table
   - [ ] Create ai_feedback table

2. **Basic Documentation**
   - [ ] Implement completeness form UI
   - [ ] Create provenance event tracking
   - [ ] Add sensitivity classification interface

3. **File Structure**
   - [ ] Implement AI-friendly file naming convention
   - [ ] Create derivative generation framework
   - [ ] Set up structured export system

### Phase 2: AI Integration Preparation (Months 4-6)

**Priority: Build evaluation and quality frameworks**

1. **Metrics Framework**
   - [ ] Implement AI metrics tracking system
   - [ ] Create evaluation dashboard
   - [ ] Build user feedback system
   - [ ] Establish baseline metrics

2. **Metadata Enhancement**
   - [ ] Add curatorial narrative fields
   - [ ] Enhance multilingual support
   - [ ] Implement relationship documentation
   - [ ] Create AI-readable exports (JSON-LD, Dublin Core)

3. **Access Control**
   - [ ] Integrate sensitivity classifications with access control
   - [ ] Implement embargo functionality enhancements
   - [ ] Create audit trail for AI access

### Phase 3: AI Features Implementation (Months 7-12)

**Priority: Deploy supervised AI workflows**

1. **Description Generation**
   - [ ] Integrate with AI service (OpenAI/Claude/local LLM)
   - [ ] Build draft review interface
   - [ ] Implement approval workflow
   - [ ] Track acceptance rates and modifications

2. **Sensitivity Detection**
   - [ ] Implement pattern-based detection
   - [ ] Integrate with AI models for content analysis
   - [ ] Build verification interface
   - [ ] Create automated access control application

3. **RAG-Based Access**
   - [ ] Implement semantic search (embeddings)
   - [ ] Build RAG query system
   - [ ] Create user interface
   - [ ] Track effectiveness metrics

4. **OCR Pipeline**
   - [ ] Integrate OCR service (Tesseract/commercial)
   - [ ] Build text extraction pipeline
   - [ ] Implement quality verification
   - [ ] Index extracted text

### Phase 4: Evaluation and Refinement (Months 13-18)

**Priority: Measure, evaluate, and improve**

1. **Metrics Analysis**
   - [ ] Analyze AI effectiveness across features
   - [ ] Gather user feedback systematically
   - [ ] Identify areas for improvement
   - [ ] Cost-benefit analysis

2. **Documentation**
   - [ ] Write comprehensive AI usage guidelines
   - [ ] Create training materials for staff
   - [ ] Document best practices
   - [ ] Publish case studies

3. **Governance**
   - [ ] Establish AI governance committee
   - [ ] Create policies for AI use
   - [ ] Define ethical guidelines
   - [ ] Regular audits of AI outputs

### Phase 5: Advanced Features (Months 19-24)

**Priority: Scale and enhance**

1. **Advanced AI Features**
   - [ ] Automated subject classification
   - [ ] Image content analysis
   - [ ] Automatic relationship detection
   - [ ] Predictive preservation recommendations

2. **API Development**
   - [ ] RESTful API for AI tool integration
   - [ ] GraphQL API for complex queries
   - [ ] Webhooks for AI workflow triggers
   - [ ] Documentation and client libraries

3. **Community Features**
   - [ ] Crowdsourced verification of AI outputs
   - [ ] Community-contributed descriptions
   - [ ] Collaborative sensitivity flagging
   - [ ] Public feedback on AI features

---

## Quick Reference Checklist

Before launching an AI project with Voile collections, verify:

- [ ] **Completeness documented** - Status, percentage, gaps, exclusions recorded
- [ ] **Metadata comprehensive** - Item-level, provenance, curatorial narratives present
- [ ] **Access conditions clear** - Public/restricted/sensitive properly marked
- [ ] **Derivatives created** - AI-ready formats generated from originals
- [ ] **File structure documented** - Predictable paths, consistent naming
- [ ] **Metrics defined** - Application-specific success criteria established
- [ ] **Evaluation plan** - How to measure AI effectiveness
- [ ] **Human oversight** - Review workflows for AI outputs defined
- [ ] **User permissions** - RBAC properly configured for AI features
- [ ] **Audit trail** - AI usage and modifications logged

---

## Governance and Ethical Considerations

### Principles for AI Use in Voile

1. **Human Oversight is Mandatory**
   - All AI outputs must be reviewed by qualified archivists/librarians
   - Final decisions on descriptions, classifications, and access remain human
   - AI is an assistive tool, not a replacement for professional judgment

2. **Transparency**
   - All AI-generated content must be clearly marked
   - Generation methods and confidence scores must be documented
   - Users must understand when they're interacting with AI

3. **Respect for Source Communities**
   - Culturally sensitive materials require specialized review
   - Indigenous knowledge systems must be respected
   - Community protocols take precedence over AI recommendations

4. **Privacy and Sensitivity**
   - AI tools must respect existing access restrictions
   - Sensitivity detection is a risk mitigation tool, not definitive
   - Legal compliance (GDPR, copyright, etc.) is paramount

5. **Bias Awareness**
   - AI models may reflect biases in training data
   - Regular audits for discriminatory or harmful outputs
   - Diverse review teams for AI-flagged content

6. **Documentation**
   - All AI usage must be logged and auditable
   - Metrics must be tracked and reported
   - Failures and limitations must be documented

### Recommended Policies

1. **AI Usage Policy**
   - Define approved AI tools and services
   - Specify data that can/cannot be sent to external AI services
   - Data retention and privacy requirements
   - Vendor evaluation criteria

2. **Quality Assurance Policy**
   - Minimum review requirements for AI outputs
   - Escalation procedures for problematic content
   - Regular quality audits
   - Continuous improvement process

3. **Training Requirements**
   - Staff training on AI capabilities and limitations
   - Ethical use of AI tools
   - Bias recognition and mitigation
   - Technical skills for AI feature use

---

## Integration Points with Existing Voile Features

### RBAC Integration

- Extend permission system to include AI features
- New permissions: `ai:generate_descriptions`, `ai:review_sensitivity`, `ai:access_rag`
- Role-based access to AI evaluation dashboards
- Audit AI feature usage per role

### Node-Based Implementation

- Each node can configure AI features independently
- Node-specific AI policies and workflows
- Metrics aggregated at node and system levels
- Multi-institution AI governance

### Multi-GLAM Support

Different AI workflows for each GLAM type:

- **Libraries:** Focus on bibliographic description generation, subject classification
- **Archives:** Emphasis on provenance, sensitivity detection, arrangement description
- **Museums:** Object description, cultural sensitivity, conservation recommendations
- **Galleries:** Artwork description, artist information, exhibition context

---

## Technical Stack Recommendations

### AI Services and Tools

**For Description Generation:**
- OpenAI GPT-4 or Claude (commercial)
- Llama 2/3 (open source, local deployment)
- Mistral (open source, EU-friendly)

**For OCR and Text Extraction:**
- Tesseract (open source)
- Google Cloud Vision API
- AWS Textract
- ABBYY FineReader (commercial)

**For Sensitivity Detection:**
- spaCy with custom NER models
- Presidio (Microsoft, open source) for PII detection
- Custom regex patterns for institution-specific needs
- Fine-tuned models for harmful content

**For Semantic Search:**
- sentence-transformers for embeddings
- Qdrant or Weaviate for vector database
- PostgreSQL pgvector extension
- OpenAI embeddings API

**For RAG Implementation:**
- LangChain or LlamaIndex frameworks
- Elixir integration via ports or NIFs
- Qdrant for vector storage
- Custom retrieval logic using existing search

### Infrastructure Requirements

**Storage:**
- Increased storage for derivatives (estimate 2-3x original storage)
- Fast access for AI processing (SSD recommended)
- Backup strategy for derivatives

**Compute:**
- GPU recommended for local AI model inference
- Sufficient RAM for large collections (32GB+ recommended)
- Horizontal scaling for batch processing

**Monitoring:**
- AI service usage and costs tracking
- Performance metrics for AI features
- Error rate monitoring
- User satisfaction tracking

---

## Costs and Resource Planning

### Budget Considerations

**One-Time Costs:**
- Database schema updates and data migration
- UI development for new features
- AI service integration development
- Staff training and documentation
- Initial derivative generation

**Ongoing Costs:**
- AI service API costs (if using commercial services)
- Additional storage for derivatives
- Compute resources for AI processing
- Staff time for AI output review
- Monitoring and evaluation

**Cost Reduction Strategies:**
- Use open-source models where possible
- Batch processing during off-peak hours
- Implement caching for frequent queries
- Prioritize high-value collections for AI processing

### Staffing Requirements

**New Roles or Responsibilities:**
- AI/ML Engineer (part-time or consultant)
- Data Quality Specialist
- AI Output Reviewer (existing archivists/librarians with training)
- Metrics Analyst

**Training Needs:**
- AI literacy for all staff
- Technical training for AI feature implementation
- Ethical AI use training
- Bias recognition and mitigation training

---

## Success Metrics

### System-Level Metrics

- **Completeness Coverage:** % of collections with documented completeness
- **Metadata Richness:** Average fields populated per collection
- **AI Readiness Score:** % of collections meeting all preparedness criteria
- **Derivative Coverage:** % of attachments with AI-ready derivatives

### Feature-Level Metrics

- **Description Generation:**
  - Acceptance rate (target: >60%)
  - Time saved per record (target: >30%)
  - Quality ratings (target: average >3.5/5)

- **Sensitivity Flagging:**
  - Precision (target: >80%)
  - Recall (target: >90%)
  - False positive rate (target: <15%)

- **RAG Access:**
  - Query relevance (target: >75%)
  - User satisfaction (target: >70%)
  - Source citation accuracy (target: >95%)

### User Experience Metrics

- User satisfaction with AI features
- Time saved on cataloging tasks
- Error rate in AI-assisted work
- Training effectiveness

---

## References and Resources

### Primary Guidelines

- Colavizza, Giovanni, and Lise Jaillant. _AI Preparedness Guidelines for Archivists_. February 2026. Archives & Records Association (UK & Ireland).
- Archives and Records Association (ARA). "New AI guidelines launched to help galleries, libraries, archives and museums prepare for the future." February 3, 2026. https://www.archives.org.uk/news/

### Related Standards and Frameworks

- **GLAM Metadata Standards:**
  - Dublin Core Metadata Initiative (DCMI)
  - Encoded Archival Description (EAD)
  - MARC 21
  - ISAD(G) - General International Standard Archival Description
  - Europeana Data Model (EDM)

- **AI Ethics Frameworks:**
  - IEEE Ethically Aligned Design
  - EU AI Act
  - UNESCO Recommendation on the Ethics of AI
  - UK Government AI Ethics Framework

- **Technical Standards:**
  - IIIF (International Image Interoperability Framework)
  - JSON-LD for linked data
  - Schema.org vocabularies
  - PREMIS for digital preservation

### Tools and Libraries

- **Elixir Ecosystem:**
  - Ecto for database operations
  - Phoenix LiveView for interactive UI
  - Req for HTTP client needs
  - NimbleCSV for data import/export

- **AI/ML Integration:**
  - Python via Ports for ML model inference
  - Bumblebee for running ML models in Elixir/BEAM
  - Explorer for data analysis (Elixir DataFrame library)

### Community Resources

- FLAME Project website (future updates)
- ARA AI Working Group
- GLAM AI Working Groups
- Voile Community Forums (to be established)

---

## Conclusion

Voile has a strong foundation for AI preparedness with its sophisticated metadata architecture, comprehensive access control, and multi-GLAM support. By implementing the recommendations in this document, Voile can become a leader in responsible AI adoption for GLAM institutions.

The key is to remember that **AI is a tool to support archival work, not replace archival judgment**. Every recommendation in this document emphasizes:

1. **Careful preparation** - Document completeness, enhance metadata, standardize formats
2. **Clear documentation** - Track everything, make it machine-readable
3. **Robust governance** - Human oversight, ethical guidelines, continuous evaluation
4. **Respect for principles** - Archival integrity, cultural sensitivity, privacy

By following this roadmap, Voile will enable institutions to:
- Speed up cataloging while maintaining quality
- Improve discoverability and access
- Protect sensitive materials more effectively
- Make informed decisions about AI use
- Lead by example in the GLAM sector

The future of archives is not AI replacing archivists—it's AI empowering archivists to do their essential work more effectively, at scale, while maintaining the highest standards of professional practice.

---

**Document Prepared By:** AI Analysis of Voile Codebase  
**Review Status:** Draft for Community Review  
**Next Review Date:** To be determined  
**Contributing:** Please submit feedback and suggestions via GitHub issues or pull requests

---

## Appendix A: Glossary

**AI-Ready:** Collections that have been prepared with appropriate documentation, standardized formats, and quality metadata to enable responsible AI use.

**Completeness:** The degree to which a digital collection represents the underlying physical or born-digital materials.

**Derivative:** A processed version of an original file created for specific purposes (like AI consumption) while preserving the original.

**GLAM:** Galleries, Libraries, Archives, and Museums - cultural heritage institutions.

**Provenance:** The documented history of ownership, custody, and modifications of archival materials.

**RAG (Retrieval-Augmented Generation):** An AI approach that retrieves relevant documents before generating responses, grounding AI outputs in actual sources.

**Sensitivity Classification:** Structured documentation of potentially sensitive, confidential, or restricted content.

**Task-Specific AI:** AI models trained for specific, well-defined tasks (e.g., OCR, entity recognition).

**Generative AI:** AI models that can create new content (text, images, etc.) based on prompts and training.

## Appendix B: Sample SQL Queries for AI Readiness Assessment

```sql
-- Check completeness documentation coverage
SELECT 
    COUNT(*) as total_collections,
    COUNT(completeness_status) as documented,
    ROUND(COUNT(completeness_status)::numeric / COUNT(*)::numeric * 100, 2) as coverage_percentage
FROM collections
WHERE status = 'published';

-- Identify collections ready for AI processing
SELECT 
    id,
    collection_code,
    title,
    completeness_status,
    digitization_status,
    access_level
FROM collections
WHERE completeness_status IS NOT NULL
    AND digitization_status IS NOT NULL
    AND status = 'published'
    AND access_level = 'public';

-- Count attachments needing derivatives
SELECT 
    COUNT(*) as total_attachments,
    COUNT(DISTINCT ad.attachment_id) as with_derivatives,
    COUNT(*) - COUNT(DISTINCT ad.attachment_id) as need_derivatives
FROM attachments a
LEFT JOIN attachment_derivatives ad ON a.id = ad.attachment_id
WHERE a.attachable_type = 'collection';

-- Sensitivity classification coverage
SELECT 
    c.id,
    c.collection_code,
    c.title,
    COUNT(sc.id) as sensitivity_flags,
    MAX(sc.sensitivity_level) as highest_sensitivity
FROM collections c
LEFT JOIN sensitivity_classifications sc ON c.id = sc.collection_id
GROUP BY c.id, c.collection_code, c.title
HAVING COUNT(sc.id) > 0;
```

## Appendix C: Configuration Examples

```elixir
# config/config.exs

config :voile, :ai_features,
  # Enable/disable AI features globally
  enabled: true,
  
  # Description generation
  description_generation: [
    enabled: true,
    provider: :openai, # :openai, :anthropic, :local
    model: "gpt-4",
    max_tokens: 500,
    temperature: 0.7
  ],
  
  # Sensitivity detection
  sensitivity_detection: [
    enabled: true,
    auto_flag_threshold: 0.8, # Confidence threshold for auto-flagging
    require_verification: true
  ],
  
  # RAG access
  rag_access: [
    enabled: true,
    max_results: 10,
    embedding_model: "text-embedding-ada-002",
    vector_db: :pgvector # :pgvector, :qdrant, :weaviate
  ],
  
  # OCR pipeline
  ocr: [
    enabled: true,
    provider: :tesseract, # :tesseract, :google_vision, :aws_textract
    languages: ["eng", "fra", "deu", "spa"]
  ],
  
  # Metrics and evaluation
  metrics: [
    track_usage: true,
    track_costs: true,
    evaluation_enabled: true
  ]
```

---

**End of Document**