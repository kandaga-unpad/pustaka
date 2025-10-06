alias Voile.Repo
alias Voile.Schema.Metadata
alias Voile.Schema.Metadata.ResourceClass

vocabulary_1 = Repo.get!(Metadata.Vocabulary, 1)
vocabulary_2 = Repo.get!(Metadata.Vocabulary, 2)
vocabulary_3 = Repo.get!(Metadata.Vocabulary, 3)
vocabulary_4 = Repo.get!(Metadata.Vocabulary, 4)

resource_class = [
  %{
    information: "A resource that acts or has the power to act.",
    label: "Agent",
    local_name: "Agent",
    owner_id: nil,
    vocabulary_id: 1,
    glam_type: "Library"
  },
  %{
    information: "A group of agents.",
    label: "Agent Class",
    local_name: "AgentClass",
    owner_id: nil,
    vocabulary_id: 1,
    glam_type: "Library"
  },
  %{
    information: "A book, article, or other documentary resource.",
    label: "Bibliographic Resource",
    local_name: "BibliographicResource",
    owner_id: nil,
    vocabulary_id: 1,
    glam_type: "Library"
  },
  %{
    information: "A digital resource format.",
    label: "File Format",
    local_name: "FileFormat",
    owner_id: nil,
    vocabulary_id: 1,
    glam_type: "Archive"
  },
  %{
    information: "A rate at which something recurs.",
    label: "Frequency",
    local_name: "Frequency",
    owner_id: nil,
    vocabulary_id: 1,
    glam_type: "Library"
  },
  %{
    information: "The extent or range of judicial, law enforcement, or other authority.",
    label: "Jurisdiction",
    local_name: "Jurisdiction",
    owner_id: nil,
    vocabulary_id: 1,
    glam_type: "Archive"
  },
  %{
    information: "A legal document giving official permission to do something with a Resource.",
    label: "License Document",
    local_name: "LicenseDocument",
    owner_id: nil,
    vocabulary_id: 1,
    glam_type: "Archive"
  },
  %{
    information: "A system of signs, symbols, sounds, gestures, or rules used in communication.",
    label: "Linguistic System",
    local_name: "LinguisticSystem",
    owner_id: nil,
    vocabulary_id: 1,
    glam_type: "Library"
  },
  %{
    information: "A spatial region or named place.",
    label: "Location",
    local_name: "Location",
    owner_id: nil,
    vocabulary_id: 1,
    glam_type: "Archive"
  },
  %{
    information: "A location, period of time, or jurisdiction.",
    label: "Location, Period, or Jurisdiction",
    local_name: "LocationPeriodOrJurisdiction",
    owner_id: nil,
    vocabulary_id: 1,
    glam_type: "Archive"
  },
  %{
    information: "A file format or physical medium.",
    label: "Media Type",
    local_name: "MediaType",
    owner_id: nil,
    vocabulary_id: 1,
    glam_type: "Archive"
  },
  %{
    information: "A media type or extent.",
    label: "Media Type or Extent",
    local_name: "MediaTypeOrExtent",
    owner_id: nil,
    vocabulary_id: 1,
    glam_type: "Archive"
  },
  %{
    information: "A process that is used to engender knowledge, attitudes, and skills.",
    label: "Method of Instruction",
    local_name: "MethodOfInstruction",
    owner_id: nil,
    vocabulary_id: 1,
    glam_type: "Library"
  },
  %{
    information: "A method by which resources are added to a collection.",
    label: "Method of Accrual",
    local_name: "MethodOfAccrual",
    owner_id: nil,
    vocabulary_id: 1,
    glam_type: "Library"
  },
  %{
    information: "An interval of time that is named or defined by its start and end dates.",
    label: "Period of Time",
    local_name: "PeriodOfTime",
    owner_id: nil,
    vocabulary_id: 1,
    glam_type: "Archive"
  },
  %{
    information: "A physical material or carrier.",
    label: "Physical Medium",
    local_name: "PhysicalMedium",
    owner_id: nil,
    vocabulary_id: 1,
    glam_type: "Museum"
  },
  %{
    information: "A material thing.",
    label: "Physical Resource",
    local_name: "PhysicalResource",
    owner_id: nil,
    vocabulary_id: 1,
    glam_type: "Museum"
  },
  %{
    information:
      "A plan or course of action by an authority, intended to influence and determine decisions, actions, and other matters.",
    label: "Policy",
    local_name: "Policy",
    owner_id: nil,
    vocabulary_id: 1,
    glam_type: "Archive"
  },
  %{
    information:
      "A statement of any changes in ownership and custody of a resource since its creation that are significant for its authenticity, integrity, and interpretation.",
    label: "Provenance Statement",
    local_name: "ProvenanceStatement",
    owner_id: nil,
    vocabulary_id: 1,
    glam_type: "Archive"
  },
  %{
    information:
      "A statement about the intellectual property rights (IPR) held in or over a Resource, a legal document giving official permission to do something with a resource, or a statement about access rights.",
    label: "Rights Statement",
    local_name: "RightsStatement",
    owner_id: nil,
    vocabulary_id: 1,
    glam_type: "Archive"
  },
  %{
    information: "A dimension or extent, or a time taken to play or execute.",
    label: "Size or Duration",
    local_name: "SizeOrDuration",
    owner_id: nil,
    vocabulary_id: 1,
    glam_type: "Library"
  },
  %{
    information:
      "A basis for comparison; a reference point against which other things can be evaluated.",
    label: "Standard",
    local_name: "Standard",
    owner_id: nil,
    vocabulary_id: 1,
    glam_type: "Library"
  },
  %{
    information: "An aggregation of resources.",
    label: "Collection",
    local_name: "Collection",
    owner_id: nil,
    vocabulary_id: 2,
    glam_type: "Archive"
  },
  %{
    information: "Data encoded in a defined structure.",
    label: "Dataset",
    local_name: "Dataset",
    owner_id: nil,
    vocabulary_id: 2,
    glam_type: "Archive"
  },
  %{
    information: "A non-persistent, time-based occurrence.",
    label: "Event",
    local_name: "Event",
    owner_id: nil,
    vocabulary_id: 2,
    glam_type: "Archive"
  },
  %{
    information: "A visual representation other than text.",
    label: "Image",
    local_name: "Image",
    owner_id: nil,
    vocabulary_id: 2,
    glam_type: "Gallery"
  },
  %{
    information:
      "A resource requiring interaction from the user to be understood, executed, or experienced.",
    label: "Interactive Resource",
    local_name: "InteractiveResource",
    owner_id: nil,
    vocabulary_id: 2,
    glam_type: "Museum"
  },
  %{
    information: "A system that provides one or more functions.",
    label: "Service",
    local_name: "Service",
    owner_id: nil,
    vocabulary_id: 2,
    glam_type: "Archive"
  },
  %{
    information: "A computer program in source or compiled form.",
    label: "Software",
    local_name: "Software",
    owner_id: nil,
    vocabulary_id: 2,
    glam_type: "Archive"
  },
  %{
    information: "A resource primarily intended to be heard.",
    label: "Sound",
    local_name: "Sound",
    owner_id: nil,
    vocabulary_id: 2,
    glam_type: "Archive"
  },
  %{
    information: "A resource consisting primarily of words for reading.",
    label: "Text",
    local_name: "Text",
    owner_id: nil,
    vocabulary_id: 2,
    glam_type: "Library"
  },
  %{
    information: "An inanimate, three-dimensional object or substance.",
    label: "Physical Object",
    local_name: "PhysicalObject",
    owner_id: nil,
    vocabulary_id: 2,
    glam_type: "Museum"
  },
  %{
    information: "A static visual representation.",
    label: "Still Image",
    local_name: "StillImage",
    owner_id: nil,
    vocabulary_id: 2,
    glam_type: "Gallery"
  },
  %{
    information:
      "A series of visual representations imparting an impression of motion when shown in succession.",
    label: "Moving Image",
    local_name: "MovingImage",
    owner_id: nil,
    vocabulary_id: 2,
    glam_type: "Gallery"
  },
  %{
    information: "A scholarly academic article, typically published in a journal.",
    label: "Academic Article",
    local_name: "AcademicArticle",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Library"
  },
  %{
    information:
      "A written composition in prose, usually nonfiction, on a specific topic, forming an independent part of a book or other publication, as a newspaper or magazine.",
    label: "Article",
    local_name: "Article",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Library"
  },
  %{
    information: "An audio document; aka record.",
    label: "audio document",
    local_name: "AudioDocument",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Archive"
  },
  %{
    information: "An audio-visual document; film, video, and so forth.",
    label: "audio-visual document",
    local_name: "AudioVisualDocument",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Archive"
  },
  %{
    information: "Draft legislation presented for discussion to a legal body.",
    label: "Bill",
    local_name: "Bill",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Archive"
  },
  %{
    information:
      "A written or printed work of fiction or nonfiction, usually on sheets of paper fastened or bound together within covers.",
    label: "Book",
    local_name: "Book",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Library"
  },
  %{
    information: "A section of a book.",
    label: "Book Section",
    local_name: "BookSection",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Library"
  },
  %{
    information: "A written argument submitted to a court.",
    label: "Brief",
    local_name: "Brief",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Archive"
  },
  %{
    information: "A chapter of a book.",
    label: "Chapter",
    local_name: "Chapter",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Library"
  },
  %{
    information: "A collection of statutes.",
    label: "Code",
    local_name: "Code",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Archive"
  },
  %{
    information: "A document that simultaneously contains other documents.",
    label: "Collected Document",
    local_name: "CollectedDocument",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Archive"
  },
  %{
    information: "A collection of Documents or Collections",
    label: "Collection",
    local_name: "Collection",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Archive"
  },
  %{
    information: "A meeting for consultation or discussion.",
    label: "Conference",
    local_name: "Conference",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Archive"
  },
  %{
    information: "A collection of legal cases.",
    label: "Court Reporter",
    local_name: "CourtReporter",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Archive"
  },
  %{
    information:
      "A document (noun) is a bounded physical representation of body of information designed with the capacity (and usually intent) to communicate. A document may manifest symbolic, diagrammatic or sensory-representational information.",
    label: "Document",
    local_name: "Document",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Archive"
  },
  %{
    information: "a distinct part of a larger document or collected document.",
    label: "document part",
    local_name: "DocumentPart",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Archive"
  },
  %{
    information: "The status of the publication of a document.",
    label: "Document Status",
    local_name: "DocumentStatus",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Library"
  },
  %{
    information: "An edited book.",
    label: "Edited Book",
    local_name: "EditedBook",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Library"
  },
  %{
    information:
      "A written communication addressed to a person or organization and transmitted electronically.",
    label: "Email",
    local_name: "Email",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Archive"
  },
  %{
    information: nil,
    label: "Event",
    local_name: "Event",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Archive"
  },
  %{
    information: "A passage selected from a larger work.",
    label: "Excerpt",
    local_name: "Excerpt",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Library"
  },
  %{
    information: "aka movie.",
    label: "Film",
    local_name: "Film",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Gallery"
  },
  %{
    information:
      "An instance or a session in which testimony and arguments are presented, esp. before an official, as a judge in a lawsuit.",
    label: "Hearing",
    local_name: "Hearing",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Archive"
  },
  %{
    information: "A document that presents visual or diagrammatic information.",
    label: "Image",
    local_name: "Image",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Gallery"
  },
  %{
    information: "A formalized discussion between two or more people.",
    label: "Interview",
    local_name: "Interview",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Archive"
  },
  %{
    information:
      "something that is printed or published and distributed, esp. a given number of a periodical",
    label: "Issue",
    local_name: "Issue",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Library"
  },
  %{
    information: "A periodical of scholarly journal Articles.",
    label: "Journal",
    local_name: "Journal",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Library"
  },
  %{
    information: "A document accompanying a legal case.",
    label: "Legal Case Document",
    local_name: "LegalCaseDocument",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Archive"
  },
  %{
    information:
      "A document containing an authoritative determination (as a decree or judgment) made after consideration of facts or law.",
    label: "Decision",
    local_name: "LegalDecision",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Archive"
  },
  %{
    information: "A legal document; for example, a court decision, a brief, and so forth.",
    label: "Legal Document",
    local_name: "LegalDocument",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Archive"
  },
  %{
    information: "A legal document proposing or enacting a law or a group of laws.",
    label: "Legislation",
    local_name: "Legislation",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Archive"
  },
  %{
    information:
      "A written or printed communication addressed to a person or organization and usually transmitted by mail.",
    label: "Letter",
    local_name: "Letter",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Archive"
  },
  %{
    information:
      "A periodical of magazine Articles. A magazine is a publication that is issued periodically, usually bound in a paper cover, and typically contains essays, stories, poems, etc., by many writers, and often photographs and drawings, frequently specializing in a particular subject or area, as hobbies, news, or sports.",
    label: "Magazine",
    local_name: "Magazine",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Library"
  },
  %{
    information: "A small reference book, especially one giving instructions.",
    label: "Manual",
    local_name: "Manual",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Library"
  },
  %{
    information:
      "An unpublished Document, which may also be submitted to a publisher for publication.",
    label: "Manuscript",
    local_name: "Manuscript",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Archive"
  },
  %{
    information: "A graphical depiction of geographic features.",
    label: "Map",
    local_name: "Map",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Library"
  },
  %{
    information: "A loose, thematic, collection of Documents, often Books.",
    label: "Multivolume Book",
    local_name: "MultiVolumeBook",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Library"
  },
  %{
    information:
      "A periodical of documents, usually issued daily or weekly, containing current news, editorials, feature articles, and usually advertising.",
    label: "Newspaper",
    local_name: "Newspaper",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Library"
  },
  %{
    information: "Notes or annotations about a resource.",
    label: "Note",
    local_name: "Note",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Archive"
  },
  %{
    information:
      "A document describing the exclusive right granted by a government to an inventor to manufacture, use, or sell an invention for a certain number of years.",
    label: "Patent",
    local_name: "Patent",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Archive"
  },
  %{
    information: "A public performance.",
    label: "Performance",
    local_name: "Performance",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Gallery"
  },
  %{
    information: "A group of related documents issued at regular intervals.",
    label: "Periodical",
    local_name: "Periodical",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Library"
  },
  %{
    information: "A communication between an agent and one or more specific recipients.",
    label: "Personal Communication",
    local_name: "PersonalCommunication",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Archive"
  },
  %{
    information: "A personal communication manifested in some document.",
    label: "Personal Communication Document",
    local_name: "PersonalCommunicationDocument",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Archive"
  },
  %{
    information: "A compilation of documents published from an event, such as a conference.",
    label: "Proceedings",
    local_name: "Proceedings",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Library"
  },
  %{
    information: "An excerpted collection of words.",
    label: "Quote",
    local_name: "Quote",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Library"
  },
  %{
    information:
      "A document that presents authoritative reference information, such as a dictionary or encylopedia .",
    label: "Reference Source",
    local_name: "ReferenceSource",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Library"
  },
  %{
    information:
      "A document describing an account or statement describing in detail an event, situation, or the like, usually as the result of observation, inquiry, etc..",
    label: "Report",
    local_name: "Report",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Archive"
  },
  %{
    information: "A loose, thematic, collection of Documents, often Books.",
    label: "Series",
    local_name: "Series",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Library"
  },
  %{
    information: "A slide in a slideshow",
    label: "Slide",
    local_name: "Slide",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Gallery"
  },
  %{
    information:
      "A presentation of a series of slides, usually presented in front of an audience with written text and images.",
    label: "Slideshow",
    local_name: "Slideshow",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Gallery"
  },
  %{
    information: "A document describing a standard",
    label: "Standard",
    local_name: "Standard",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Library"
  },
  %{
    information: "A bill enacted into law.",
    label: "Statute",
    local_name: "Statute",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Archive"
  },
  %{
    information:
      "A document created to summarize research findings associated with the completion of an academic degree.",
    label: "Thesis",
    local_name: "Thesis",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Library"
  },
  %{
    information: "The academic degree of a Thesis",
    label: "Thesis degree",
    local_name: "ThesisDegree",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Library"
  },
  %{
    information:
      "A web page is an online document available (at least initially) on the world wide web. A web page is written first and foremost to appear on the web, as distinct from other online resources such as books, manuscripts or audio documents which use the web primarily as a distribution mechanism alongside other more traditional methods such as print.",
    label: "Webpage",
    local_name: "Webpage",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Archive"
  },
  %{
    information: "A group of Webpages accessible on the Web.",
    label: "Website",
    local_name: "Website",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Archive"
  },
  %{
    information:
      "A seminar, discussion group, or the like, that emphasizes zxchange of ideas and the demonstration and application of techniques, skills, etc.",
    label: "Workshop",
    local_name: "Workshop",
    owner_id: nil,
    vocabulary_id: 3,
    glam_type: "Archive"
  },
  %{
    information:
      "A foaf:LabelProperty is any RDF property with texual values that serve as labels.",
    label: "Label Property",
    local_name: "LabelProperty",
    owner_id: nil,
    vocabulary_id: 4,
    glam_type: "Library"
  },
  %{
    information: "A person.",
    label: "Person",
    local_name: "Person",
    owner_id: nil,
    vocabulary_id: 4,
    glam_type: "Archive"
  },
  %{
    information: "A document.",
    label: "Document",
    local_name: "Document",
    owner_id: nil,
    vocabulary_id: 4,
    glam_type: "Archive"
  },
  %{
    information: "An organization.",
    label: "Organization",
    local_name: "Organization",
    owner_id: nil,
    vocabulary_id: 4,
    glam_type: "Archive"
  },
  %{
    information: "A class of Agents.",
    label: "Group",
    local_name: "Group",
    owner_id: nil,
    vocabulary_id: 4,
    glam_type: "Archive"
  },
  %{
    information: "An agent (eg. person, group, software or physical artifact).",
    label: "Agent",
    local_name: "Agent",
    owner_id: nil,
    vocabulary_id: 4,
    glam_type: "Library"
  },
  %{
    information: "A project (a collective endeavour of some kind).",
    label: "Project",
    local_name: "Project",
    owner_id: nil,
    vocabulary_id: 4,
    glam_type: "Archive"
  },
  %{
    information: "An image.",
    label: "Image",
    local_name: "Image",
    owner_id: nil,
    vocabulary_id: 4,
    glam_type: "Gallery"
  },
  %{
    information: "A personal profile RDF document.",
    label: "PersonalProfileDocument",
    local_name: "PersonalProfileDocument",
    owner_id: nil,
    vocabulary_id: 4,
    glam_type: "Archive"
  },
  %{
    information: "An online account.",
    label: "Online Account",
    local_name: "OnlineAccount",
    owner_id: nil,
    vocabulary_id: 4,
    glam_type: "Archive"
  },
  %{
    information: "An online gaming account.",
    label: "Online Gaming Account",
    local_name: "OnlineGamingAccount",
    owner_id: nil,
    vocabulary_id: 4,
    glam_type: "Archive"
  },
  %{
    information: "An online e-commerce account.",
    label: "Online E-commerce Account",
    local_name: "OnlineEcommerceAccount",
    owner_id: nil,
    vocabulary_id: 4,
    glam_type: "Archive"
  },
  %{
    information: "An online chat account.",
    label: "Online Chat Account",
    local_name: "OnlineChatAccount",
    owner_id: nil,
    vocabulary_id: 4,
    glam_type: "Archive"
  }
]

for resource <- resource_class do
  # Check if resource class already exists by local_name
  case Repo.get_by(ResourceClass, local_name: resource[:local_name]) do
    nil ->
      %ResourceClass{
        label: resource[:label],
        local_name: resource[:local_name],
        information: resource[:information],
        glam_type: resource[:glam_type],
        vocabulary_id:
          case resource[:vocabulary_id] do
            1 -> vocabulary_1.id
            2 -> vocabulary_2.id
            3 -> vocabulary_3.id
            4 -> vocabulary_4.id
            _ -> 1
          end
      }
      |> Repo.insert!()

    _existing ->
      # Resource class already exists, skip
      :ok
  end
end
