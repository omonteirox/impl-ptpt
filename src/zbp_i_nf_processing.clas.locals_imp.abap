CLASS lhc_zi_nf_processing DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    TYPES xlsx_lines_tt TYPE TABLE OF zsnf_xlsx_line_s WITH EMPTY KEY.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR NfProcessing RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR NfProcessing RESULT result.

    METHODS process_invoices FOR MODIFY
      IMPORTING keys FOR ACTION NfProcessing~ProcessInvoices RESULT result.

    METHODS set_initial_status FOR DETERMINE ON MODIFY
      IMPORTING keys FOR NfProcessing~setInitialStatus.

    METHODS parse_xlsx
      IMPORTING file_content      TYPE xstring
      RETURNING VALUE(xlsx_lines) TYPE xlsx_lines_tt
      RAISING   cx_static_check.
ENDCLASS.


CLASS lhc_zi_nf_processing IMPLEMENTATION.

  METHOD get_global_authorizations.
    result = VALUE #( %create                 = if_abap_behv=>auth-allowed
                      %delete                 = if_abap_behv=>auth-allowed
                      %update                 = if_abap_behv=>auth-allowed
                      %action-ProcessInvoices = if_abap_behv=>auth-allowed ).
  ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF zi_nf_processing IN LOCAL MODE
      ENTITY NfProcessing
        FIELDS ( ProcessStatus XlsxFilename )
        WITH CORRESPONDING #( keys )
      RESULT DATA(nfs)
      FAILED failed
      REPORTED reported.

    result = VALUE #( FOR nf IN nfs (
      %tky = nf-%tky

      %field-XlsxFileContent  = COND #(
        WHEN nf-ProcessStatus IS INITIAL OR nf-ProcessStatus = 'N'
        THEN if_abap_behv=>fc-f-unrestricted
        ELSE if_abap_behv=>fc-f-read_only )

      %action-ProcessInvoices = COND #(
        WHEN nf-XlsxFilename IS NOT INITIAL
         AND nf-ProcessStatus = 'N'
         AND nf-%is_draft     = if_abap_behv=>mk-off
        THEN if_abap_behv=>fc-o-enabled
        ELSE if_abap_behv=>fc-o-disabled ) ) ).
  ENDMETHOD.

METHOD set_initial_status.
    READ ENTITIES OF zi_nf_processing IN LOCAL MODE
      ENTITY NfProcessing
        FIELDS ( ProcessStatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(nfs)
      FAILED DATA(lc_failed)
      REPORTED DATA(lc_reported).

    DELETE nfs WHERE ProcessStatus IS NOT INITIAL.
    CHECK nfs IS NOT INITIAL.

    MODIFY ENTITIES OF zi_nf_processing IN LOCAL MODE
      ENTITY NfProcessing
        UPDATE FIELDS ( ProcessStatus )
        WITH VALUE #( FOR nf IN nfs
          ( %tky          = nf-%tky
            ProcessStatus = 'N' ) )
      FAILED DATA(lc_failed2)
      REPORTED DATA(lc_reported2).
ENDMETHOD.

  METHOD process_invoices.
    READ ENTITIES OF zi_nf_processing IN LOCAL MODE
      ENTITY NfProcessing
        FIELDS ( ProcessStatus XlsxFileContent XlsxFilename )
        WITH CORRESPONDING #( keys )
      RESULT DATA(nfs)
      FAILED failed
      REPORTED reported.

    DELETE nfs WHERE ProcessStatus <> 'N' OR XlsxFileContent IS INITIAL.
    CHECK nfs IS NOT INITIAL.

    DATA lc_mapped   TYPE RESPONSE FOR MAPPED   EARLY zi_nf_processing.
    DATA lc_failed   TYPE RESPONSE FOR FAILED   EARLY zi_nf_processing.
    DATA lc_reported TYPE RESPONSE FOR REPORTED EARLY zi_nf_processing.

    LOOP AT nfs ASSIGNING FIELD-SYMBOL(<nf>).
      TRY.
          DATA(xlsx_lines) = parse_xlsx( <nf>-XlsxFileContent ).

          DELETE xlsx_lines WHERE company_code   IS INITIAL
                               AND purchase_order IS INITIAL
                               AND nf_number      IS INITIAL.

          IF xlsx_lines IS INITIAL.
            INSERT VALUE #(
              %tky = <nf>-%tky
              %msg = new_message_with_text( severity = if_abap_behv_message=>severity-warning
                                            text     = 'Arquivo sem dados válidos.' )
            ) INTO TABLE reported-nfprocessing.
            CONTINUE.
          ENDIF.

          CLEAR: lc_mapped, lc_failed, lc_reported.

          MODIFY ENTITIES OF zi_nf_processing IN LOCAL MODE
            ENTITY NfProcessing
              CREATE FIELDS (
                CompanyCode        PurchaseOrder
                PoItem             DocumentDate   NfNumber
                NfCategory         NfAccessKey    InvoiceGrossAmount
                ItemAmount         ProtocolNumber HeaderText
                PaymentTerms       PaymentBlock   GlAccount
                CostCenter )
              WITH VALUE #( FOR line IN xlsx_lines INDEX INTO i
                ( %cid               = |XLSX_{ <nf>-Uuid }_{ i }|
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
                  CostCenter         = line-cost_center ) )
            MAPPED   lc_mapped
            FAILED   lc_failed
            REPORTED lc_reported.

          APPEND LINES OF lc_reported-nfprocessing TO reported-nfprocessing.

          DATA(created)  = lines( xlsx_lines ).
          DATA(rejected) = lines( lc_failed-nfprocessing ).

          MODIFY ENTITIES OF zi_nf_processing IN LOCAL MODE
            ENTITY NfProcessing
              UPDATE FIELDS ( ProcessStatus )
              WITH VALUE #( ( %tky = <nf>-%tky ProcessStatus = 'P' ) ).

          INSERT VALUE #(
            %tky = <nf>-%tky
            %msg = new_message_with_text(
              severity = COND #( WHEN rejected > 0
                                 THEN if_abap_behv_message=>severity-warning
                                 ELSE if_abap_behv_message=>severity-success )
              text     = |{ created - rejected } NF(s) importada(s). { rejected } com erro.| )
          ) INTO TABLE reported-nfprocessing.

        CATCH cx_static_check INTO DATA(ex).
          INSERT VALUE #(
            %tky = <nf>-%tky
            %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                          text     = |Erro: { ex->get_text( ) }| )
          ) INTO TABLE reported-nfprocessing.
      ENDTRY.
    ENDLOOP.

    READ ENTITIES OF zi_nf_processing IN LOCAL MODE
      ENTITY NfProcessing ALL FIELDS
        WITH CORRESPONDING #( keys )
      RESULT DATA(updated).

    result = VALUE #( FOR nf IN updated ( %tky = nf-%tky %param = nf ) ).
  ENDMETHOD.

METHOD parse_xlsx.
  DATA(lo_reader) = NEW zcl_nf_xlsx_reader( ).
  xlsx_lines = lo_reader->read_xlsx( file_content ).
ENDMETHOD.

ENDCLASS.
