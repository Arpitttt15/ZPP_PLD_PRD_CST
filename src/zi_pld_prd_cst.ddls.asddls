@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface for Planned Production Cost'
@Metadata.allowExtensions: true
define root view entity ZI_PLD_PRD_CST
  as select from    I_ManufacturingOrder       as a
    left outer join ztb_ppc                    as b on a.ManufacturingOrder = b.orderid
    left outer join I_ManufacturingOrderStatus as c on a.ManufacturingOrder = c.ManufacturingOrder
    left outer join I_Customer                 as d on b.customer           = d.Customer
{
  key a.ManufacturingOrder as OrderID,
      a.CreationDate,
      b.base64,
      b.m_ind,
      b.salesunitprice,
      b.freight,
      b.customer,
      d.CustomerName
}
where
      a.Batch          = 'COSTCALC'
  and c.StatusCode     = 'I0045'
  and c.StatusIsActive = 'X'
