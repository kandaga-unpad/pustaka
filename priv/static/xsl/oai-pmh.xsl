<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:oai="http://www.openarchives.org/OAI/2.0/"
    xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    exclude-result-prefixes="oai oai_dc dc">

  <xsl:output method="html" encoding="UTF-8" indent="yes"/>

  <xsl:template match="/">
    <html>
      <head>
        <title>OAI-PMH Response</title>
        <link rel="stylesheet" href="/css/oai-pmh.css" type="text/css"/>
        <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
      </head>
      <body>
        <div class="container">
          <header class="page-header">
            <h1>OAI-PMH 2.0 Repository</h1>
            <p class="subtitle">Open Archives Initiative Protocol for Metadata Harvesting</p>
          </header>

          <xsl:apply-templates select="oai:OAI-PMH"/>
        </div>
      </body>
    </html>
  </xsl:template>

  <!-- Main OAI-PMH wrapper -->
  <xsl:template match="oai:OAI-PMH">
    <div class="oai-response">
      <!-- Response Date -->
      <div class="response-info">
        <div class="info-row">
          <span class="label">Response Date:</span>
          <span class="value"><xsl:value-of select="oai:responseDate"/></span>
        </div>
      </div>

      <!-- Request Information -->
      <xsl:apply-templates select="oai:request"/>

      <!-- Error handling -->
      <xsl:apply-templates select="oai:error"/>

      <!-- Different verb responses -->
      <xsl:apply-templates select="oai:Identify"/>
      <xsl:apply-templates select="oai:ListMetadataFormats"/>
      <xsl:apply-templates select="oai:ListSets"/>
      <xsl:apply-templates select="oai:ListIdentifiers"/>
      <xsl:apply-templates select="oai:ListRecords"/>
      <xsl:apply-templates select="oai:GetRecord"/>
    </div>
  </xsl:template>

  <!-- Request element -->
  <xsl:template match="oai:request">
    <div class="request-info">
      <h2>Request</h2>
      <div class="info-card">
        <div class="info-row">
          <span class="label">Base URL:</span>
          <span class="value url"><xsl:value-of select="."/></span>
        </div>
        <xsl:if test="@verb">
          <div class="info-row">
            <span class="label">Verb:</span>
            <span class="value verb"><xsl:value-of select="@verb"/></span>
          </div>
        </xsl:if>
        <xsl:if test="@metadataPrefix">
          <div class="info-row">
            <span class="label">Metadata Prefix:</span>
            <span class="value"><xsl:value-of select="@metadataPrefix"/></span>
          </div>
        </xsl:if>
        <xsl:if test="@identifier">
          <div class="info-row">
            <span class="label">Identifier:</span>
            <span class="value"><xsl:value-of select="@identifier"/></span>
          </div>
        </xsl:if>
        <xsl:if test="@from">
          <div class="info-row">
            <span class="label">From:</span>
            <span class="value"><xsl:value-of select="@from"/></span>
          </div>
        </xsl:if>
        <xsl:if test="@until">
          <div class="info-row">
            <span class="label">Until:</span>
            <span class="value"><xsl:value-of select="@until"/></span>
          </div>
        </xsl:if>
        <xsl:if test="@set">
          <div class="info-row">
            <span class="label">Set:</span>
            <span class="value"><xsl:value-of select="@set"/></span>
          </div>
        </xsl:if>
        <xsl:if test="@resumptionToken">
          <div class="info-row">
            <span class="label">Resumption Token:</span>
            <span class="value token"><xsl:value-of select="@resumptionToken"/></span>
          </div>
        </xsl:if>
      </div>
    </div>
  </xsl:template>

  <!-- Error -->
  <xsl:template match="oai:error">
    <div class="error-message">
      <h2>Error</h2>
      <div class="error-card">
        <div class="error-code"><xsl:value-of select="@code"/></div>
        <div class="error-text"><xsl:value-of select="."/></div>
      </div>
    </div>
  </xsl:template>

  <!-- Identify -->
  <xsl:template match="oai:Identify">
    <div class="identify">
      <h2>Repository Information</h2>
      <div class="info-card">
        <div class="info-row">
          <span class="label">Repository Name:</span>
          <span class="value"><xsl:value-of select="oai:repositoryName"/></span>
        </div>
        <div class="info-row">
          <span class="label">Base URL:</span>
          <span class="value url"><xsl:value-of select="oai:baseURL"/></span>
        </div>
        <div class="info-row">
          <span class="label">Protocol Version:</span>
          <span class="value"><xsl:value-of select="oai:protocolVersion"/></span>
        </div>
        <div class="info-row">
          <span class="label">Earliest Datestamp:</span>
          <span class="value"><xsl:value-of select="oai:earliestDatestamp"/></span>
        </div>
        <div class="info-row">
          <span class="label">Deleted Record:</span>
          <span class="value"><xsl:value-of select="oai:deletedRecord"/></span>
        </div>
        <div class="info-row">
          <span class="label">Granularity:</span>
          <span class="value"><xsl:value-of select="oai:granularity"/></span>
        </div>
        <xsl:for-each select="oai:adminEmail">
          <div class="info-row">
            <span class="label">Admin Email:</span>
            <span class="value"><xsl:value-of select="."/></span>
          </div>
        </xsl:for-each>
        <xsl:if test="oai:compression">
          <div class="info-row">
            <span class="label">Compression:</span>
            <span class="value"><xsl:value-of select="oai:compression"/></span>
          </div>
        </xsl:if>
      </div>
    </div>
  </xsl:template>

  <!-- ListMetadataFormats -->
  <xsl:template match="oai:ListMetadataFormats">
    <div class="metadata-formats">
      <h2>Available Metadata Formats</h2>
      <div class="format-list">
        <xsl:for-each select="oai:metadataFormat">
          <div class="format-card">
            <h3><xsl:value-of select="oai:metadataPrefix"/></h3>
            <div class="info-row">
              <span class="label">Schema:</span>
              <span class="value url"><xsl:value-of select="oai:schema"/></span>
            </div>
            <div class="info-row">
              <span class="label">Namespace:</span>
              <span class="value url"><xsl:value-of select="oai:metadataNamespace"/></span>
            </div>
          </div>
        </xsl:for-each>
      </div>
    </div>
  </xsl:template>

  <!-- ListSets -->
  <xsl:template match="oai:ListSets">
    <div class="sets">
      <h2>Available Sets</h2>
      <div class="set-list">
        <xsl:for-each select="oai:set">
          <div class="set-card">
            <h3><xsl:value-of select="oai:setName"/></h3>
            <div class="info-row">
              <span class="label">Set Spec:</span>
              <span class="value"><xsl:value-of select="oai:setSpec"/></span>
            </div>
            <xsl:if test="oai:setDescription">
              <div class="info-row">
                <span class="label">Description:</span>
                <span class="value"><xsl:value-of select="oai:setDescription"/></span>
              </div>
            </xsl:if>
          </div>
        </xsl:for-each>
      </div>
      <xsl:apply-templates select="oai:resumptionToken"/>
    </div>
  </xsl:template>

  <!-- ListIdentifiers -->
  <xsl:template match="oai:ListIdentifiers">
    <div class="identifiers">
      <h2>Record Identifiers</h2>
      <div class="record-count">
        <xsl:value-of select="count(oai:header)"/> record(s) in this response
      </div>
      <div class="identifier-list">
        <xsl:for-each select="oai:header">
          <div class="identifier-card">
            <xsl:if test="@status='deleted'">
              <xsl:attribute name="class">identifier-card deleted</xsl:attribute>
            </xsl:if>
            <div class="identifier-value">
              <xsl:value-of select="oai:identifier"/>
            </div>
            <div class="metadata-row">
              <span class="label">Datestamp:</span>
              <span class="value"><xsl:value-of select="oai:datestamp"/></span>
            </div>
            <xsl:for-each select="oai:setSpec">
              <div class="metadata-row">
                <span class="label">Set:</span>
                <span class="value"><xsl:value-of select="."/></span>
              </div>
            </xsl:for-each>
            <xsl:if test="@status">
              <div class="status-badge"><xsl:value-of select="@status"/></div>
            </xsl:if>
          </div>
        </xsl:for-each>
      </div>
      <xsl:apply-templates select="oai:resumptionToken"/>
    </div>
  </xsl:template>

  <!-- ListRecords -->
  <xsl:template match="oai:ListRecords">
    <div class="records">
      <h2>Records</h2>
      <div class="record-count">
        <xsl:value-of select="count(oai:record)"/> record(s) in this response
      </div>
      <div class="record-list">
        <xsl:for-each select="oai:record">
          <div class="record-card">
            <xsl:apply-templates select="oai:header"/>
            <xsl:apply-templates select="oai:metadata"/>
          </div>
        </xsl:for-each>
      </div>
      <xsl:apply-templates select="oai:resumptionToken"/>
    </div>
  </xsl:template>

  <!-- GetRecord -->
  <xsl:template match="oai:GetRecord">
    <div class="record">
      <h2>Record</h2>
      <div class="record-card">
        <xsl:apply-templates select="oai:record/oai:header"/>
        <xsl:apply-templates select="oai:record/oai:metadata"/>
      </div>
    </div>
  </xsl:template>

  <!-- Header -->
  <xsl:template match="oai:header">
    <div class="record-header">
      <xsl:if test="@status='deleted'">
        <div class="status-badge deleted">DELETED</div>
      </xsl:if>
      <div class="header-row">
        <span class="label">Identifier:</span>
        <span class="value identifier"><xsl:value-of select="oai:identifier"/></span>
      </div>
      <div class="header-row">
        <span class="label">Datestamp:</span>
        <span class="value"><xsl:value-of select="oai:datestamp"/></span>
      </div>
      <xsl:for-each select="oai:setSpec">
        <div class="header-row">
          <span class="label">Set:</span>
          <span class="value"><xsl:value-of select="."/></span>
        </div>
      </xsl:for-each>
    </div>
  </xsl:template>

  <!-- Metadata -->
  <xsl:template match="oai:metadata">
    <div class="record-metadata">
      <h3>Metadata</h3>
      <xsl:apply-templates select="oai_dc:dc"/>
    </div>
  </xsl:template>

  <!-- Dublin Core -->
  <xsl:template match="oai_dc:dc">
    <div class="dublin-core">
      <xsl:for-each select="dc:title">
        <div class="dc-field">
          <span class="dc-label">Title:</span>
          <span class="dc-value title"><xsl:value-of select="."/></span>
        </div>
      </xsl:for-each>
      <xsl:for-each select="dc:creator">
        <div class="dc-field">
          <span class="dc-label">Creator:</span>
          <span class="dc-value"><xsl:value-of select="."/></span>
        </div>
      </xsl:for-each>
      <xsl:for-each select="dc:subject">
        <div class="dc-field">
          <span class="dc-label">Subject:</span>
          <span class="dc-value"><xsl:value-of select="."/></span>
        </div>
      </xsl:for-each>
      <xsl:for-each select="dc:description">
        <div class="dc-field">
          <span class="dc-label">Description:</span>
          <span class="dc-value description"><xsl:value-of select="."/></span>
        </div>
      </xsl:for-each>
      <xsl:for-each select="dc:publisher">
        <div class="dc-field">
          <span class="dc-label">Publisher:</span>
          <span class="dc-value"><xsl:value-of select="."/></span>
        </div>
      </xsl:for-each>
      <xsl:for-each select="dc:contributor">
        <div class="dc-field">
          <span class="dc-label">Contributor:</span>
          <span class="dc-value"><xsl:value-of select="."/></span>
        </div>
      </xsl:for-each>
      <xsl:for-each select="dc:date">
        <div class="dc-field">
          <span class="dc-label">Date:</span>
          <span class="dc-value"><xsl:value-of select="."/></span>
        </div>
      </xsl:for-each>
      <xsl:for-each select="dc:type">
        <div class="dc-field">
          <span class="dc-label">Type:</span>
          <span class="dc-value"><xsl:value-of select="."/></span>
        </div>
      </xsl:for-each>
      <xsl:for-each select="dc:format">
        <div class="dc-field">
          <span class="dc-label">Format:</span>
          <span class="dc-value"><xsl:value-of select="."/></span>
        </div>
      </xsl:for-each>
      <xsl:for-each select="dc:identifier">
        <div class="dc-field">
          <span class="dc-label">Identifier:</span>
          <span class="dc-value url"><xsl:value-of select="."/></span>
        </div>
      </xsl:for-each>
      <xsl:for-each select="dc:source">
        <div class="dc-field">
          <span class="dc-label">Source:</span>
          <span class="dc-value"><xsl:value-of select="."/></span>
        </div>
      </xsl:for-each>
      <xsl:for-each select="dc:language">
        <div class="dc-field">
          <span class="dc-label">Language:</span>
          <span class="dc-value"><xsl:value-of select="."/></span>
        </div>
      </xsl:for-each>
      <xsl:for-each select="dc:relation">
        <div class="dc-field">
          <span class="dc-label">Relation:</span>
          <span class="dc-value"><xsl:value-of select="."/></span>
        </div>
      </xsl:for-each>
      <xsl:for-each select="dc:coverage">
        <div class="dc-field">
          <span class="dc-label">Coverage:</span>
          <span class="dc-value"><xsl:value-of select="."/></span>
        </div>
      </xsl:for-each>
      <xsl:for-each select="dc:rights">
        <div class="dc-field">
          <span class="dc-label">Rights:</span>
          <span class="dc-value"><xsl:value-of select="."/></span>
        </div>
      </xsl:for-each>
    </div>
  </xsl:template>

  <!-- Resumption Token -->
  <xsl:template match="oai:resumptionToken">
    <div class="resumption-token">
      <h3>Resumption Token</h3>
      <div class="token-card">
        <xsl:if test=".!=''">
          <div class="token-value">
            <span class="label">Token:</span>
            <span class="value token"><xsl:value-of select="."/></span>
          </div>
        </xsl:if>
        <xsl:if test="@completeListSize">
          <div class="token-info">
            <span class="label">Total Records:</span>
            <span class="value"><xsl:value-of select="@completeListSize"/></span>
          </div>
        </xsl:if>
        <xsl:if test="@cursor">
          <div class="token-info">
            <span class="label">Current Position:</span>
            <span class="value"><xsl:value-of select="@cursor"/></span>
          </div>
        </xsl:if>
        <xsl:if test="@expirationDate">
          <div class="token-info">
            <span class="label">Expires:</span>
            <span class="value"><xsl:value-of select="@expirationDate"/></span>
          </div>
        </xsl:if>
        <xsl:if test=".=''">
          <div class="token-info">
            <em>No more records available (end of list)</em>
          </div>
        </xsl:if>
      </div>
    </div>
  </xsl:template>

</xsl:stylesheet>
