CLASS zcl_nf_invoice_processor DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

TYPES:
      BEGIN OF ty_result,
        success          TYPE abap_boolean,
        supplier_invoice TYPE belnr_d,
        fiscal_year      TYPE gjahr,
        br_nota_fiscal   TYPE belnr_d,
        error_message    TYPE symsgv,
      END OF ty_result.

    METHODS process_invoice
      IMPORTING
        is_line        TYPE zsnf_xlsx_line_s
      RETURNING
        VALUE(rs_result) TYPE ty_result.

  PRIVATE SECTION.

    METHODS build_payload_ya
      IMPORTING
        is_line          TYPE zsnf_xlsx_line_s
      RETURNING
        VALUE(rv_payload) TYPE string.

    METHODS build_payload_se
      IMPORTING
        is_line          TYPE zsnf_xlsx_line_s
      RETURNING
        VALUE(rv_payload) TYPE string.

    METHODS call_api
      IMPORTING
        iv_payload       TYPE string
      RETURNING
        VALUE(rs_result) TYPE ty_result.

    METHODS format_date
      IMPORTING
        iv_date          TYPE datum
      RETURNING
        VALUE(rv_date)   TYPE string.

    METHODS get_csrf_token
      IMPORTING
        io_client        TYPE REF TO if_web_http_client
      RETURNING
        VALUE(rv_token)  TYPE string.

ENDCLASS.



CLASS ZCL_NF_INVOICE_PROCESSOR IMPLEMENTATION.


  METHOD process_invoice.

    " Valida Ctg.NF
    IF is_line-nf_category = 'YA'.
      DATA(lv_payload) = build_payload_ya( is_line ).
    ELSEIF is_line-nf_category = 'SE'.
      lv_payload = build_payload_se( is_line ).
    ELSE.
      rs_result-success = abap_false.
      rs_result-error_message = |Ctg.NF inválida: { is_line-nf_category }. Use YA ou SE.|.
      RETURN.
    ENDIF.

    " Chama a API
    rs_result = call_api( lv_payload ).

  ENDMETHOD.


  METHOD build_payload_ya.

    DATA(lv_date) = format_date( is_line-document_date ).
    DATA(lv_amount) = |{ is_line-invoice_gross_amount DECIMALS = 2 }|.
    DATA(lv_item_amount) = |{ is_line-item_amount DECIMALS = 2 }|.

    rv_payload = |\{"CompanyCode":"{ is_line-company_code }",| &&
                 |"DocumentDate":"{ lv_date }",| &&
                 |"PostingDate":"{ lv_date }",| &&
                 |"DocumentCurrency":"BRL",| &&
                 |"InvoiceGrossAmount":"{ lv_amount }",| &&
                 |"SupplierInvoiceIDByInvcgParty":"{ is_line-nf_number }",| &&
                 |"DocumentHeaderText":"{ is_line-header_text }",| &&
                 |"PaymentTerms":"{ is_line-payment_terms }",| &&
                 |"SupplierInvoiceStatus":"A",| &&
                 |"TaxIsCalculatedAutomatically":true,| &&
                 |"to_SuplrInvcItemPurOrdRef":[\{| &&
                 |"SupplierInvoiceItem":"000001",| &&
                 |"PurchaseOrder":"{ is_line-purchase_order }",| &&
                 |"PurchaseOrderItem":"{ is_line-po_item }",| &&
                 |"DocumentCurrency":"BRL",| &&
                 |"SupplierInvoiceItemAmount":"{ lv_item_amount }",| &&
                 |"TaxCode":"00"| &&
                 |\}]\}|.

  ENDMETHOD.


  METHOD build_payload_se.

    DATA(lv_date) = format_date( is_line-document_date ).
    DATA(lv_amount) = |{ is_line-invoice_gross_amount DECIMALS = 2 }|.
    DATA(lv_item_amount) = |{ is_line-item_amount DECIMALS = 2 }|.

    rv_payload = |\{"CompanyCode":"{ is_line-company_code }",| &&
                 |"DocumentDate":"{ lv_date }",| &&
                 |"PostingDate":"{ lv_date }",| &&
                 |"DocumentCurrency":"BRL",| &&
                 |"InvoiceGrossAmount":"{ lv_amount }",| &&
                 |"SupplierInvoiceIDByInvcgParty":"{ is_line-nf_number }",| &&
                 |"DocumentHeaderText":"{ is_line-header_text }",| &&
                 |"PaymentTerms":"{ is_line-payment_terms }",| &&
                 |"SupplierInvoiceStatus":"A",| &&
                 |"TaxIsCalculatedAutomatically":true,| &&
                 |"to_SupplierInvoiceItemGLAcct":[\{| &&
                 |"SupplierInvoiceItem":"000001",| &&
                 |"GLAccount":"{ is_line-gl_account }",| &&
                 |"CostCenter":"{ is_line-cost_center }",| &&
                 |"DocumentCurrency":"BRL",| &&
                 |"SupplierInvoiceItemAmount":"{ lv_item_amount }",| &&
                 |"TaxCode":"00"| &&
                 |\}]\}|.

  ENDMETHOD.


  METHOD format_date.
    " Converte DATUM (YYYYMMDD) para ISO 8601 (YYYY-MM-DDT00:00:00)
    rv_date = |{ iv_date(4) }-{ iv_date+4(2) }-{ iv_date+6(2) }T00:00:00|.
  ENDMETHOD.


 METHOD get_csrf_token.

    TRY.
        DATA(lo_request) = io_client->get_http_request( ).
        lo_request->set_header_fields( VALUE #(
          ( name = 'x-csrf-token' value = 'fetch' )
        ) ).

        DATA(lo_response) = io_client->execute( if_web_http_client=>get ).
        rv_token = lo_response->get_header_field( 'x-csrf-token' ).

      CATCH cx_web_http_client_error INTO DATA(lx_http).
        rv_token = ''.
    ENDTRY.

  ENDMETHOD.


 METHOD call_api.

    DATA lv_search TYPE string.
    DATA lv_pos    TYPE i.
    DATA lv_end    TYPE i.
    DATA lv_value  TYPE string.

    TRY.
        DATA(lo_dest) = cl_http_destination_provider=>create_by_comm_arrangement(
          comm_scenario  = 'SAP_COM_0057'
          service_id     = 'API_SUPPLIERINVOICE_PROCESS_SRV'
        ).

        DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination( lo_dest ).

        DATA(lv_token) = get_csrf_token( lo_client ).

        DATA(lo_request) = lo_client->get_http_request( ).
        lo_request->set_header_fields( VALUE #(
          ( name = 'Content-Type' value = 'application/json' )
          ( name = 'Accept'       value = 'application/json' )
          ( name = 'x-csrf-token' value = lv_token )
        ) ).
        lo_request->set_uri_path(
          '/sap/opu/odata/sap/API_SUPPLIERINVOICE_PROCESS_SRV/A_SupplierInvoice'
        ).
        lo_request->set_text( iv_payload ).

        DATA(lo_response) = lo_client->execute( if_web_http_client=>post ).
        DATA(lv_status)   = lo_response->get_status( ).
        DATA(lv_body)     = lo_response->get_text( ).

        IF lv_status-code = 201.
          rs_result-success = abap_true.

          " Extrai SupplierInvoice
          lv_search = '"SupplierInvoice":"'.
          FIND lv_search IN lv_body MATCH OFFSET lv_pos.
          IF sy-subrc = 0.
            lv_pos = lv_pos + strlen( lv_search ).
            lv_value = lv_body+lv_pos.
            FIND '"' IN lv_value MATCH OFFSET lv_end.
            rs_result-supplier_invoice = lv_value(lv_end).
          ENDIF.

          " Extrai FiscalYear
          lv_search = '"FiscalYear":"'.
          FIND lv_search IN lv_body MATCH OFFSET lv_pos.
          IF sy-subrc = 0.
            lv_pos = lv_pos + strlen( lv_search ).
            lv_value = lv_body+lv_pos.
            FIND '"' IN lv_value MATCH OFFSET lv_end.
            rs_result-fiscal_year = lv_value(lv_end).
          ENDIF.

        ELSE.
          rs_result-success = abap_false.

          " Extrai mensagem de erro
          lv_search = '"value":"'.
          FIND lv_search IN lv_body MATCH OFFSET lv_pos.
          IF sy-subrc = 0.
            lv_pos = lv_pos + strlen( lv_search ).
            lv_value = lv_body+lv_pos.
            FIND '"' IN lv_value MATCH OFFSET lv_end.
            IF lv_end > 255.
              lv_end = 255.
            ENDIF.
            rs_result-error_message = lv_value(lv_end).
          ENDIF.

        ENDIF.

      CATCH cx_http_dest_provider_error INTO DATA(lx_dest).
        rs_result-success = abap_false.
        rs_result-error_message = lx_dest->get_text( ).

      CATCH cx_web_http_client_error INTO DATA(lx_http).
        rs_result-success = abap_false.
        rs_result-error_message = lx_http->get_text( ).

    ENDTRY.

  ENDMETHOD.
ENDCLASS.
