@EndUserText.label: 'File Stream - NF Automation'
define root abstract entity ZA_NF_FILE_STREAM
{
  @Semantics.largeObject.mimeType: 'MimeType'
  @Semantics.largeObject.fileName: 'FileName'
  @Semantics.largeObject.contentDispositionPreference: #INLINE
  @EndUserText.label: 'Selecione o arquivo XLSX'
  StreamProperty : abap.rawstring(0);

  @UI.hidden: true
  MimeType       : abap.char(128);

  @UI.hidden: true
  FileName       : abap.char(128);
}
