@AbapCatalog.viewEnhancementCategory: [ #NONE ]

@AccessControl.authorizationCheck: #NOT_REQUIRED

@EndUserText.label: 'Interface CDS View - NF Automation'

@Metadata.ignorePropagatedAnnotations: true

define root view entity ZI_NF_PROCESSING
  as select from zsnf_nf_t

{
  key uuid                  as Uuid,

      process_status        as ProcessStatus,
      supplier_invoice      as SupplierInvoice,
      fiscal_year           as FiscalYear,
      br_nota_fiscal        as BrNotaFiscal,
      error_message         as ErrorMessage,
      created_by            as CreatedBy,
      created_at            as CreatedAt,
      last_changed_by       as LastChangedBy,
      last_changed_at       as LastChangedAt,
      local_last_changed_at as LocalLastChangedAt,

      company_code          as CompanyCode,
      purchase_order        as PurchaseOrder,
      po_item               as PoItem,
      invoice_gross_amount  as InvoiceGrossAmount,
      item_amount           as ItemAmount,
      protocol_number       as ProtocolNumber,
      document_date         as DocumentDate,
      nf_access_key         as NfAccessKey,
      nf_category           as NfCategory,
      nf_number             as NfNumber,
      header_text           as HeaderText,
      payment_terms         as PaymentTerms,
      payment_block         as PaymentBlock,
      gl_account            as GlAccount,
      cost_center           as CostCenter,

      @Semantics.largeObject: { mimeType: 'XlsxFileMimetype',
                                fileName: 'XlsxFilename',
                                contentDispositionPreference: #ATTACHMENT,
                                acceptableMimeTypes: [ 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ] }
      xlsx_file_content     as XlsxFileContent,

      @Semantics.mimeType: true
      xlsx_file_mimetype    as XlsxFileMimetype,

      xlsx_filename         as XlsxFilename
}
