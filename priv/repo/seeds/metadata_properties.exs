alias Voile.Repo
alias Voile.Schema.Metadata
alias Voile.Schema.Metadata.Property

vocabulary_1 = Repo.get!(Metadata.Vocabulary, 1)
vocabulary_2 = Repo.get!(Metadata.Vocabulary, 2)
vocabulary_3 = Repo.get!(Metadata.Vocabulary, 3)
vocabulary_4 = Repo.get!(Metadata.Vocabulary, 4)
vocabulary_5 = Repo.get!(Metadata.Vocabulary, 5)
vocabulary_6 = Repo.get!(Metadata.Vocabulary, 6)
vocabulary_7 = Repo.get!(Metadata.Vocabulary, 7)
vocabulary_8 = Repo.get!(Metadata.Vocabulary, 8)
vocabulary_9 = Repo.get!(Metadata.Vocabulary, 9)
vocabulary_10 = Repo.get!(Metadata.Vocabulary, 10)
vocabulary_11 = Repo.get!(Metadata.Vocabulary, 11)
vocabulary_12 = Repo.get!(Metadata.Vocabulary, 12)
vocabulary_13 = Repo.get!(Metadata.Vocabulary, 13)
vocabulary_14 = Repo.get!(Metadata.Vocabulary, 14)
vocabulary_15 = Repo.get!(Metadata.Vocabulary, 15)
vocabulary_16 = Repo.get!(Metadata.Vocabulary, 16)
vocabulary_17 = Repo.get!(Metadata.Vocabulary, 17)
vocabulary_18 = Repo.get!(Metadata.Vocabulary, 18)
vocabulary_19 = Repo.get!(Metadata.Vocabulary, 19)
vocabulary_20 = Repo.get!(Metadata.Vocabulary, 20)
vocabulary_21 = Repo.get!(Metadata.Vocabulary, 21)
vocabulary_22 = Repo.get!(Metadata.Vocabulary, 22)
vocabulary_23 = Repo.get!(Metadata.Vocabulary, 23)
vocabulary_24 = Repo.get!(Metadata.Vocabulary, 24)
vocabulary_25 = Repo.get!(Metadata.Vocabulary, 25)
vocabulary_26 = Repo.get!(Metadata.Vocabulary, 26)
vocabulary_27 = Repo.get!(Metadata.Vocabulary, 27)
vocabulary_28 = Repo.get!(Metadata.Vocabulary, 28)
vocabulary_29 = Repo.get!(Metadata.Vocabulary, 29)

properties_list = [
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "title",
    label: "Title",
    comment: "A name given to the resource.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "creator",
    label: "Creator",
    comment: "An entity primarily responsible for making the resource.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "subject",
    label: "Subject",
    comment: "The topic of the resource.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "description",
    label: "Description",
    comment: "An account of the resource.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "publisher",
    label: "Publisher",
    comment: "An entity responsible for making the resource available.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "contributor",
    label: "Contributor",
    comment: "An entity responsible for making contributions to the resource.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "date",
    label: "Date",
    comment:
      "A point or period of time associated with an event in the lifecycle of the resource.",
    type_value: "date"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "type",
    label: "Type",
    comment: "The nature or genre of the resource.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "format",
    label: "Format",
    comment: "The file format, physical medium, or dimensions of the resource.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "identifier",
    label: "Identifier",
    comment: "An unambiguous reference to the resource within a given context.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "source",
    label: "Source",
    comment: "A related resource from which the described resource is derived.",
    type_value: "url"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "language",
    label: "Language",
    comment: "A language of the resource.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "relation",
    label: "Relation",
    comment: "A related resource.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "coverage",
    label: "Coverage",
    comment:
      "The spatial or temporal topic of the resource, the spatial applicability of the resource, or the jurisdiction under which the resource is relevant.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "rights",
    label: "Rights",
    comment: "Information about rights held in and over the resource.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "audience",
    label: "Audience",
    comment: "A class of entity for whom the resource is intended or useful.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "alternative",
    label: "Alternative Title",
    comment: "An alternative name for the resource.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "tableOfContents",
    label: "Table Of Contents",
    comment: "A list of subunits of the resource.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "abstract",
    label: "Abstract",
    comment: "A summary of the resource.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "created",
    label: "Date Created",
    comment: "Date of creation of the resource.",
    type_value: "date"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "valid",
    label: "Date Valid",
    comment: "Date (often a range) of validity of a resource.",
    type_value: "date"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "available",
    label: "Date Available",
    comment: "Date (often a range) that the resource became or will become available.",
    type_value: "date"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "issued",
    label: "Date Issued",
    comment: "Date of formal issuance (e.g., publication) of the resource.",
    type_value: "date"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "modified",
    label: "Date Modified",
    comment: "Date on which the resource was changed.",
    type_value: "date"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "extent",
    label: "Extent",
    comment: "The size or duration of the resource.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "medium",
    label: "Medium",
    comment: "The material or physical carrier of the resource.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "isVersionOf",
    label: "Is Version Of",
    comment:
      "A related resource of which the described resource is a version, edition, or adaptation.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "hasVersion",
    label: "Has Version",
    comment:
      "A related resource that is a version, edition, or adaptation of the described resource.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "isReplacedBy",
    label: "Is Replaced By",
    comment:
      "A related resource that supplants, displaces, or supersedes the described resource.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "replaces",
    label: "Replaces",
    comment:
      "A related resource that is supplanted, displaced, or superseded by the described resource.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "isRequiredBy",
    label: "Is Required By",
    comment:
      "A related resource that requires the described resource to support its function, delivery, or coherence.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "requires",
    label: "Requires",
    comment:
      "A related resource that is required by the described resource to support its function, delivery, or coherence.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "isPartOf",
    label: "Is Part Of",
    comment:
      "A related resource in which the described resource is physically or logically included.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "hasPart",
    label: "Has Part",
    comment:
      "A related resource that is included either physically or logically in the described resource.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "isReferencedBy",
    label: "Is Referenced By",
    comment:
      "A related resource that references, cites, or otherwise points to the described resource.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "references",
    label: "References",
    comment:
      "A related resource that is referenced, cited, or otherwise pointed to by the described resource.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "isFormatOf",
    label: "Is Format Of",
    comment:
      "A related resource that is substantially the same as the described resource, but in another format.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "hasFormat",
    label: "Has Format",
    comment:
      "A related resource that is substantially the same as the pre-existing described resource, but in another format.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "conformsTo",
    label: "Conforms To",
    comment: "An established standard to which the described resource conforms.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "spatial",
    label: "Spatial Coverage",
    comment: "Spatial characteristics of the resource.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "temporal",
    label: "Temporal Coverage",
    comment: "Temporal characteristics of the resource.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "mediator",
    label: "Mediator",
    comment:
      "An entity that mediates access to the resource and for whom the resource is intended or useful.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "dateAccepted",
    label: "Date Accepted",
    comment: "Date of acceptance of the resource.",
    type_value: "date"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "dateCopyrighted",
    label: "Date Copyrighted",
    comment: "Date of copyright.",
    type_value: "date"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "dateSubmitted",
    label: "Date Submitted",
    comment: "Date of submission of the resource.",
    type_value: "date"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "educationLevel",
    label: "Audience Education Level",
    comment:
      "A class of entity, defined in terms of progression through an educational or training context, for which the described resource is intended.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "accessRights",
    label: "Access Rights",
    comment:
      "Information about who can access the resource or an indication of its security status.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "bibliographicCitation",
    label: "Bibliographic Citation",
    comment: "A bibliographic reference for the resource.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "license",
    label: "License",
    comment: "A legal document giving official permission to do something with the resource.",
    type_value: "url"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "rightsHolder",
    label: "Rights Holder",
    comment: "A person or organization owning or managing rights over the resource.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "provenance",
    label: "Provenance",
    comment:
      "A statement of any changes in ownership and custody of the resource since its creation that are significant for its authenticity, integrity, and interpretation.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "instructionalMethod",
    label: "Instructional Method",
    comment:
      "A process, used to engender knowledge, attitudes and skills, that the described resource is designed to support.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "accrualMethod",
    label: "Accrual Method",
    comment: "The method by which items are added to a collection.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "accrualPeriodicity",
    label: "Accrual Periodicity",
    comment: "The frequency with which items are added to a collection.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 1,
    local_name: "accrualPolicy",
    label: "Accrual Policy",
    comment: "The policy governing the addition of items to a collection.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "affirmedBy",
    label: "affirmedBy",
    comment: "A legal decision that affirms a ruling.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "annotates",
    label: "annotates",
    comment: "Critical or explanatory note for a Document.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "authorList",
    label: "list of authors",
    comment:
      "An ordered list of authors. Normally, this list is seen as a priority list that order authors by importance.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "citedBy",
    label: "cited by",
    comment: "Relates a document to another document that cites the\nfirst document.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "cites",
    label: "cites",
    comment:
      "Relates a document to another document that is cited\nby the first document as reference, comment, review, quotation or for\nanother purpose.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "contributorList",
    label: "list of contributors",
    comment:
      "An ordered list of contributors. Normally, this list is seen as a priority list that order contributors by importance.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "court",
    label: "court",
    comment:
      "A court associated with a legal document; for example, that which issues a decision.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "degree",
    label: "degree",
    comment: "The thesis degree.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "director",
    label: "director",
    comment: "A Film director.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "distributor",
    label: "distributor",
    comment: "Distributor of a document or a collection of documents.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "editor",
    label: "editor",
    comment:
      "A person having managerial and sometimes policy-making responsibility for the editorial part of a publishing firm or of a newspaper, magazine, or other publication.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "editorList",
    label: "list of editors",
    comment:
      "An ordered list of editors. Normally, this list is seen as a priority list that order editors by importance.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "interviewee",
    label: "interviewee",
    comment: "An agent that is interviewed by another agent.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "interviewer",
    label: "interviewer",
    comment: "An agent that interview another agent.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "issuer",
    label: "issuer",
    comment:
      "An entity responsible for issuing often informally published documents such as press releases, reports, etc.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "organizer",
    label: "organizer",
    comment:
      "The organizer of an event; includes conference organizers, but also government agencies or other bodies that are responsible for conducting hearings.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "owner",
    label: "owner",
    comment: "Owner of a document or a collection of documents.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "performer",
    label: "performer",
    comment: nil,
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "presentedAt",
    label: "presented at",
    comment: "Relates a document to an event; for example, a paper to a conference.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "presents",
    label: "presents",
    comment: "Relates an event to associated documents; for example, conference to a paper.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "producer",
    label: "producer",
    comment: "Producer of a document or a collection of documents.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "recipient",
    label: "recipient",
    comment: "An agent that receives a communication document.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "reproducedIn",
    label: "reproducedIn",
    comment: "The resource in which another resource is reproduced.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "reversedBy",
    label: "reversedBy",
    comment: "A legal decision that reverses a ruling.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "reviewOf",
    label: "review of",
    comment: "Relates a review document to a reviewed thing (resource, item, etc.).",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "status",
    label: "status",
    comment: "The publication status of (typically academic) content.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "subsequentLegalDecision",
    label: "subsequentLegalDecision",
    comment:
      "A legal decision on appeal that takes action on a case (affirming it, reversing it, etc.).",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "transcriptOf",
    label: "transcript of",
    comment: "Relates a document to some transcribed original.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "translationOf",
    label: "translation of",
    comment: "Relates a translated document to the original document.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "translator",
    label: "translator",
    comment: "A person who translates written document from one language to another.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "argued",
    label: "date argued",
    comment:
      "The date on which a legal case is argued before a court. Date is of format xsd:date",
    type_value: "date"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "asin",
    label: "asin",
    comment: nil,
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "chapter",
    label: "chapter",
    comment: "An chapter number",
    type_value: "number"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "coden",
    label: "coden",
    comment: nil,
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "content",
    label: "content",
    comment:
      "This property is for a plain-text rendering of the content of a Document. While the plain-text content of an entire document could be described by this property.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "doi",
    label: "doi",
    comment: nil,
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "eanucc13",
    label: "eanucc13",
    comment: nil,
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "edition",
    label: "edition",
    comment:
      "The name defining a special edition of a document. Normally its a literal value composed of a version number and words.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "eissn",
    label: "eissn",
    comment: nil,
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "gtin14",
    label: "gtin14",
    comment: nil,
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "handle",
    label: "handle",
    comment: nil,
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "isbn",
    label: "isbn",
    comment: nil,
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "isbn10",
    label: "isbn10",
    comment: nil,
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "isbn13",
    label: "isbn13",
    comment: nil,
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "issn",
    label: "issn",
    comment: nil,
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "issue",
    label: "issue",
    comment: "An issue number",
    type_value: "number"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "lccn",
    label: "lccn",
    comment: nil,
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "locator",
    label: "locator",
    comment:
      "A description (often numeric) that locates an item within a containing document or collection.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "numPages",
    label: "number of pages",
    comment: "The number of pages contained in a document",
    type_value: "number"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "numVolumes",
    label: "number of volumes",
    comment:
      "The number of volumes contained in a collection of documents (usually a series, periodical, etc.).",
    type_value: "number"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "number",
    label: "number",
    comment: "A generic item or document number. Not to be confused with issue number.",
    type_value: "number"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "oclcnum",
    label: "oclcnum",
    comment: nil,
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "pageEnd",
    label: "page end",
    comment: "Ending page number within a continuous page range.",
    type_value: "number"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "pageStart",
    label: "page start",
    comment: "Starting page number within a continuous page range.",
    type_value: "number"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "pages",
    label: "pages",
    comment:
      "A string of non-contiguous page spans that locate a Document within a Collection. Example: 23-25, 34, 54-56. For continuous page ranges, use the pageStart and pageEnd properties.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "pmid",
    label: "pmid",
    comment: nil,
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "prefixName",
    label: "prefix name",
    comment: "The prefix of a name",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "section",
    label: "section",
    comment: "A section number",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "shortDescription",
    label: "shortDescription",
    comment: nil,
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "shortTitle",
    label: "short title",
    comment: "The abbreviation of a title.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "sici",
    label: "sici",
    comment: nil,
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "suffixName",
    label: "suffix name",
    comment: "The suffix of a name",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "upc",
    label: "upc",
    comment: nil,
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "uri",
    label: "uri",
    comment: "Universal Resource Identifier of a document",
    type_value: "url"
  },
  %{
    owner_id: nil,
    vocabulary_id: 3,
    local_name: "volume",
    label: "volume",
    comment: "A volume number",
    type_value: "number"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "mbox",
    label: "personal mailbox",
    comment:
      "A  personal mailbox, ie. an Internet mailbox associated with exactly one owner, the first owner of this mailbox. This is a 'static inverse functional property', in that  there is (across time and change) at most one individual that ever has any particular value for foaf:mbox.",
    type_value: "email"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "mbox_sha1sum",
    label: "sha1sum of a personal mailbox URI name",
    comment:
      "The sha1sum of the URI of an Internet mailbox associated with exactly one owner, the  first owner of the mailbox.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "gender",
    label: "gender",
    comment: "The gender of this Agent (typically but not necessarily 'male' or 'female').",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "geekcode",
    label: "geekcode",
    comment: "A textual geekcode for this person, see http:\/\/www.geekcode.com\/geek.html",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "dnaChecksum",
    label: "DNA checksum",
    comment: "A checksum for the DNA of some thing. Joke.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "sha1",
    label: "sha1sum (hex)",
    comment: "A sha1sum hash, in hex.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "based_near",
    label: "based near",
    comment: "A location that something is based near, for some broadly human notion of near.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "person_title",
    label: "person title",
    comment: "Title (Mr, Mrs, Ms, Dr. etc)",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "nick",
    label: "nickname",
    comment:
      "A short informal nickname characterising an agent (includes login identifiers, IRC and other chat nicknames).",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "jabberID",
    label: "jabber ID",
    comment: "A jabber ID for something.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "aimChatID",
    label: "AIM chat ID",
    comment: "An AIM chat ID",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "skypeID",
    label: "Skype ID",
    comment: "A Skype ID",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "icqChatID",
    label: "ICQ chat ID",
    comment: "An ICQ chat ID",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "yahooChatID",
    label: "Yahoo chat ID",
    comment: "A Yahoo chat ID",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "msnChatID",
    label: "MSN chat ID",
    comment: "An MSN chat ID",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "name",
    label: "name",
    comment: "A name for some thing.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "firstName",
    label: "firstName",
    comment: "The first name of a person.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "lastName",
    label: "lastName",
    comment: "The last name of a person.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "givenName",
    label: "Given name",
    comment: "The given name of some person.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "surname",
    label: "Surname",
    comment: "The surname of some person.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "family_name",
    label: "family_name",
    comment: "The family name of some person.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "familyName",
    label: "familyName",
    comment: "The family name of some person.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "phone",
    label: "phone",
    comment:
      "A phone,  specified using fully qualified tel: URI scheme (refs: http:\/\/www.w3.org\/Addressing\/schemes.html#tel).",
    type_value: "tel"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "homepage",
    label: "homepage",
    comment: "A homepage for some thing.",
    type_value: "url"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "weblog",
    label: "weblog",
    comment: "A weblog of some thing (whether person, group, company etc.).",
    type_value: "url"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "openid",
    label: "openid",
    comment: "An OpenID for an Agent.",
    type_value: "url"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "tipjar",
    label: "tipjar",
    comment: "A tipjar document for this agent, describing means for payment and reward.",
    type_value: "url"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "plan",
    label: "plan",
    comment: "A .plan comment, in the tradition of finger and '.plan' files.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "made",
    label: "made",
    comment: "Something that was made by this agent.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "maker",
    label: "maker",
    comment: "An agent that  made this thing.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "img",
    label: "image",
    comment:
      "An image that can be used to represent some thing (ie. those depictions which are particularly representative of something, eg. one's photo on a homepage).",
    type_value: "file"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "depiction",
    label: "depiction",
    comment: "A depiction of some thing.",
    type_value: "file"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "depicts",
    label: "depicts",
    comment: "A thing depicted in this representation.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "thumbnail",
    label: "thumbnail",
    comment: "A derived thumbnail image.",
    type_value: "file"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "myersBriggs",
    label: "myersBriggs",
    comment: "A Myers Briggs (MBTI) personality classification.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "workplaceHomepage",
    label: "workplace homepage",
    comment:
      "A workplace homepage of some person; the homepage of an organization they work for.",
    type_value: "url"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "workInfoHomepage",
    label: "work info homepage",
    comment:
      "A work info homepage of some person; a page about their work for some organization.",
    type_value: "url"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "schoolHomepage",
    label: "schoolHomepage",
    comment: "A homepage of a school attended by the person.",
    type_value: "url"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "knows",
    label: "knows",
    comment:
      "A person known by this person (indicating some level of reciprocated interaction between the parties).",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "interest",
    label: "interest",
    comment: "A page about a topic of interest to this person.",
    type_value: "url"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "topic_interest",
    label: "topic_interest",
    comment: "A thing of interest to this person.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "publications",
    label: "publications",
    comment: "A link to the publications of this person.",
    type_value: "url"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "currentProject",
    label: "current project",
    comment: "A current project this person works on.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "pastProject",
    label: "past project",
    comment: "A project this person has previously worked on.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "fundedBy",
    label: "funded by",
    comment: "An organization funding a project or person.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "logo",
    label: "logo",
    comment: "A logo representing some thing.",
    type_value: "file"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "topic",
    label: "topic",
    comment: "A topic of some page or document.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "primaryTopic",
    label: "primary topic",
    comment: "The primary topic of some page or document.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "focus",
    label: "focus",
    comment: "The underlying or 'focal' entity associated with some SKOS-described concept.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "isPrimaryTopicOf",
    label: "is primary topic of",
    comment: "A document that this thing is the primary topic of.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "page",
    label: "page",
    comment: "A page or document about this thing.",
    type_value: "url"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "theme",
    label: "theme",
    comment: "A theme.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "account",
    label: "account",
    comment: "Indicates an account held by this agent.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "holdsAccount",
    label: "holds account",
    comment: "Indicates an account held by this agent.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "accountServiceHomepage",
    label: "account service homepage",
    comment: "Indicates a homepage of the service provide for this online account.",
    type_value: "url"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "accountName",
    label: "account name",
    comment: "Indicates the name (identifier) associated with this online account.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "member",
    label: "member",
    comment: "Indicates a member of a Group",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "membershipClass",
    label: "membershipClass",
    comment: "Indicates the class of individuals that are a member of a Group",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "birthday",
    label: "birthday",
    comment: "The birthday of this Agent, represented in mm-dd string form, eg. '12-31'.",
    type_value: "date"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "age",
    label: "age",
    comment: "The age in years of some agent.",
    type_value: "number"
  },
  %{
    owner_id: nil,
    vocabulary_id: 4,
    local_name: "statusUser",
    label: "status user",
    comment:
      "A string expressing what the user is happy for the general public (normally) to know about their current activity.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 5,
    local_name: "title",
    label: "Title",
    comment: "The title of the resource based on Perpustakaan Universitas Padjadjaran's Book.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 5,
    local_name: "sor",
    label: "Statement of Responsibility",
    comment:
      "A statement of responsibility for the resource based on Perpustakaan Universitas Padjadjaran's Book.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 5,
    local_name: "edition",
    label: "Edition",
    comment: "The edition of the resource based on Perpustakaan Universitas Padjadjaran's Book.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 5,
    local_name: "isbn",
    label: "International Standard Book Number",
    comment: "The ISBN of the resource based on Perpustakaan Universitas Padjadjaran's Book.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 5,
    local_name: "issn",
    label: "International Standard Serial Number",
    comment: "The ISSN of the resource based on Perpustakaan Universitas Padjadjaran's Book.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 5,
    local_name: "publisher",
    label: "Publisher",
    comment:
      "The publisher of the resource based on Perpustakaan Universitas Padjadjaran's Book.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 5,
    local_name: "publishedYear",
    label: "Published Year",
    comment:
      "The year the resource was published based on Perpustakaan Universitas Padjadjaran's Book.",
    type_value: "number"
  },
  %{
    owner_id: nil,
    vocabulary_id: 5,
    local_name: "publishedDate",
    label: "Published Date",
    comment:
      "The date the resource was published based on Perpustakaan Universitas Padjadjaran's Book.",
    type_value: "date"
  },
  %{
    owner_id: nil,
    vocabulary_id: 5,
    local_name: "publishedPlace",
    label: "Published Place",
    comment:
      "The place where the resource was published based on Perpustakaan Universitas Padjadjaran's Book.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 5,
    local_name: "collation",
    label: "Collation",
    comment:
      "The collation of the resource based on Perpustakaan Universitas Padjadjaran's Book.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 5,
    local_name: "seriesTitle",
    label: "Series Title",
    comment:
      "The series title of the resource based on Perpustakaan Universitas Padjadjaran's Book.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 5,
    local_name: "callNumber",
    label: "Call Number",
    comment:
      "The call number of the resource based on Perpustakaan Universitas Padjadjaran's Book.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 5,
    local_name: "languageType",
    label: "Language Type",
    comment:
      "The language type of the resource based on Perpustakaan Universitas Padjadjaran's Book.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 5,
    local_name: "sourceOfResource",
    label: "Source of Resource",
    comment: "The source of the resource based on Perpustakaan Universitas Padjadjaran's Book.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 5,
    local_name: "classification",
    label: "Classification",
    comment:
      "The classification of the resource based on Perpustakaan Universitas Padjadjaran's Book.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 5,
    local_name: "notes",
    label: "Notes",
    comment:
      "Additional notes about the resource based on Perpustakaan Universitas Padjadjaran's Book.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 5,
    local_name: "frequency",
    label: "Frequency",
    comment:
      "The frequency of the resource released based on Perpustakaan Universitas Padjadjaran's Book.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 5,
    local_name: "specDetailInfo",
    label: "Special Detail Information",
    comment:
      "Special detail information about the resource based on Perpustakaan Universitas Padjadjaran's Book.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 5,
    local_name: "contentType",
    label: "Content Type",
    comment:
      "The content type of the resource based on Perpustakaan Universitas Padjadjaran's Book.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 5,
    local_name: "mediaType",
    label: "Media Type",
    comment:
      "The media type of the resource based on Perpustakaan Universitas Padjadjaran's Book.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 5,
    local_name: "carrierType",
    label: "Carrier Type",
    comment:
      "The carrier type of the resource based on Perpustakaan Universitas Padjadjaran's Book.",
    type_value: "text"
  },
  # ── 6. VRA Core 4.0 ──────────────────────────────────────────────────────────
  %{
    owner_id: nil,
    vocabulary_id: 6,
    local_name: "agent",
    label: "Agent",
    comment:
      "Individuals or groups responsible for the creation, production, or alteration of a work or image.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 6,
    local_name: "culturalContext",
    label: "Cultural Context",
    comment: "The name of the culture, people, or nationality from which the work originated.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 6,
    local_name: "date",
    label: "Date",
    comment:
      "Date or range of dates associated with the creation, alteration, or discovery of the work.",
    type_value: "date"
  },
  %{
    owner_id: nil,
    vocabulary_id: 6,
    local_name: "description",
    label: "Description",
    comment: "A free-text description of the work, image, or collection.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 6,
    local_name: "inscription",
    label: "Inscription",
    comment:
      "All marks or written words added to the surface of the work at the time of production or later.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 6,
    local_name: "location",
    label: "Location",
    comment:
      "The geographic location and/or name of the repository, site, or event associated with the work.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 6,
    local_name: "material",
    label: "Material",
    comment: "The substance of which the work is composed.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 6,
    local_name: "measurements",
    label: "Measurements",
    comment: "The physical dimensions, size, scale, or format of the work.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 6,
    local_name: "relation",
    label: "Relation",
    comment:
      "Reference to another Work, Image, or Collection that has a relationship to the described resource.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 6,
    local_name: "rights",
    label: "Rights",
    comment: "Information about the rights management associated with the work.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 6,
    local_name: "source",
    label: "Source",
    comment: "A reference to the source of the information recorded about the work.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 6,
    local_name: "stateEdition",
    label: "State / Edition",
    comment: "The state or edition of the work.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 6,
    local_name: "stylePeriod",
    label: "Style / Period",
    comment:
      "A defined style, historical period, group, school, dynasty, movement, etc. whose characteristics are represented in the work.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 6,
    local_name: "subject",
    label: "Subject",
    comment:
      "Terms or phrases that describe, identify, or interpret the work and what it depicts or expresses.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 6,
    local_name: "technique",
    label: "Technique",
    comment: "The processes, methods, and means by which the work was created.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 6,
    local_name: "textref",
    label: "Text Reference",
    comment:
      "The name and location within a text of a citation or reference relating to the work.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 6,
    local_name: "title",
    label: "Title",
    comment: "The title or identifying phrase given to a work.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 6,
    local_name: "worktype",
    label: "Work Type",
    comment:
      "The specific kind of object or work being described (e.g., painting, photograph, sculpture).",
    type_value: "text"
  },

  # ── 7 . CDWA Lite ─────────────────────────────────────────────────────────────
  %{
    owner_id: nil,
    vocabulary_id: 7,
    local_name: "objectWorkType",
    label: "Object / Work Type",
    comment: "The specific kind of object or work being catalogued.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 7,
    local_name: "titles",
    label: "Titles",
    comment: "Names, titles, or identifying phrases given to the work.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 7,
    local_name: "creatorDescription",
    label: "Creator Description",
    comment: "Describes the maker(s) of the work.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 7,
    local_name: "creationDate",
    label: "Creation Date",
    comment: "The date or date range when the work was created.",
    type_value: "date"
  },
  %{
    owner_id: nil,
    vocabulary_id: 7,
    local_name: "stylesCultures",
    label: "Styles / Cultures",
    comment: "The style, period, group, or culture to which the work belongs.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 7,
    local_name: "currentLocation",
    label: "Current Location",
    comment: "The current location (repository, museum, site) where the work is held.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 7,
    local_name: "subjectMatter",
    label: "Subject Matter",
    comment: "What is depicted or expressed in the work.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 7,
    local_name: "classificationTerm",
    label: "Classification Term",
    comment: "The term used to classify or categorise the work.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 7,
    local_name: "materialsTechniques",
    label: "Materials & Techniques",
    comment: "The materials and techniques used in making the work.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 7,
    local_name: "measurements",
    label: "Measurements",
    comment: "The dimensions, size, scale, or format of the work.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 7,
    local_name: "inscriptions",
    label: "Inscriptions",
    comment: "Marks or written words on the work.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 7,
    local_name: "stateEditionDescription",
    label: "State / Edition Description",
    comment: "The specific state, edition, or version of the work.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 7,
    local_name: "descriptiveNotes",
    label: "Descriptive Notes",
    comment: "Free-text notes about the work.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 7,
    local_name: "associatedNames",
    label: "Associated Names",
    comment:
      "Names of persons or corporate bodies associated with the work (other than creators).",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 7,
    local_name: "relatedWorks",
    label: "Related Works",
    comment: "Works related to the described work.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 7,
    local_name: "rightsAndReproduction",
    label: "Rights & Reproduction",
    comment: "Information about copyright and reproduction rights.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 7,
    local_name: "recordID",
    label: "Record ID",
    comment: "A unique identifier for the catalogue record.",
    type_value: "text"
  },

  # ── 8. EXIF ───────────────────────────────────────────────────────────────────
  %{
    owner_id: nil,
    vocabulary_id: 8,
    local_name: "imageWidth",
    label: "Image Width",
    comment: "The number of columns of image data (pixels per row).",
    type_value: "integer"
  },
  %{
    owner_id: nil,
    vocabulary_id: 8,
    local_name: "imageLength",
    label: "Image Length",
    comment: "The number of rows of image data.",
    type_value: "integer"
  },
  %{
    owner_id: nil,
    vocabulary_id: 8,
    local_name: "bitsPerSample",
    label: "Bits Per Sample",
    comment: "The number of bits per image component.",
    type_value: "integer"
  },
  %{
    owner_id: nil,
    vocabulary_id: 8,
    local_name: "colorSpace",
    label: "Color Space",
    comment: "The colour space information tag (e.g., sRGB, Adobe RGB).",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 8,
    local_name: "dateTimeOriginal",
    label: "Date Time Original",
    comment: "Date and time when the original image data was generated.",
    type_value: "date"
  },
  %{
    owner_id: nil,
    vocabulary_id: 8,
    local_name: "make",
    label: "Camera Make",
    comment: "The manufacturer of the recording equipment.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 8,
    local_name: "model",
    label: "Camera Model",
    comment: "The model name or model number of the equipment.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 8,
    local_name: "exposureTime",
    label: "Exposure Time",
    comment: "Exposure time, in seconds.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 8,
    local_name: "fNumber",
    label: "F-Number",
    comment: "The F number (aperture) at the time of capture.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 8,
    local_name: "isoSpeedRatings",
    label: "ISO Speed Ratings",
    comment: "The ISO speed and ISO latitude of the camera.",
    type_value: "integer"
  },
  %{
    owner_id: nil,
    vocabulary_id: 8,
    local_name: "gpsInfo",
    label: "GPS Info",
    comment: "GPS measurement info including latitude, longitude, and altitude.",
    type_value: "text"
  },

  # ── 9. IPTC Photo Metadata ────────────────────────────────────────────────────
  %{
    owner_id: nil,
    vocabulary_id: 9,
    local_name: "headline",
    label: "Headline",
    comment: "A brief publishable synopsis or summary of the contents of the photograph.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 9,
    local_name: "caption",
    label: "Caption / Abstract",
    comment: "A textual description, including captions, of the image.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 9,
    local_name: "creator",
    label: "Creator",
    comment: "The creator or photographer of the image.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 9,
    local_name: "jobTitle",
    label: "Creator's Job Title",
    comment: "The job title of the creator.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 9,
    local_name: "keywords",
    label: "Keywords",
    comment: "Keywords to express the subject of the image.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 9,
    local_name: "subjectCode",
    label: "Subject Code",
    comment: "Structured subjects (IPTC Subject NewsCode).",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 9,
    local_name: "copyrightNotice",
    label: "Copyright Notice",
    comment: "The copyright notice for claiming the intellectual property.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 9,
    local_name: "creditLine",
    label: "Credit Line",
    comment: "The credit to person(s) and/or organisation(s) required by the supplier.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 9,
    local_name: "dateCreated",
    label: "Date Created",
    comment: "Designates the date and optionally the time the intellectual content was created.",
    type_value: "date"
  },
  %{
    owner_id: nil,
    vocabulary_id: 9,
    local_name: "city",
    label: "City",
    comment: "Name of the city of the location shown in the image.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 9,
    local_name: "countryName",
    label: "Country Name",
    comment: "The name of the country shown in the image.",
    type_value: "text"
  },

  # ── 10. XMP ────────────────────────────────────────────────────────────────────
  %{
    owner_id: nil,
    vocabulary_id: 10,
    local_name: "CreateDate",
    label: "Create Date",
    comment: "The date and time the resource was created.",
    type_value: "date"
  },
  %{
    owner_id: nil,
    vocabulary_id: 10,
    local_name: "ModifyDate",
    label: "Modify Date",
    comment: "The date and time the resource was last modified.",
    type_value: "date"
  },
  %{
    owner_id: nil,
    vocabulary_id: 10,
    local_name: "Rating",
    label: "Rating",
    comment: "A user-assigned rating for the file (–1 to 5 stars).",
    type_value: "integer"
  },
  %{
    owner_id: nil,
    vocabulary_id: 10,
    local_name: "UsageTerms",
    label: "Usage Terms",
    comment: "A collection of text instructions on how a resource can be legally used.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 10,
    local_name: "DocumentID",
    label: "Document ID",
    comment: "The common identifier for all versions and renditions of a document.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 10,
    local_name: "InstanceID",
    label: "Instance ID",
    comment:
      "An identifier for a specific incarnation of a document, updated each time the file is saved.",
    type_value: "text"
  },

  # ── 11. Schema.org ─────────────────────────────────────────────────────────────
  %{
    owner_id: nil,
    vocabulary_id: 11,
    local_name: "name",
    label: "Name",
    comment: "The name of the item.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 11,
    local_name: "description",
    label: "Description",
    comment: "A description of the item.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 11,
    local_name: "url",
    label: "URL",
    comment: "URL of the item.",
    type_value: "uri"
  },
  %{
    owner_id: nil,
    vocabulary_id: 11,
    local_name: "dateCreated",
    label: "Date Created",
    comment: "The date on which the CreativeWork was created.",
    type_value: "date"
  },
  %{
    owner_id: nil,
    vocabulary_id: 11,
    local_name: "dateModified",
    label: "Date Modified",
    comment: "The date on which the CreativeWork was most recently modified.",
    type_value: "date"
  },
  %{
    owner_id: nil,
    vocabulary_id: 11,
    local_name: "creator",
    label: "Creator",
    comment: "The creator/author of this content or rating.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 11,
    local_name: "license",
    label: "License",
    comment: "A license document that applies to this content.",
    type_value: "uri"
  },
  %{
    owner_id: nil,
    vocabulary_id: 11,
    local_name: "artEdition",
    label: "Art Edition",
    comment:
      "The number of copies when multiple copies of a piece of artwork are produced — e.g. for a limited edition of 20 prints.",
    type_value: "integer"
  },
  %{
    owner_id: nil,
    vocabulary_id: 11,
    local_name: "artMedium",
    label: "Art Medium",
    comment:
      "The material used (e.g. Oil, Watercolour, Acrylic, Linocut, Marble, Cyanotype, Digital, Lithograph).",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 11,
    local_name: "artform",
    label: "Artform",
    comment:
      "An established vocabulary of artforms (e.g., Painting, Drawing, Sculpture, Print, Film, Installation).",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 11,
    local_name: "artworkSurface",
    label: "Artwork Surface",
    comment: "The supporting materials for the artwork (e.g. Canvas, Panel, Paper, Wood, Board).",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 11,
    local_name: "depth",
    label: "Depth",
    comment: "The depth of the item.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 11,
    local_name: "height",
    label: "Height",
    comment: "The height of the item.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 11,
    local_name: "width",
    label: "Width",
    comment: "The width of the item.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 11,
    local_name: "locationCreated",
    label: "Location Created",
    comment: "The location where the artwork was created.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 11,
    local_name: "encodingFormat",
    label: "Encoding Format",
    comment: "MIME format (or media type) of the content.",
    type_value: "text"
  },

  # ── 12. MARC 21 ────────────────────────────────────────────────────────────────
  %{
    owner_id: nil,
    vocabulary_id: 12,
    local_name: "controlNumber",
    label: "Control Number (001)",
    comment:
      "Unique control number assigned by the organisation whose system number appears in field 003.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 12,
    local_name: "controlNumberIdentifier",
    label: "Control Number Identifier (003)",
    comment:
      "MARC code for the organisation whose system control number is contained in field 001.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 12,
    local_name: "latestTransactionDateTime",
    label: "Latest Transaction Date/Time (005)",
    comment: "Date and time of the latest record transaction.",
    type_value: "date"
  },
  %{
    owner_id: nil,
    vocabulary_id: 12,
    local_name: "fixedLengthDataElements",
    label: "Fixed-Length Data Elements (008)",
    comment: "Positionally-defined data elements for all types of material.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 12,
    local_name: "isbn",
    label: "ISBN (020)",
    comment: "The International Standard Book Number.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 12,
    local_name: "issn",
    label: "ISSN (022)",
    comment: "The International Standard Serial Number.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 12,
    local_name: "catalogingSource",
    label: "Cataloging Source (040)",
    comment: "MARC code for the organisation that created, transcribed, or modified the record.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 12,
    local_name: "languageCode",
    label: "Language Code (041)",
    comment: "Language code(s) for the language of the item.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 12,
    local_name: "lcCallNumber",
    label: "LC Call Number (050)",
    comment: "Library of Congress call number.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 12,
    local_name: "deweyDecimal",
    label: "Dewey Decimal Classification (082)",
    comment: "Dewey Decimal Classification number.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 12,
    local_name: "personalName",
    label: "Personal Name — Main Entry (100)",
    comment: "Personal name as the main entry (primary access point) for the record.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 12,
    local_name: "corporateName",
    label: "Corporate Name — Main Entry (110)",
    comment: "Corporate name as the main entry for the record.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 12,
    local_name: "uniformTitle",
    label: "Uniform Title (130/240)",
    comment: "A distinctive title assigned to a work which has appeared under varying titles.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 12,
    local_name: "titleStatement",
    label: "Title Statement (245)",
    comment: "The title and statement of responsibility area.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 12,
    local_name: "varyingFormTitle",
    label: "Varying Form of Title (246)",
    comment: "Portion of the title or an alternative title.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 12,
    local_name: "editionStatement",
    label: "Edition Statement (250)",
    comment: "Information relating to the edition of a work.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 12,
    local_name: "publication",
    label: "Publication / Distribution (264)",
    comment:
      "Place, name, and date relating to publication, distribution, manufacture, or copyright.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 12,
    local_name: "physicalDescription",
    label: "Physical Description (300)",
    comment: "The physical description of the item (extent, dimensions, accompanying material).",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 12,
    local_name: "generalNote",
    label: "General Note (500)",
    comment: "General information for which a specific note field has not been defined.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 12,
    local_name: "summaryNote",
    label: "Summary (520)",
    comment: "Unformatted information about the contents of the item.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 12,
    local_name: "subjectTopical",
    label: "Subject — Topical Term (650)",
    comment: "A topical term used as a subject added entry.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 12,
    local_name: "subjectGeographic",
    label: "Subject — Geographic Name (651)",
    comment: "A geographic name used as a subject added entry.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 12,
    local_name: "addedEntryPersonalName",
    label: "Added Entry — Personal Name (700)",
    comment: "A secondary entry under a personal name.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 12,
    local_name: "electronicLocationURL",
    label: "Electronic Location and Access (856)",
    comment: "Information needed to locate and access an electronic resource.",
    type_value: "uri"
  },

  # ── 13. MODS ───────────────────────────────────────────────────────────────────
  %{
    owner_id: nil,
    vocabulary_id: 13,
    local_name: "titleInfo",
    label: "Title Info",
    comment:
      "A word, phrase, character, or group of characters that constitutes the chief title of a resource.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 13,
    local_name: "name",
    label: "Name",
    comment:
      "The name of a person, organisation, or event associated in some way with the resource.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 13,
    local_name: "typeOfResource",
    label: "Type of Resource",
    comment:
      "A term that specifies the characteristics and general type of content of the resource.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 13,
    local_name: "genre",
    label: "Genre",
    comment:
      "A term or terms that designate a category characterising a particular style, form, or content.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 13,
    local_name: "originInfo",
    label: "Origin Info",
    comment: "Information about the origin of the resource: place, publisher, date.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 13,
    local_name: "language",
    label: "Language",
    comment: "The language(s) of the content of the resource.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 13,
    local_name: "physicalDescription",
    label: "Physical Description",
    comment: "Information about the physical attributes of the resource.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 13,
    local_name: "abstract",
    label: "Abstract",
    comment: "A summary of the content of the resource.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 13,
    local_name: "tableOfContents",
    label: "Table of Contents",
    comment: "A description of the contents of the resource.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 13,
    local_name: "targetAudience",
    label: "Target Audience",
    comment:
      "A description of the intellectual level, motivation/interest level, subject interest, or special characteristics of the intended audience.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 13,
    local_name: "note",
    label: "Note",
    comment: "General textual information relating to a resource.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 13,
    local_name: "subject",
    label: "Subject",
    comment: "A term or phrase representing the primary topic(s) on which a work is focused.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 13,
    local_name: "classification",
    label: "Classification",
    comment:
      "A designation applied to a resource that indicates the subject by applying a formal system of coding and organising resources.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 13,
    local_name: "relatedItem",
    label: "Related Item",
    comment: "Information about other resources related to the resource being described.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 13,
    local_name: "identifier",
    label: "Identifier",
    comment:
      "Contains a unique standard number or code that distinctively identifies a resource.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 13,
    local_name: "location",
    label: "Location",
    comment:
      "Identifies the institution or repository holding the resource, or a remote location in the form of a URL.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 13,
    local_name: "accessCondition",
    label: "Access Condition",
    comment: "Information about restrictions imposed on access to a resource.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 13,
    local_name: "part",
    label: "Part",
    comment: "Designation of physical pages, volumes, tracks of music, frames of film, etc.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 13,
    local_name: "recordInfo",
    label: "Record Info",
    comment: "Information about the metadata record.",
    type_value: "text"
  },

  # ── 14. BIBFRAME 2.0 ──────────────────────────────────────────────────────────
  %{
    owner_id: nil,
    vocabulary_id: 14,
    local_name: "title",
    label: "Title",
    comment: "Title information associated with a resource (Work or Instance).",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 14,
    local_name: "subject",
    label: "Subject",
    comment: "Subject term(s) describing the Work.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 14,
    local_name: "contribution",
    label: "Contribution",
    comment: "Agent and role associated with the creation of the Work.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 14,
    local_name: "language",
    label: "Language",
    comment: "Language associated with a resource.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 14,
    local_name: "content",
    label: "Content Type",
    comment: "Content type of the Work (RDA Content Type term).",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 14,
    local_name: "summary",
    label: "Summary",
    comment: "Summary of the content of the resource.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 14,
    local_name: "classification",
    label: "Classification",
    comment: "Classification number(s) assigned to the Work.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 14,
    local_name: "intendedAudience",
    label: "Intended Audience",
    comment: "Intended audience of the Work.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 14,
    local_name: "genreForm",
    label: "Genre / Form",
    comment: "Genre or form of the Work.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 14,
    local_name: "place",
    label: "Place",
    comment: "Geographic place associated with the Work.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 14,
    local_name: "identifiedBy",
    label: "Identified By",
    comment: "Identifier for the Instance (ISBN, ISSN, etc.).",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 14,
    local_name: "publicationStatement",
    label: "Publication Statement",
    comment: "Publication statement of the Instance.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 14,
    local_name: "editionStatement",
    label: "Edition Statement",
    comment: "Edition statement of the Instance.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 14,
    local_name: "responsibilityStatement",
    label: "Responsibility Statement",
    comment: "Statement of responsibility of the Instance.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 14,
    local_name: "media",
    label: "Media Type",
    comment: "RDA Media Type of the Instance.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 14,
    local_name: "carrier",
    label: "Carrier Type",
    comment: "RDA Carrier Type of the Instance.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 14,
    local_name: "extent",
    label: "Extent",
    comment: "Number and type of units of the Instance.",
    type_value: "text"
  },

  # ── 15. METS ──────────────────────────────────────────────────────────────────
  %{
    owner_id: nil,
    vocabulary_id: 15,
    local_name: "metsHdr",
    label: "METS Header",
    comment: "Header element containing metadata describing the METS document itself.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 15,
    local_name: "dmdSec",
    label: "Descriptive Metadata Section",
    comment: "One or more sections of descriptive metadata (e.g., DC, MODS).",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 15,
    local_name: "amdSec",
    label: "Administrative Metadata Section",
    comment: "Technical, rights, source, and digital provenance metadata (PREMIS, MIX).",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 15,
    local_name: "fileSec",
    label: "File Section",
    comment: "Inventory of files comprising the digital object.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 15,
    local_name: "structMap",
    label: "Structural Map",
    comment: "Outlines the hierarchical logical or physical structure of the digital object.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 15,
    local_name: "structLink",
    label: "Structural Links",
    comment: "Hyperlinks between structural map nodes.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 15,
    local_name: "behaviorSec",
    label: "Behavior Section",
    comment: "Executable behaviors that can be applied to the digital object.",
    type_value: "text"
  },

  # ── 16. ONIX 3.0 ──────────────────────────────────────────────────────────────
  %{
    owner_id: nil,
    vocabulary_id: 16,
    local_name: "productIdentifier",
    label: "Product Identifier",
    comment: "An identifier for the product, typically ISBN-13.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 16,
    local_name: "titleDetail",
    label: "Title Detail",
    comment: "The title of the product in a specific title type.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 16,
    local_name: "contributor",
    label: "Contributor",
    comment:
      "A contributor to the content of the product (author, editor, illustrator, etc.) with their role.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 16,
    local_name: "language",
    label: "Language",
    comment: "Language of the text of the product.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 16,
    local_name: "subject",
    label: "Subject",
    comment: "Subject classification (BISAC, BIC, Thema, etc.).",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 16,
    local_name: "extent",
    label: "Extent",
    comment: "The number of pages, number of words, or duration of the product.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 16,
    local_name: "editionStatement",
    label: "Edition Statement",
    comment: "A short free-text description of the edition.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 16,
    local_name: "publisher",
    label: "Publisher",
    comment: "The name of the publisher.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 16,
    local_name: "publishingDate",
    label: "Publishing Date",
    comment: "Publication date of the product.",
    type_value: "date"
  },
  %{
    owner_id: nil,
    vocabulary_id: 16,
    local_name: "relatedMaterial",
    label: "Related Material",
    comment: "Related products or related works.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 16,
    local_name: "textContent",
    label: "Text Content",
    comment: "A free text excerpt from the work (blurb, review quote, table of contents).",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 16,
    local_name: "price",
    label: "Price",
    comment: "The price of the product for a specific market and currency.",
    type_value: "text"
  },

  # ── 17. ISAD(G) ───────────────────────────────────────────────────────────────
  %{
    owner_id: nil,
    vocabulary_id: 17,
    local_name: "referenceCode",
    label: "Reference Code",
    comment: "Unique identifier for the unit of description within the repository.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 17,
    local_name: "title",
    label: "Title",
    comment: "Name of the unit of description.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 17,
    local_name: "dates",
    label: "Dates",
    comment: "Date(s) of creation of the records.",
    type_value: "date"
  },
  %{
    owner_id: nil,
    vocabulary_id: 17,
    local_name: "levelOfDescription",
    label: "Level of Description",
    comment: "Level of arrangement of the unit of description (fonds, series, file, item).",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 17,
    local_name: "extentAndMedium",
    label: "Extent and Medium",
    comment: "Physical extent and medium of the unit of description.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 17,
    local_name: "nameOfCreator",
    label: "Name of Creator",
    comment:
      "Name of the organisation(s) or individual(s) responsible for the creation of the archival unit.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 17,
    local_name: "administrativeHistory",
    label: "Administrative / Biographical History",
    comment:
      "Concise information on the administrative history of the creating body or the life of the creator.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 17,
    local_name: "archivalHistory",
    label: "Archival History",
    comment:
      "Successive transfers of ownership, responsibility or custody of the unit of description.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 17,
    local_name: "immediateSourceOfAcquisition",
    label: "Immediate Source of Acquisition",
    comment:
      "Source from which the repository directly acquired the unit of description and the date and method of acquisition.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 17,
    local_name: "scopeAndContent",
    label: "Scope and Content",
    comment: "Enables users to judge the potential relevance of the unit of description.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 17,
    local_name: "appraisalDestructionScheduling",
    label: "Appraisal, Destruction and Scheduling",
    comment: "Information on any appraisal, destruction and scheduling action.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 17,
    local_name: "accruals",
    label: "Accruals",
    comment: "Planned additions to the unit of description.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 17,
    local_name: "systemOfArrangement",
    label: "System of Arrangement",
    comment:
      "Information about the internal structure, order, and/or classification system of the unit of description.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 17,
    local_name: "conditionsGoverningAccess",
    label: "Conditions Governing Access",
    comment:
      "Information on the legal status or other regulations that restrict or affect access to the unit of description.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 17,
    local_name: "conditionsGoverningReproduction",
    label: "Conditions Governing Reproduction",
    comment:
      "Restrictions on reproduction of the unit of description after access has been provided.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 17,
    local_name: "languageScriptsOfMaterial",
    label: "Language / Scripts of Material",
    comment: "Language(s) and/or script(s) of the materials in the unit of description.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 17,
    local_name: "physicalTechnicalRequirements",
    label: "Physical Characteristics and Technical Requirements",
    comment:
      "Physical condition and any technical requirements that affect use of the unit of description.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 17,
    local_name: "findingAids",
    label: "Finding Aids",
    comment:
      "Information about any finding aids that relate to the context or content of the unit of description.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 17,
    local_name: "existenceAndLocationOfOriginals",
    label: "Existence and Location of Originals",
    comment:
      "Information about the existence, location, availability and/or destruction of originals.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 17,
    local_name: "existenceAndLocationOfCopies",
    label: "Existence and Location of Copies",
    comment: "Information about copies of the unit of description.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 17,
    local_name: "relatedUnitsOfDescription",
    label: "Related Units of Description",
    comment:
      "Information about units of description in the same or other repositories that are related by provenance or other association.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 17,
    local_name: "publicationNote",
    label: "Publication Note",
    comment:
      "A citation to, and/or information about a publication based on, using, about or transcribing the unit of description.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 17,
    local_name: "note",
    label: "Note",
    comment: "Specialised information not accommodated by any of the other areas.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 17,
    local_name: "archivistNote",
    label: "Archivist's Note",
    comment: "A note on how the description was prepared and by whom.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 17,
    local_name: "rulesOrConventions",
    label: "Rules or Conventions",
    comment: "The rules or conventions applied in preparing the description.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 17,
    local_name: "dateOfDescriptions",
    label: "Date(s) of Descriptions",
    comment: "Date(s) the entry was prepared and/or revised.",
    type_value: "date"
  },

  # ── 18. EAD 3 ─────────────────────────────────────────────────────────────────
  %{
    owner_id: nil,
    vocabulary_id: 18,
    local_name: "recordId",
    label: "Record ID",
    comment: "A unique persistent identifier for the EAD instance.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 18,
    local_name: "unittitle",
    label: "Unit Title",
    comment: "Name of the described materials.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 18,
    local_name: "unitid",
    label: "Unit ID",
    comment: "Identifier for the unit of description, typically a reference code.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 18,
    local_name: "unitdatestructured",
    label: "Unit Date (Structured)",
    comment: "Date(s) of the materials being described, in structured form.",
    type_value: "date"
  },
  %{
    owner_id: nil,
    vocabulary_id: 18,
    local_name: "physdescstructured",
    label: "Physical Description (Structured)",
    comment: "Physical extent and form of the materials being described.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 18,
    local_name: "origination",
    label: "Origination",
    comment: "The creator(s) of the materials.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 18,
    local_name: "langmaterial",
    label: "Language of Materials",
    comment: "Language(s) of the materials described.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 18,
    local_name: "repository",
    label: "Repository",
    comment: "The name and address of the institution holding the described materials.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 18,
    local_name: "abstract",
    label: "Abstract",
    comment: "A very brief summary of the materials being described.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 18,
    local_name: "scopecontent",
    label: "Scope and Content",
    comment: "Describes the nature, scope, and informational content of the described materials.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 18,
    local_name: "bioghist",
    label: "Biographical / Historical Note",
    comment: "A concise essay about the life and activities of the creator(s).",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 18,
    local_name: "arrangement",
    label: "Arrangement",
    comment: "Information about the arrangement of the materials.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 18,
    local_name: "accessrestrict",
    label: "Access Restriction",
    comment: "Information about conditions that affect the availability of the materials.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 18,
    local_name: "userestrict",
    label: "Use Restriction",
    comment: "Information about limitations on the use of the materials after access.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 18,
    local_name: "controlaccess",
    label: "Controlled Access",
    comment: "Controlled access terms: subject headings, geographic names, personal names, etc.",
    type_value: "text"
  },

  # ── 19. EAC-CPF 2.0 ───────────────────────────────────────────────────────────
  %{
    owner_id: nil,
    vocabulary_id: 19,
    local_name: "entityType",
    label: "Entity Type",
    comment: "The type of entity being described: person, corporateBody, or family.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 19,
    local_name: "nameEntry",
    label: "Name Entry",
    comment: "A name by which the entity is known.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 19,
    local_name: "nameEntryParallel",
    label: "Parallel Name Entry",
    comment: "A parallel form of a name entry (e.g., in another language or script).",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 19,
    local_name: "authorizedForm",
    label: "Authorized Form",
    comment: "The name form that is the authorised access point.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 19,
    local_name: "alternativeForm",
    label: "Alternative Form",
    comment: "An alternative form of a name.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 19,
    local_name: "existDates",
    label: "Exist Dates",
    comment:
      "The dates of existence of the entity (birth/death for persons, founding/dissolution for corporate bodies).",
    type_value: "date"
  },
  %{
    owner_id: nil,
    vocabulary_id: 19,
    local_name: "places",
    label: "Places",
    comment: "Significant places associated with the entity.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 19,
    local_name: "legalStatuses",
    label: "Legal Statuses",
    comment: "Legal status of a corporate body.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 19,
    local_name: "functions",
    label: "Functions",
    comment: "Functions, occupations, and activities of the entity.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 19,
    local_name: "occupations",
    label: "Occupations",
    comment: "Occupations or roles of a person.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 19,
    local_name: "biogHist",
    label: "Biographical / Historical Note",
    comment: "A concise biographical or historical note on the entity.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 19,
    local_name: "structureOrGenealogy",
    label: "Structure or Genealogy",
    comment:
      "Internal structural information about a corporate body, or genealogical information about a family.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 19,
    local_name: "cpfRelation",
    label: "CPF Relation",
    comment: "A relationship between the entity and another corporate body, person, or family.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 19,
    local_name: "resourceRelation",
    label: "Resource Relation",
    comment: "A relationship between the entity and archival records or other resources.",
    type_value: "text"
  },

  # ── 20. Records in Contexts (RiC) ─────────────────────────────────────────────
  %{
    owner_id: nil,
    vocabulary_id: 20,
    local_name: "hasCreator",
    label: "Has Creator",
    comment: "Relates a record or record set to its creator agent.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 20,
    local_name: "hasAccumulationDate",
    label: "Has Accumulation Date",
    comment: "Relates a record or record set to its accumulation date(s).",
    type_value: "date"
  },
  %{
    owner_id: nil,
    vocabulary_id: 20,
    local_name: "hasProvenance",
    label: "Has Provenance",
    comment: "Relates a record or record set to an agent that had custody or ownership.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 20,
    local_name: "hasContentOfType",
    label: "Has Content of Type",
    comment: "Relates a record or record set to a content type.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 20,
    local_name: "isAssociatedWithPlace",
    label: "Is Associated With Place",
    comment: "Relates a thing to a place.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 20,
    local_name: "hasLegalStatus",
    label: "Has Legal Status",
    comment: "Relates a thing to a legal status.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 20,
    local_name: "isRelatedTo",
    label: "Is Related To",
    comment: "A generic relation between two RiC entities.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 20,
    local_name: "hasIdentifier",
    label: "Has Identifier",
    comment: "Relates a thing to an identifier.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 20,
    local_name: "hasTitle",
    label: "Has Title",
    comment: "The title associated with a record or record set.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 20,
    local_name: "hasLanguage",
    label: "Has Language",
    comment: "Language of a record or record set.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 20,
    local_name: "scopeAndContent",
    label: "Scope and Content",
    comment: "Broad description of the scope and content of a record or record set.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 20,
    local_name: "conditionsOfAccess",
    label: "Conditions of Access",
    comment: "Conditions governing access to the records.",
    type_value: "textarea"
  },

  # ── 21. PREMIS 3.0 ─────────────────────────────────────────────────────────────
  %{
    owner_id: nil,
    vocabulary_id: 21,
    local_name: "objectIdentifier",
    label: "Object Identifier",
    comment: "An unambiguous value that refers to the PREMIS object within the local system.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 21,
    local_name: "objectCategory",
    label: "Object Category",
    comment:
      "Categorisation of the object (intellectual entity, representation, file, or bitstream).",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 21,
    local_name: "preservationLevel",
    label: "Preservation Level",
    comment: "A high-level description of the overall preservation approach for the object.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 21,
    local_name: "significantProperties",
    label: "Significant Properties",
    comment: "Characteristics of a digital object that must be maintained over time.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 21,
    local_name: "fixity",
    label: "Fixity (Checksum)",
    comment: "A checksum or message digest to verify integrity of the file.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 21,
    local_name: "size",
    label: "Size",
    comment: "Size of the stored object in bytes.",
    type_value: "integer"
  },
  %{
    owner_id: nil,
    vocabulary_id: 21,
    local_name: "format",
    label: "Format",
    comment: "The file format of the object (PRONOM PUID or MIME type).",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 21,
    local_name: "creatingApplication",
    label: "Creating Application",
    comment: "The application that created the object.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 21,
    local_name: "originalName",
    label: "Original Name",
    comment: "Original filename at the time of ingest.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 21,
    local_name: "storage",
    label: "Storage",
    comment: "Storage location or medium identifier.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 21,
    local_name: "eventIdentifier",
    label: "Event Identifier",
    comment: "An unambiguous value that refers to the PREMIS event.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 21,
    local_name: "eventType",
    label: "Event Type",
    comment:
      "A term that uniquely identifies the type of event (e.g., ingest, validation, fixity check).",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 21,
    local_name: "eventDateTime",
    label: "Event Date/Time",
    comment:
      "The single date and time, or the start date and time of a date range, when the event occurred.",
    type_value: "date"
  },
  %{
    owner_id: nil,
    vocabulary_id: 21,
    local_name: "eventOutcome",
    label: "Event Outcome",
    comment: "A term indicating the overall result of the event (success, failure, etc.).",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 21,
    local_name: "agentType",
    label: "Agent Type",
    comment: "The type of agent performing the event (person, organisation, or software).",
    type_value: "text"
  },

  # ── 22. ISAAR(CPF) ────────────────────────────────────────────────────────────
  %{
    owner_id: nil,
    vocabulary_id: 22,
    local_name: "typeOfEntity",
    label: "Type of Entity",
    comment: "The type of entity (corporate body, person, or family) being described.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 22,
    local_name: "authorizedFormOfName",
    label: "Authorized Form of Name",
    comment: "The standardised form of name for the entity.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 22,
    local_name: "parallelFormsOfName",
    label: "Parallel Forms of Name",
    comment: "Forms of the authorised name in different languages or scripts.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 22,
    local_name: "standardizedFormsOfName",
    label: "Standardized Forms of Name",
    comment:
      "Standardised forms of name for the entity constructed according to other conventions.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 22,
    local_name: "datesOfExistence",
    label: "Dates of Existence",
    comment: "Dates of existence of the corporate body, person, or family.",
    type_value: "date"
  },
  %{
    owner_id: nil,
    vocabulary_id: 22,
    local_name: "history",
    label: "History",
    comment: "A concise history of the corporate body, person, or family.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 22,
    local_name: "places",
    label: "Places",
    comment: "Significant places associated with the entity.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 22,
    local_name: "legalStatus",
    label: "Legal Status",
    comment: "Legal status of a corporate body.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 22,
    local_name: "functions",
    label: "Functions",
    comment: "Functions, occupations and activities of the entity.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 22,
    local_name: "mandatesOrSources",
    label: "Mandates / Sources of Authority",
    comment: "The legal and other mandate(s) under which the corporate body operates.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 22,
    local_name: "internalStructure",
    label: "Internal Structure / Genealogy",
    comment:
      "Significant information about the internal structure of a corporate body, or the genealogy of a family.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 22,
    local_name: "generalContext",
    label: "General Context",
    comment:
      "Significant general social, cultural, economic, political, and/or historical context.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 22,
    local_name: "relatedCorporateBodies",
    label: "Related Corporate Bodies / Persons / Families",
    comment:
      "The name of the related corporate body, person, or family and the nature of the relationship.",
    type_value: "text"
  },

  # ── 23. CIDOC CRM ─────────────────────────────────────────────────────────────
  %{
    owner_id: nil,
    vocabulary_id: 23,
    local_name: "E1_CRM_Entity",
    label: "E1 CRM Entity",
    comment: "The most general class of the CIDOC CRM. All classes are subclasses of this.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 23,
    local_name: "E18_Physical_Thing",
    label: "E18 Physical Thing",
    comment: "Subclass of E1 CRM Entity — a thing with a physical form.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 23,
    local_name: "E22_Human_Made_Object",
    label: "E22 Human-Made Object",
    comment: "A physical object purposely created by human activity.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 23,
    local_name: "E21_Person",
    label: "E21 Person",
    comment: "A real person, living or deceased.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 23,
    local_name: "E74_Group",
    label: "E74 Group",
    comment: "Any gatherings or organisation of Actors.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 23,
    local_name: "E52_Time_Span",
    label: "E52 Time-Span",
    comment: "A period in time.",
    type_value: "date"
  },
  %{
    owner_id: nil,
    vocabulary_id: 23,
    local_name: "E53_Place",
    label: "E53 Place",
    comment: "An extent in space.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 23,
    local_name: "E55_Type",
    label: "E55 Type",
    comment: "A set of categories or terms forming a classification scheme.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 23,
    local_name: "E65_Creation",
    label: "E65 Creation",
    comment: "The event of bringing an item into existence (intellectual/conceptual creation).",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 23,
    local_name: "E12_Production",
    label: "E12 Production",
    comment: "The event of producing a physical object.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 23,
    local_name: "P1_is_identified_by",
    label: "P1 is identified by",
    comment: "Associates an item with an identifier or appellation.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 23,
    local_name: "P2_has_type",
    label: "P2 has type",
    comment: "Categorises the subject with the object.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 23,
    local_name: "P4_has_time_span",
    label: "P4 has time-span",
    comment: "Defines the time-span of the period or event.",
    type_value: "date"
  },
  %{
    owner_id: nil,
    vocabulary_id: 23,
    local_name: "P7_took_place_at",
    label: "P7 took place at",
    comment: "The location at which an event took place.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 23,
    local_name: "P14_carried_out_by",
    label: "P14 carried out by",
    comment: "The agent who carried out an activity.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 23,
    local_name: "P43_has_dimension",
    label: "P43 has dimension",
    comment: "Dimension(s) of the physical thing (height, width, depth, weight).",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 23,
    local_name: "P45_consists_of",
    label: "P45 consists of",
    comment: "The material(s) of which the object is composed.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 23,
    local_name: "P52_has_current_owner",
    label: "P52 has current owner",
    comment: "The current legal owner of the physical thing.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 23,
    local_name: "P55_has_current_location",
    label: "P55 has current location",
    comment: "The current location of the physical thing.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 23,
    local_name: "P62_depicts",
    label: "P62 depicts",
    comment: "The entities visually represented in an image.",
    type_value: "text"
  },

  # ── 24. SPECTRUM 5.1 ──────────────────────────────────────────────────────────
  %{
    owner_id: nil,
    vocabulary_id: 24,
    local_name: "objectNumber",
    label: "Object Number",
    comment: "Unique accession number or identifier assigned to the object.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 24,
    local_name: "objectName",
    label: "Object Name",
    comment: "The name by which the object is known.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 24,
    local_name: "objectDescription",
    label: "Object Description",
    comment:
      "A textual description of the object's appearance, subject matter, and significant features.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 24,
    local_name: "objectProduction",
    label: "Object Production",
    comment: "Information about the production of the object: maker, date, place, method.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 24,
    local_name: "objectHistory",
    label: "Object History",
    comment: "The known history of the object from creation to acquisition.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 24,
    local_name: "objectCondition",
    label: "Object Condition",
    comment: "A description of the physical condition of the object.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 24,
    local_name: "objectValuation",
    label: "Object Valuation",
    comment: "The current assessed value of the object.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 24,
    local_name: "currentLocation",
    label: "Current Location",
    comment: "The current physical location of the object within the institution.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 24,
    local_name: "objectEntryDetails",
    label: "Object Entry Details",
    comment: "Information about how the object arrived at the institution.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 24,
    local_name: "acquisitionDetails",
    label: "Acquisition Details",
    comment:
      "Information about the formal acquisition of the object (method, date, source, cost).",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 24,
    local_name: "loanInDetails",
    label: "Loan In Details",
    comment: "Details of the loan agreement when the object is on loan to the institution.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 24,
    local_name: "loanOutDetails",
    label: "Loan Out Details",
    comment: "Details of the loan agreement when the object is loaned to another institution.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 24,
    local_name: "movementDetails",
    label: "Movement Details",
    comment: "A record of each movement of the object within or outside the institution.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 24,
    local_name: "ownershipDetails",
    label: "Ownership Details",
    comment: "Information about who owns the object.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 24,
    local_name: "rights",
    label: "Rights",
    comment: "Copyright and intellectual property rights information.",
    type_value: "textarea"
  },

  # ── 25. LIDO 1.1 ──────────────────────────────────────────────────────────────
  %{
    owner_id: nil,
    vocabulary_id: 25,
    local_name: "lidoRecID",
    label: "LIDO Record ID",
    comment: "A unique persistent identifier for the LIDO record.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 25,
    local_name: "objectPublishedID",
    label: "Object Published ID",
    comment: "A globally unique identifier for the object published on the web.",
    type_value: "uri"
  },
  %{
    owner_id: nil,
    vocabulary_id: 25,
    local_name: "category",
    label: "Category",
    comment: "The CIDOC CRM class that is the overall type of the described object.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 25,
    local_name: "objectClassification",
    label: "Object Classification",
    comment:
      "Classification of the object using standardised terminology (object name, classification).",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 25,
    local_name: "objectIdentification",
    label: "Object Identification",
    comment: "Title, inscriptions, repository, and measurements of the object.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 25,
    local_name: "objectMeasurements",
    label: "Object Measurements",
    comment: "The dimensions or other measurements of the object.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 25,
    local_name: "eventWrap",
    label: "Events",
    comment: "Events associated with the object (production, acquisition, exhibition, etc.).",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 25,
    local_name: "eventType",
    label: "Event Type",
    comment:
      "The type of event (e.g., Production, Acquisition, Exhibition, Move, Loss, Restoration, Provenance).",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 25,
    local_name: "eventDate",
    label: "Event Date",
    comment: "The date(s) of the event.",
    type_value: "date"
  },
  %{
    owner_id: nil,
    vocabulary_id: 25,
    local_name: "eventActor",
    label: "Event Actor",
    comment: "An actor (person or organisation) involved in the event.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 25,
    local_name: "objectRelation",
    label: "Object Relation",
    comment: "Relationships of the object to other objects or subjects.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 25,
    local_name: "rightsWork",
    label: "Rights of Work",
    comment: "Rights information about the object.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 25,
    local_name: "recordSource",
    label: "Record Source",
    comment: "The institution or person that provided the record.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 25,
    local_name: "resourceSet",
    label: "Resource Set",
    comment: "Digital resources representing the object (images, 3D scans, etc.).",
    type_value: "uri"
  },

  # ── 26. ICOM Object ID ────────────────────────────────────────────────────────
  %{
    owner_id: nil,
    vocabulary_id: 26,
    local_name: "typeOfObject",
    label: "Type of Object",
    comment:
      "The specific type of object being documented (e.g., painting, sculpture, vase, coin).",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 26,
    local_name: "materialsAndTechniques",
    label: "Materials and Techniques",
    comment: "The materials from which the object is made and the techniques used to make it.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 26,
    local_name: "measurements",
    label: "Measurements",
    comment: "The dimensions and/or weight of the object.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 26,
    local_name: "inscriptionsAndMarkings",
    label: "Inscriptions and Markings",
    comment: "Any lettering, inscriptions, labels, stamps, and/or hallmarks on the object.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 26,
    local_name: "distinguishingFeatures",
    label: "Distinguishing Features",
    comment:
      "Any unusual features, damage, or repair that may be used to distinguish the object.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 26,
    local_name: "titleOrSubject",
    label: "Title or Subject",
    comment: "The title by which the object is known, or a brief description of its subject.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 26,
    local_name: "datePeriod",
    label: "Date or Period",
    comment: "The date or period of production of the object.",
    type_value: "date"
  },
  %{
    owner_id: nil,
    vocabulary_id: 26,
    local_name: "maker",
    label: "Maker",
    comment: "The person(s) or organisation(s) responsible for making the object.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 26,
    local_name: "images",
    label: "Images",
    comment: "Photographic images of the object from multiple angles.",
    type_value: "uri"
  },

  # ── 27. Europeana EDM ─────────────────────────────────────────────────────────
  %{
    owner_id: nil,
    vocabulary_id: 27,
    local_name: "type",
    label: "EDM Type",
    comment: "The type of the provided object (TEXT, IMAGE, SOUND, VIDEO, 3D).",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 27,
    local_name: "rights",
    label: "Rights",
    comment:
      "The rights statement for the object (Creative Commons URI or RightsStatements.org URI).",
    type_value: "uri"
  },
  %{
    owner_id: nil,
    vocabulary_id: 27,
    local_name: "dataProvider",
    label: "Data Provider",
    comment: "The name of the organisation that provides data to an aggregator.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 27,
    local_name: "provider",
    label: "Provider",
    comment: "The name of the aggregating organisation that provided data to Europeana.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 27,
    local_name: "isShownAt",
    label: "Is Shown At",
    comment: "An unambiguous URL reference to the digital object on the provider's website.",
    type_value: "uri"
  },
  %{
    owner_id: nil,
    vocabulary_id: 27,
    local_name: "isShownBy",
    label: "Is Shown By",
    comment: "An unambiguous URL reference to a digital representation of the CHO.",
    type_value: "uri"
  },
  %{
    owner_id: nil,
    vocabulary_id: 27,
    local_name: "object",
    label: "Object",
    comment: "The URL of a thumbnail representing the digital object.",
    type_value: "uri"
  },
  %{
    owner_id: nil,
    vocabulary_id: 27,
    local_name: "currentLocation",
    label: "Current Location",
    comment:
      "The geographic location and/or name of the repository where the physical object resides.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 27,
    local_name: "hasMet",
    label: "Has Met",
    comment: "A reference to entities or events the described object has been associated with.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 27,
    local_name: "hasType",
    label: "Has Type",
    comment: "A type of the described resource beyond the EDM type.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 27,
    local_name: "incorporates",
    label: "Incorporates",
    comment: "A work that is incorporated in the described work.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 27,
    local_name: "realizationOf",
    label: "Realisation Of",
    comment: "Relates an instance to the work of which it is a realisation.",
    type_value: "uri"
  },
  %{
    owner_id: nil,
    vocabulary_id: 27,
    local_name: "isDerivativeOf",
    label: "Is Derivative Of",
    comment: "An original work from which the described object is derived.",
    type_value: "uri"
  },
  %{
    owner_id: nil,
    vocabulary_id: 27,
    local_name: "wasPresentAt",
    label: "Was Present At",
    comment: "An event at which the described object was present.",
    type_value: "text"
  },

  # ── 28. SKOS ──────────────────────────────────────────────────────────────────
  %{
    owner_id: nil,
    vocabulary_id: 28,
    local_name: "prefLabel",
    label: "Preferred Label",
    comment: "The preferred lexical label for a resource, in a given language.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 28,
    local_name: "altLabel",
    label: "Alternative Label",
    comment: "An alternative lexical label for a resource (variant, abbreviation, synonym).",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 28,
    local_name: "hiddenLabel",
    label: "Hidden Label",
    comment:
      "A lexical label for a resource that should be hidden when generating visual displays.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 28,
    local_name: "definition",
    label: "Definition",
    comment: "A statement or formal explanation of the meaning of a concept.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 28,
    local_name: "scopeNote",
    label: "Scope Note",
    comment: "A note that helps clarify the meaning and/or the use of a concept.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 28,
    local_name: "example",
    label: "Example",
    comment: "An example of the use of a concept.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 28,
    local_name: "historyNote",
    label: "History Note",
    comment: "A note about the past status/use/meaning of a concept.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 28,
    local_name: "editorialNote",
    label: "Editorial Note",
    comment: "A note for an editor, translator, or maintainer of the vocabulary.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 28,
    local_name: "notation",
    label: "Notation",
    comment: "A notation, code, or classification number (e.g., Dewey number, AAT ID).",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 28,
    local_name: "broader",
    label: "Broader",
    comment: "Relates a concept to a concept that is more general in meaning.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 28,
    local_name: "narrower",
    label: "Narrower",
    comment: "Relates a concept to a concept that is more specific in meaning.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 28,
    local_name: "related",
    label: "Related",
    comment:
      "Relates a concept to a concept with which there is an associative semantic relationship.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 28,
    local_name: "inScheme",
    label: "In Scheme",
    comment: "Relates a resource to the concept scheme of which it is part.",
    type_value: "uri"
  },
  %{
    owner_id: nil,
    vocabulary_id: 28,
    local_name: "hasTopConcept",
    label: "Has Top Concept",
    comment:
      "Relates a concept scheme to a concept which is topmost in the broader/narrower concept hierarchy.",
    type_value: "text"
  },

  # ── 29. IIIF Presentation API 3 ───────────────────────────────────────────────
  %{
    owner_id: nil,
    vocabulary_id: 29,
    local_name: "id",
    label: "ID",
    comment: "The URI that identifies the IIIF resource.",
    type_value: "uri"
  },
  %{
    owner_id: nil,
    vocabulary_id: 29,
    local_name: "type",
    label: "Type",
    comment: "The type of IIIF resource (Manifest, Collection, Canvas, AnnotationPage, etc.).",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 29,
    local_name: "label",
    label: "Label",
    comment: "A human-readable label for the resource, intended for display to the user.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 29,
    local_name: "summary",
    label: "Summary",
    comment:
      "A short textual summary intended to be conveyed to the user when the metadata property is not shown.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 29,
    local_name: "metadata",
    label: "Metadata",
    comment: "An ordered list of label/value pairs for display to the user.",
    type_value: "textarea"
  },
  %{
    owner_id: nil,
    vocabulary_id: 29,
    local_name: "requiredStatement",
    label: "Required Statement",
    comment:
      "A required statement of attribution or other information that must be shown to the user.",
    type_value: "text"
  },
  %{
    owner_id: nil,
    vocabulary_id: 29,
    local_name: "rights",
    label: "Rights",
    comment:
      "A string that identifies a license or rights statement that applies to the content.",
    type_value: "uri"
  },
  %{
    owner_id: nil,
    vocabulary_id: 29,
    local_name: "logo",
    label: "Logo",
    comment: "A small image that represents an agent (organisation or person).",
    type_value: "uri"
  },
  %{
    owner_id: nil,
    vocabulary_id: 29,
    local_name: "thumbnail",
    label: "Thumbnail",
    comment: "A content resource intended to be used as a thumbnail for the resource.",
    type_value: "uri"
  },
  %{
    owner_id: nil,
    vocabulary_id: 29,
    local_name: "homepage",
    label: "Homepage",
    comment: "A web page that is about the object represented by the resource.",
    type_value: "uri"
  },
  %{
    owner_id: nil,
    vocabulary_id: 29,
    local_name: "seeAlso",
    label: "See Also",
    comment:
      "A machine-readable resource (e.g., MODS/RDF) that is related to the current resource.",
    type_value: "uri"
  },
  %{
    owner_id: nil,
    vocabulary_id: 29,
    local_name: "partOf",
    label: "Part Of",
    comment: "A containing resource that includes the current resource.",
    type_value: "uri"
  },
  %{
    owner_id: nil,
    vocabulary_id: 29,
    local_name: "start",
    label: "Start Canvas",
    comment: "A Canvas, or part of a Canvas, that the client should display on initialisation.",
    type_value: "uri"
  },
  %{
    owner_id: nil,
    vocabulary_id: 29,
    local_name: "viewingDirection",
    label: "Viewing Direction",
    comment:
      "The direction in which Canvases should be presented (left-to-right, right-to-left, top-to-bottom, bottom-to-top).",
    type_value: "text"
  }
]

for property <- properties_list do
  # Check if property already exists by local_name and vocabulary_id
  vocabulary_id =
    case property[:vocabulary_id] do
      1 -> vocabulary_1.id
      2 -> vocabulary_2.id
      3 -> vocabulary_3.id
      4 -> vocabulary_4.id
      5 -> vocabulary_5.id
      6 -> vocabulary_6.id
      7 -> vocabulary_7.id
      8 -> vocabulary_8.id
      9 -> vocabulary_9.id
      10 -> vocabulary_10.id
      11 -> vocabulary_11.id
      12 -> vocabulary_12.id
      13 -> vocabulary_13.id
      14 -> vocabulary_14.id
      15 -> vocabulary_15.id
      16 -> vocabulary_16.id
      17 -> vocabulary_17.id
      18 -> vocabulary_18.id
      19 -> vocabulary_19.id
      20 -> vocabulary_20.id
      21 -> vocabulary_21.id
      22 -> vocabulary_22.id
      23 -> vocabulary_23.id
      24 -> vocabulary_24.id
      25 -> vocabulary_25.id
      26 -> vocabulary_26.id
      27 -> vocabulary_27.id
      28 -> vocabulary_28.id
      29 -> vocabulary_29.id
      _ -> raise "Invalid vocabulary_id: #{property[:vocabulary_id]}"
    end

  case Repo.get_by(Property, local_name: property[:local_name], vocabulary_id: vocabulary_id) do
    nil ->
      %Property{
        owner_id: property[:owner_id],
        vocabulary_id: vocabulary_id,
        local_name: property[:local_name],
        label: property[:label],
        information: property[:comment],
        type_value: property[:type_value]
      }
      |> Repo.insert!()

    _existing ->
      # Property already exists, skip
      :ok
  end
end
