@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption CDS - Upload NF'
@Metadata.ignorePropagatedAnnotations: false
@Metadata.allowExtensions: true
@UI.createHidden: false

@UI.headerInfo: {
  typeName: 'Upload NF',
  typeNamePlural: 'Uploads NF',
  title: { type: #STANDARD, value: 'XlsxFilename' },
  description: { type: #STANDARD, value: 'UploadStatus' }
}

define root view entity ZC_NF_UPLOAD
  provider contract transactional_query
  as projection on ZI_NF_UPLOAD
{
  @UI.facet: [{ id: 'General', type: #IDENTIFICATION_REFERENCE,
                label: 'Upload', position: 10 },
              { id: 'NfLines', type: #LINEITEM_REFERENCE,
                label: 'Notas Fiscais', position: 20,
                targetElement: '_NfLines' }]

  @UI.lineItem: [
    { position: 10, label: 'UUID' },
    { type: #FOR_ACTION, dataAction: 'ProcessAllInvoices',
      label: 'Processar NFs', position: 10 }
  ]
  @UI.identification: [{ position: 10, label: 'UUID' }]
  key Uuid,

  @UI.lineItem: [{ position: 20, label: 'Status' }]
  @UI.identification: [{ position: 20, label: 'Status' }]
  UploadStatus,

  @UI.lineItem: [{ position: 30, label: 'Resultado' }]
  @UI.identification: [{ position: 30, label: 'Resultado' }]
  ResultMessage,

  @UI.identification: [{ position: 40, label: 'Arquivo XLSX' }]
  XlsxFileContent,

  @UI.hidden: true
  XlsxFileMimetype,

  @UI.lineItem: [{ position: 50, label: 'Nome do Arquivo' }]
  @UI.identification: [{ position: 50, label: 'Nome do Arquivo' }]
  XlsxFilename,

  @UI.hidden: true
  CreatedBy,
  @UI.hidden: true
  CreatedAt,
  @UI.hidden: true
  LastChangedBy,
  @UI.hidden: true
  LastChangedAt,
  @UI.hidden: true
  LocalLastChangedAt,

  /* Composition */
  _NfLines : redirected to composition child ZC_NF_PROCESSING
}
