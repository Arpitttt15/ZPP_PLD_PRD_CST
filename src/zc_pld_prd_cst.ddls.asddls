@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Projection for Planned Production Cost'
@Metadata.allowExtensions: true
@UI.headerInfo:{
    typeName: 'Planned Production Cost Sheet',
    typeNamePlural: 'Planned Production Cost Sheet',
    title:{ type: #STANDARD, value: 'OrderId' } }
define root view entity ZC_PLD_PRD_CST
  provider contract transactional_query
  as projection on ZI_PLD_PRD_CST
{

      @UI.facet: [{ id : 'OrderId',
      purpose: #STANDARD,
      type: #IDENTIFICATION_REFERENCE,
      label: 'Planned Production Cost Sheet',
      position: 10 }]
      @UI.lineItem:       [{ position: 10, label: 'OrderId' },{ type: #FOR_ACTION , dataAction: 'ZPRINT', label: 'Generate Print'},{ type: #FOR_ACTION , dataAction: 'ZSENDMAIL', label: 'Send Email'}]
      @UI.identification: [{ position: 10, label: 'OrderId' }]
      @UI.selectionField: [{ position: 10 }]

  key OrderID,

      @UI.lineItem:       [{ position: 20, label: 'Creation Date' }]
      @UI.identification: [{ position: 20, label: 'Creation Date' }]
      @UI.selectionField: [{ position: 20 }]
      CreationDate,
      base64,
      m_ind,

      @UI.lineItem:       [{ position: 30, label: 'Sales Unit Price' }]
      @UI.identification: [{ position: 30, label: 'Sales Unit Price' }]
      @UI.selectionField: [{ position: 30 }]
      @EndUserText.label: 'Sales Unit Price'
      salesunitprice,

      @UI.lineItem:       [{ position: 40, label: 'Freight' }]
      @UI.identification: [{ position: 40, label: 'Freight' }]
      @UI.selectionField: [{ position: 40 }]
      @EndUserText.label: 'Freight'
      freight,

      @Consumption.valueHelpDefinition: [
      {
      entity: { name: 'I_Customer', element: 'Customer' },
      additionalBinding: [
      {
       localElement: 'Customer',
       element: 'Customer'}]
      }]
      @UI.lineItem:       [{ position: 50, label: 'Customer' }]
      @UI.identification: [{ position: 50, label: 'Customer' }]
      @UI.selectionField: [{ position: 50 }]
      @EndUserText.label: 'Customer'
      customer,
      
      @Consumption.valueHelpDefinition: [
      {
      entity: { name: 'I_Customer', element: 'CustomerName' },
      additionalBinding: [
      {
       localElement: 'CustomerName',
       element: 'CustomerName'}]
      }]
      @UI.lineItem:       [{ position: 60, label: 'Customer' }]
      @UI.identification: [{ position: 60, label: 'Customer' }]
      @UI.selectionField: [{ position: 60 }]
      @EndUserText.label: 'CustomerName'
      CustomerName

}
