CLASS lhc_nf_upload DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    TYPES xlsx_lines_tt TYPE TABLE OF zsnf_xlsx_line_s WITH EMPTY KEY.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR NfUpload RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR NfUpload RESULT result.

    METHODS parse_xlsx FOR DETERMINE ON SAVE
      IMPORTING keys FOR NfUpload~parseXlsx.

    METHODS process_all_invoices FOR MODIFY
      IMPORTING keys FOR ACTION NfUpload~ProcessAllInvoices RESULT result.
ENDCLASS.


CLASS lhc_nf_upload IMPLEMENTATION.

  METHOD get_global_authorizations.
    result = VALUE #( %create                    = if_abap_behv=>auth-allowed
                      %delete                    = if_abap_behv=>auth-allowed
                      %update                    = if_abap_behv=>auth-allowed
                      %action-ProcessAllInvoices = if_abap_behv=>auth-allowed ).
  ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF zi_nf_upload IN LOCAL MODE
      ENTITY NfUpload
        FIELDS ( UploadStatus XlsxFilename )
        WITH CORRESPONDING #( keys )
      RESULT DATA(uploads)
      FAILED failed
      REPORTED reported.

    result = VALUE #( FOR upload IN uploads (
      %tky = upload-%tky

      %action-ProcessAllInvoices = COND #(
        WHEN upload-UploadStatus = 'P'
         AND upload-%is_draft    = if_abap_behv=>mk-off
        THEN if_abap_behv=>fc-o-enabled
        ELSE if_abap_behv=>fc-o-disabled ) ) ).
  ENDMETHOD.

  METHOD parse_xlsx.
    READ ENTITIES OF zi_nf_upload IN LOCAL MODE
      ENTITY NfUpload
        FIELDS ( XlsxFileContent XlsxFilename )
        WITH CORRESPONDING #( keys )
      RESULT DATA(uploads)
      FAILED failed
      REPORTED reported.

    DELETE uploads WHERE XlsxFileContent IS INITIAL.
    CHECK uploads IS NOT INITIAL.

    DATA(lo_reader) = NEW zcl_nf_xlsx_reader( ).

    LOOP AT uploads ASSIGNING FIELD-SYMBOL(<upload>).
      TRY.
          DATA(xlsx_lines) = lo_reader->read_xlsx( <upload>-XlsxFileContent ).

          DELETE xlsx_lines WHERE company_code   IS INITIAL
                               AND purchase_order IS INITIAL
                               AND nf_number      IS INITIAL.

          IF xlsx_lines IS INITIAL.
            MODIFY ENTITIES OF zi_nf_upload IN LOCAL MODE
              ENTITY NfUpload
                UPDATE FIELDS ( UploadStatus ResultMessage )
                WITH VALUE #( ( %tky          = <upload>-%tky
                                UploadStatus  = 'E'
                                ResultMessage = 'Arquivo sem dados validos.' ) )
              REPORTED DATA(lc_reported1).
            CONTINUE.
          ENDIF.

          MODIFY ENTITIES OF zi_nf_upload IN LOCAL MODE
            ENTITY NfUpload
              CREATE BY \_NfLines
              FIELDS ( CompanyCode        PurchaseOrder
                       PoItem             DocumentDate   NfNumber
                       NfCategory         NfAccessKey    InvoiceGrossAmount
                       ItemAmount         ProtocolNumber HeaderText
                       PaymentTerms       PaymentBlock   GlAccount
                       CostCenter         ProcessStatus )
              WITH VALUE #( FOR line IN xlsx_lines INDEX INTO i
                ( %tky                 = <upload>-%tky
                  %target = VALUE #( (
                    %cid               = |XLSX_{ sy-tabix }_{ i }|
                    %is_draft          = if_abap_behv=>mk-off
                    CompanyCode        = line-company_code
                    PurchaseOrder      = line-purchase_order
                    PoItem             = line-po_item
                    DocumentDate       = line-document_date
                    NfNumber           = line-nf_number
                    NfCategory         = line-nf_category
                    NfAccessKey        = line-nf_access_key
                    InvoiceGrossAmount = line-invoice_gross_amount
                    ItemAmount         = line-item_amount
                    ProtocolNumber     = line-protocol_number
                    HeaderText         = line-header_text
                    PaymentTerms       = line-payment_terms
                    PaymentBlock       = line-payment_block
                    GlAccount          = line-gl_account
                    CostCenter         = line-cost_center
                    ProcessStatus      = 'N' ) ) ) )
            MAPPED DATA(lc_mapped)
            FAILED DATA(lc_failed)
            REPORTED DATA(lc_reported2).

          DATA(created)  = lines( xlsx_lines ).
          DATA(rejected) = lines( lc_failed-nfline ).

          MODIFY ENTITIES OF zi_nf_upload IN LOCAL MODE
            ENTITY NfUpload
              UPDATE FIELDS ( UploadStatus ResultMessage )
              WITH VALUE #( ( %tky          = <upload>-%tky
                              UploadStatus  = 'P'
                              ResultMessage = |{ created - rejected } NF(s) importada(s). { rejected } com erro.| ) )
            REPORTED DATA(lc_reported3).

        CATCH cx_root INTO DATA(ex).
          MODIFY ENTITIES OF zi_nf_upload IN LOCAL MODE
            ENTITY NfUpload
              UPDATE FIELDS ( UploadStatus ResultMessage )
              WITH VALUE #( ( %tky          = <upload>-%tky
                              UploadStatus  = 'E'
                              ResultMessage = |Erro ao processar XLSX: { ex->get_text( ) }| ) )
            REPORTED DATA(lc_reported4).
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

  METHOD process_all_invoices.
    READ ENTITIES OF zi_nf_upload IN LOCAL MODE
      ENTITY NfUpload
        ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(uploads)
      FAILED failed
      REPORTED reported.

    DELETE uploads WHERE UploadStatus <> 'P'.
    CHECK uploads IS NOT INITIAL.

    DATA(lo_processor) = NEW zcl_nf_invoice_processor( ).

    LOOP AT uploads ASSIGNING FIELD-SYMBOL(<upload>).

      READ ENTITIES OF zi_nf_upload IN LOCAL MODE
        ENTITY NfUpload BY \_NfLines
          ALL FIELDS
          WITH VALUE #( ( %tky = <upload>-%tky ) )
        RESULT DATA(nf_lines)
        FAILED DATA(lc_failed_read)
        REPORTED DATA(lc_reported_read).

      DELETE nf_lines WHERE ProcessStatus <> 'N'.

      IF nf_lines IS INITIAL.
        INSERT VALUE #(
          %tky = <upload>-%tky
          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-warning
                                        text     = 'Nenhuma NF pendente para processar.' )
        ) INTO TABLE reported-nfupload.
        CONTINUE.
      ENDIF.

      DATA lv_success TYPE i.
      DATA lv_errors  TYPE i.
      CLEAR: lv_success, lv_errors.

      LOOP AT nf_lines ASSIGNING FIELD-SYMBOL(<nf>).
        DATA(ls_line) = VALUE zsnf_xlsx_line_s(
          company_code        = <nf>-CompanyCode
          purchase_order      = <nf>-PurchaseOrder
          po_item             = <nf>-PoItem
          document_date       = <nf>-DocumentDate
          nf_number           = <nf>-NfNumber
          nf_category         = <nf>-NfCategory
          nf_access_key       = <nf>-NfAccessKey
          invoice_gross_amount = <nf>-InvoiceGrossAmount
          item_amount         = <nf>-ItemAmount
          protocol_number     = <nf>-ProtocolNumber
          header_text         = <nf>-HeaderText
          payment_terms       = <nf>-PaymentTerms
          payment_block       = <nf>-PaymentBlock
          gl_account          = <nf>-GlAccount
          cost_center         = <nf>-CostCenter
        ).

        DATA(ls_result) = lo_processor->process_invoice( ls_line ).

        IF ls_result-success = abap_true.
          lv_success = lv_success + 1.
          MODIFY ENTITIES OF zi_nf_upload IN LOCAL MODE
            ENTITY NfLine
              UPDATE FIELDS ( ProcessStatus SupplierInvoice FiscalYear BrNotaFiscal ErrorMessage )
              WITH VALUE #( ( %tky            = <nf>-%tky
                              ProcessStatus   = 'S'
                              SupplierInvoice = ls_result-supplier_invoice
                              FiscalYear      = ls_result-fiscal_year
                              BrNotaFiscal    = ls_result-br_nota_fiscal
                              ErrorMessage    = '' ) )
            REPORTED DATA(lc_reported_upd1).
        ELSE.
          lv_errors = lv_errors + 1.
          MODIFY ENTITIES OF zi_nf_upload IN LOCAL MODE
            ENTITY NfLine
              UPDATE FIELDS ( ProcessStatus ErrorMessage )
              WITH VALUE #( ( %tky          = <nf>-%tky
                              ProcessStatus = 'E'
                              ErrorMessage  = ls_result-error_message ) )
            REPORTED DATA(lc_reported_upd2).
        ENDIF.
      ENDLOOP.

      MODIFY ENTITIES OF zi_nf_upload IN LOCAL MODE
        ENTITY NfUpload
          UPDATE FIELDS ( UploadStatus ResultMessage )
          WITH VALUE #( ( %tky          = <upload>-%tky
                          UploadStatus  = 'C'
                          ResultMessage = |{ lv_success } processada(s) com sucesso. { lv_errors } com erro.| ) )
        REPORTED DATA(lc_reported_final).

      INSERT VALUE #(
        %tky = <upload>-%tky
        %msg = new_message_with_text(
          severity = COND #( WHEN lv_errors > 0
                             THEN if_abap_behv_message=>severity-warning
                             ELSE if_abap_behv_message=>severity-success )
          text     = |{ lv_success } processada(s). { lv_errors } com erro.| )
      ) INTO TABLE reported-nfupload.

    ENDLOOP.

    READ ENTITIES OF zi_nf_upload IN LOCAL MODE
      ENTITY NfUpload ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(updated).

    result = VALUE #( FOR u IN updated ( %tky = u-%tky %param = u ) ).
  ENDMETHOD.

ENDCLASS.


CLASS lhc_nf_line DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR NfLine RESULT result.

    METHODS process_invoice FOR MODIFY
      IMPORTING keys FOR ACTION NfLine~ProcessInvoice RESULT result.
ENDCLASS.


CLASS lhc_nf_line IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF zi_nf_upload IN LOCAL MODE
      ENTITY NfLine
        FIELDS ( ProcessStatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(nfs)
      FAILED failed
      REPORTED reported.

    result = VALUE #( FOR nf IN nfs (
      %tky = nf-%tky

      %action-ProcessInvoice = COND #(
        WHEN nf-ProcessStatus = 'N'
         AND nf-%is_draft     = if_abap_behv=>mk-off
        THEN if_abap_behv=>fc-o-enabled
        ELSE if_abap_behv=>fc-o-disabled ) ) ).
  ENDMETHOD.

  METHOD process_invoice.
    READ ENTITIES OF zi_nf_upload IN LOCAL MODE
      ENTITY NfLine
        ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(nfs)
      FAILED failed
      REPORTED reported.

    DELETE nfs WHERE ProcessStatus <> 'N'.
    CHECK nfs IS NOT INITIAL.

    DATA(lo_processor) = NEW zcl_nf_invoice_processor( ).

    LOOP AT nfs ASSIGNING FIELD-SYMBOL(<nf>).
      DATA(ls_line) = VALUE zsnf_xlsx_line_s(
        company_code        = <nf>-CompanyCode
        purchase_order      = <nf>-PurchaseOrder
        po_item             = <nf>-PoItem
        document_date       = <nf>-DocumentDate
        nf_number           = <nf>-NfNumber
        nf_category         = <nf>-NfCategory
        nf_access_key       = <nf>-NfAccessKey
        invoice_gross_amount = <nf>-InvoiceGrossAmount
        item_amount         = <nf>-ItemAmount
        protocol_number     = <nf>-ProtocolNumber
        header_text         = <nf>-HeaderText
        payment_terms       = <nf>-PaymentTerms
        payment_block       = <nf>-PaymentBlock
        gl_account          = <nf>-GlAccount
        cost_center         = <nf>-CostCenter
      ).

      DATA(ls_result) = lo_processor->process_invoice( ls_line ).

      IF ls_result-success = abap_true.
        MODIFY ENTITIES OF zi_nf_upload IN LOCAL MODE
          ENTITY NfLine
            UPDATE FIELDS ( ProcessStatus SupplierInvoice FiscalYear BrNotaFiscal ErrorMessage )
            WITH VALUE #( ( %tky            = <nf>-%tky
                            ProcessStatus   = 'S'
                            SupplierInvoice = ls_result-supplier_invoice
                            FiscalYear      = ls_result-fiscal_year
                            BrNotaFiscal    = ls_result-br_nota_fiscal
                            ErrorMessage    = '' ) )
          REPORTED DATA(lc_reported1).
      ELSE.
        MODIFY ENTITIES OF zi_nf_upload IN LOCAL MODE
          ENTITY NfLine
            UPDATE FIELDS ( ProcessStatus ErrorMessage )
            WITH VALUE #( ( %tky          = <nf>-%tky
                            ProcessStatus = 'E'
                            ErrorMessage  = ls_result-error_message ) )
          REPORTED DATA(lc_reported2).
      ENDIF.

      INSERT VALUE #(
        %tky = <nf>-%tky
        %msg = new_message_with_text(
          severity = COND #( WHEN ls_result-success = abap_true
                             THEN if_abap_behv_message=>severity-success
                             ELSE if_abap_behv_message=>severity-error )
          text     = COND #( WHEN ls_result-success = abap_true
                             THEN |NF { <nf>-NfNumber } processada: { ls_result-supplier_invoice }|
                             ELSE |Erro NF { <nf>-NfNumber }: { ls_result-error_message }| ) )
      ) INTO TABLE reported-nfline.
    ENDLOOP.

    READ ENTITIES OF zi_nf_upload IN LOCAL MODE
      ENTITY NfLine ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(updated).

    result = VALUE #( FOR nf IN updated ( %tky = nf-%tky %param = nf ) ).
  ENDMETHOD.

ENDCLASS.
