CLASS ltc_test_insert DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS test_insert FOR TESTING RAISING cx_static_check.

ENDCLASS.

CLASS ltc_test_insert IMPLEMENTATION.

  METHOD test_insert.

    MODIFY ENTITIES OF zi_nf_upload
      ENTITY NfLine
      CREATE FIELDS (
        CompanyCode
        PurchaseOrder
        PoItem
        InvoiceGrossAmount
        ItemAmount
        ProtocolNumber
        DocumentDate
        NfCategory
        NfNumber
        PaymentTerms
      )
      WITH VALUE #( (
        %cid               = 'TEST001'
        CompanyCode        = 'JA01'
        PurchaseOrder      = '4500001266'
        PoItem             = '00010'
        InvoiceGrossAmount = '4307.12'
        ItemAmount         = '3745.32'
        ProtocolNumber     = '135260082468034'
        DocumentDate       = '20260108'
        NfCategory         = 'YA'
        NfNumber           = '13329-TEST'
        PaymentTerms       = 'D030'
      ) )
      REPORTED DATA(ls_reported)
      FAILED DATA(ls_failed)
      MAPPED DATA(ls_mapped).

    COMMIT ENTITIES.

    cl_abap_unit_assert=>assert_initial( ls_failed ).

  ENDMETHOD.

ENDCLASS.
