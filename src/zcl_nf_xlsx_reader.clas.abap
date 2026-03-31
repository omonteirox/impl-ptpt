CLASS zcl_nf_xlsx_reader DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES tt_xlsx_lines TYPE STANDARD TABLE OF zsnf_xlsx_line_s WITH EMPTY KEY.

    METHODS read_xlsx
      IMPORTING
        iv_file_content TYPE xstring
      RETURNING
        VALUE(rt_lines) TYPE tt_xlsx_lines.

  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_xlsx_row,
        purchase_order       TYPE c LENGTH 50,
        po_item              TYPE c LENGTH 50,
        invoice_gross_amount TYPE c LENGTH 50,
        protocol_number      TYPE c LENGTH 50,
        document_date        TYPE c LENGTH 50,
        nf_access_key        TYPE c LENGTH 50,
        nf_category          TYPE c LENGTH 50,
        nf_number            TYPE c LENGTH 50,
        header_text          TYPE c LENGTH 50,
        payment_terms        TYPE c LENGTH 50,
        payment_block        TYPE c LENGTH 50,
        company_code         TYPE c LENGTH 50,
        gl_account           TYPE c LENGTH 50,
        cost_center          TYPE c LENGTH 50,
      END OF ty_xlsx_row,
      tt_xlsx_rows TYPE STANDARD TABLE OF ty_xlsx_row WITH EMPTY KEY.

    METHODS parse_date
      IMPORTING
        iv_date_str    TYPE string
      RETURNING
        VALUE(rv_date) TYPE datum.

    METHODS parse_amount
      IMPORTING
        iv_amount_str    TYPE string
      RETURNING
        VALUE(rv_amount) TYPE decfloat16.

    METHODS parse_payment_block
      IMPORTING
        iv_value        TYPE string
      RETURNING
        VALUE(rv_block) TYPE char1.

ENDCLASS.

CLASS zcl_nf_xlsx_reader IMPLEMENTATION.

  METHOD read_xlsx.

    TRY.
        DATA(lo_xlsx) = xco_cp_xlsx=>document->for_file_content(
          iv_file_content = iv_file_content
        )->read_access( ).

        DATA(lo_worksheet) = lo_xlsx->get_workbook( )->worksheet->at_position( 1 ).

        IF lo_worksheet->exists( ) = abap_false.
          RETURN.
        ENDIF.

        DATA(lo_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to(
          )->from_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
          )->from_row( xco_cp_xlsx=>coordinate->for_numeric_value( 2 )
          )->get_pattern( ).

        DATA lt_raw_rows TYPE tt_xlsx_rows.

        lo_worksheet->select( lo_pattern
          )->row_stream( )->operation->write_to( REF #( lt_raw_rows )
          )->execute( ).

        LOOP AT lt_raw_rows INTO DATA(ls_raw).

          IF ls_raw-purchase_order IS INITIAL AND ls_raw-nf_number IS INITIAL.
            CONTINUE.
          ENDIF.

          DATA(lv_po)      = CONV string( ls_raw-purchase_order ).
          DATA(lv_po_item) = CONV string( ls_raw-po_item ).
          DATA(lv_amount)  = CONV string( ls_raw-invoice_gross_amount ).
          DATA(lv_proto)   = CONV string( ls_raw-protocol_number ).
          DATA(lv_date)    = CONV string( ls_raw-document_date ).
          DATA(lv_key)     = CONV string( ls_raw-nf_access_key ).
          DATA(lv_cat)     = CONV string( ls_raw-nf_category ).
          DATA(lv_nf)      = CONV string( ls_raw-nf_number ).
          DATA(lv_text)    = CONV string( ls_raw-header_text ).
          DATA(lv_terms)   = CONV string( ls_raw-payment_terms ).
          DATA(lv_block)   = CONV string( ls_raw-payment_block ).
          DATA(lv_comp)    = CONV string( ls_raw-company_code ).
          DATA(lv_gl)      = CONV string( ls_raw-gl_account ).
          DATA(lv_cc)      = CONV string( ls_raw-cost_center ).

          DATA(ls_line) = VALUE zsnf_xlsx_line_s(
            purchase_order       = lv_po
            po_item              = lv_po_item
            invoice_gross_amount = parse_amount( lv_amount )
            item_amount          = parse_amount( lv_amount )
            protocol_number      = lv_proto
            document_date        = parse_date( lv_date )
            nf_access_key        = lv_key
            nf_category          = lv_cat
            nf_number            = lv_nf
            header_text          = lv_text
            payment_terms        = lv_terms
            payment_block        = parse_payment_block( lv_block )
            company_code         = lv_comp
            gl_account           = lv_gl
            cost_center          = lv_cc
          ).

          APPEND ls_line TO rt_lines.

        ENDLOOP.

      CATCH cx_root.
        CLEAR rt_lines.
    ENDTRY.

  ENDMETHOD.

  METHOD parse_date.
    DATA(lv_clean) = iv_date_str.

    IF lv_clean IS INITIAL.
      rv_date = '00000000'.
      RETURN.
    ENDIF.

    " Formato ISO: YYYY-MM-DD
    IF lv_clean(4) CO '0123456789' AND lv_clean+4(1) = '-'.
      rv_date = |{ lv_clean(4) }{ lv_clean+5(2) }{ lv_clean+8(2) }|.
      RETURN.
    ENDIF.

    " Formato DD/MM/YYYY ou DD.MM.YYYY
    REPLACE ALL OCCURRENCES OF '/' IN lv_clean WITH '.'.
    IF lv_clean CA '.'.
      rv_date = |{ lv_clean+6(4) }{ lv_clean+3(2) }{ lv_clean(2) }|.
      RETURN.
    ENDIF.

    rv_date = lv_clean.
  ENDMETHOD.

  METHOD parse_amount.
    DATA(lv_clean) = iv_amount_str.
    REPLACE ALL OCCURRENCES OF '.' IN lv_clean WITH ''.
    REPLACE ALL OCCURRENCES OF ',' IN lv_clean WITH '.'.
    TRY.
        DATA(lv_dec) = CONV decfloat34( lv_clean ).
        rv_amount = lv_dec.
      CATCH cx_root.
        rv_amount = 0.
    ENDTRY.
  ENDMETHOD.

  METHOD parse_payment_block.
    IF iv_value IS INITIAL
    OR iv_value = 'Não'
    OR iv_value = 'Nao'
    OR iv_value = 'N'.
      rv_block = ''.
    ELSE.
      DATA(lv_first) = iv_value(1).
      rv_block = lv_first.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
