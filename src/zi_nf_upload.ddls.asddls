 @AbapCatalog.viewEnhancementCategory: [#NONE]                                                                                                   
  @EndUserText.label: 'Interface CDS - Upload NF'                                                                                                 
  @Metadata.ignorePropagatedAnnotations: true
  define root view entity ZI_NF_UPLOAD                                                                                                            
    as select from zsnf_upload_t                                                                                                                  
  {
    key uuid                  as Uuid,                                                                                                            
        upload_status         as UploadStatus,
        result_message        as ResultMessage,
                                                                                                                                                  
        @Semantics.largeObject: {
          mimeType: 'XlsxFileMimetype',                                                                                                           
          fileName: 'XlsxFilename',
          contentDispositionPreference: #ATTACHMENT,
          acceptableMimeTypes: [ 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ]                                            
        }
        xlsx_file_content     as XlsxFileContent,                                                                                                 
                  
        @Semantics.mimeType: true                                                                                                                 
        xlsx_file_mimetype    as XlsxFileMimetype,

        xlsx_filename         as XlsxFilename,                                                                                                    
        created_by            as CreatedBy,
        created_at            as CreatedAt,                                                                                                       
        last_changed_by       as LastChangedBy,
        last_changed_at       as LastChangedAt,
        local_last_changed_at as LocalLastChangedAt                                                                                               
  }
