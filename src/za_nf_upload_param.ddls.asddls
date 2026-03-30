 @EndUserText.label: 'Upload Param - NF Automation'
  define root abstract entity ZA_NF_UPLOAD_PARAM

{
  @EndUserText.label: 'Arquivo XLSX'
  @Semantics.largeObject: { mimeType: 'MimeType',
                            fileName: 'FileName',
                            contentDispositionPreference: #ATTACHMENT,
                            acceptableMimeTypes: [ 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ] }
  FileContent : abap.rawstring(0);

  @Semantics.mimeType: true
  @UI.hidden: true
  MimeType    : abap.char(128);

  @EndUserText.label: 'Nome do Arquivo'
  FileName    : abap.char(255);
}
