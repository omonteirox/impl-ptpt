@AbapCatalog.viewEnhancementCategory: [ #NONE ]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Consumption CDS View - NF Automation'

@Metadata.allowExtensions: true
@Metadata.ignorePropagatedAnnotations: true

@UI.headerInfo: { typeName: 'Nota Fiscal',
                  typeNamePlural: 'Notas Fiscais',
                  title: { type: #STANDARD, value: 'NfNumber' },
                  description: { type: #STANDARD, value: 'SupplierInvoice' } }

define view entity ZC_NF_PROCESSING
  as projection on ZI_NF_PROCESSING

{
      @UI.identification: [ { position: 10, label: 'UUID' } ]
      @UI.lineItem: [ { position: 10, label: 'UUID' },
                      { type: #FOR_ACTION, dataAction: 'ProcessInvoice', label: 'Processar NF', position: 10 } ]
  key Uuid,

      @UI.hidden: true
      ParentUuid,

      @UI.identification: [ { position: 20, label: 'Status' } ]
      @UI.lineItem: [ { position: 20, label: 'Status' } ]
      @UI.selectionField: [ { position: 20 } ]
      ProcessStatus,

      @UI.identification: [ { position: 30, label: 'Fatura SAP' } ]
      @UI.lineItem: [ { position: 30, label: 'Fatura SAP' } ]
      SupplierInvoice,

      @UI.lineItem: [ { position: 40, label: 'Ano Fiscal' } ]
      FiscalYear,

      @UI.identification: [ { position: 50, label: 'Nota Fiscal' } ]
      @UI.lineItem: [ { position: 50, label: 'Nota Fiscal' } ]
      BrNotaFiscal,

      @UI.identification: [ { position: 60, label: 'Mensagem Erro' } ]
      @UI.lineItem: [ { position: 60, label: 'Mensagem Erro' } ]
      ErrorMessage,

      @UI.identification: [ { position: 70, label: 'Empresa' } ]
      @UI.lineItem: [ { position: 70, label: 'Empresa' } ]
      @UI.selectionField: [ { position: 30 } ]
      CompanyCode,

      @UI.identification: [ { position: 80, label: 'Pedido de Compra' } ]
      @UI.lineItem: [ { position: 80, label: 'Pedido de Compra' } ]
      @UI.selectionField: [ { position: 40 } ]
      PurchaseOrder,

      @UI.identification: [ { position: 90, label: 'Item PO' } ]
      PoItem,

      @UI.identification: [ { position: 100, label: 'Valor Bruto NF' } ]
      @UI.lineItem: [ { position: 100, label: 'Valor Bruto NF' } ]
      InvoiceGrossAmount,

      @UI.identification: [ { position: 110, label: 'Valor Item' } ]
      ItemAmount,

      @UI.identification: [ { position: 120, label: 'Protocolo Autorizacao' } ]
      ProtocolNumber,

      @UI.identification: [ { position: 130, label: 'Data Emissao' } ]
      @UI.lineItem: [ { position: 130, label: 'Data Emissao' } ]
      DocumentDate,

      @UI.identification: [ { position: 135, label: 'Data Validade' } ]
      @UI.lineItem: [ { position: 135, label: 'Data Validade' } ]
      BaselineDate,

      @UI.identification: [ { position: 140, label: 'Chave de Acesso' } ]
      NfAccessKey,

      @UI.identification: [ { position: 150, label: 'Ctg. NF' } ]
      @UI.lineItem: [ { position: 150, label: 'Ctg. NF' } ]
      NfCategory,

      @UI.identification: [ { position: 160, label: 'N NF-e' } ]
      @UI.lineItem: [ { position: 160, label: 'N NF-e' } ]
      @UI.selectionField: [ { position: 50 } ]
      NfNumber,

      @UI.identification: [ { position: 170, label: 'Texto' } ]
      HeaderText,

      @UI.identification: [ { position: 180, label: 'Cond. Pagamento' } ]
      PaymentTerms,

      @UI.identification: [ { position: 190, label: 'Bloq. Pagamento' } ]
      PaymentBlock,

      @UI.identification: [ { position: 200, label: 'Conta Razao' } ]
      GlAccount,

      @UI.identification: [ { position: 210, label: 'Centro de Custo' } ]
      CostCenter,

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

      /* Parent association */
      _Upload : redirected to parent ZC_NF_UPLOAD
}
