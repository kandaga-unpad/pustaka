alias Voile.Repo
alias Voile.Schema.Metadata
alias Voile.Schema.Metadata.Property

vocabulary_1 = Repo.get!(Metadata.Vocabulary, 1)
vocabulary_2 = Repo.get!(Metadata.Vocabulary, 2)
vocabulary_3 = Repo.get!(Metadata.Vocabulary, 3)
vocabulary_4 = Repo.get!(Metadata.Vocabulary, 4)
vocabulary_5 = Repo.get!(Metadata.Vocabulary, 5)

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
